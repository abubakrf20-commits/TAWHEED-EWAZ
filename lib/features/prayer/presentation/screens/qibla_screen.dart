import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tawheeed/core/services/location_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:tawheeed/features/prayer/services/magnetic_declination_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/prayer/services/qibla_math.dart';
import 'package:tawheeed/features/prayer/services/qibla_zone.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/qibla_dial.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/geo_format.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

part 'qibla_compass_card.dart';

/// One immutable snapshot of the compass sensor pipeline, published to the
/// dial subtree through [_QiblaScreenState]'s ValueNotifier.
@immutable
class CompassReading {
  const CompassReading({
    this.heading,
    this.angle = 0,
    this.isOnTarget = false,
    this.hasFirstReading = false,
    this.qiblaKnown = false,
    this.needsCalibration = false,
    this.sensorAbsent = false,
  });

  /// Smoothed TRUE heading (0 = north), null before the first reading.
  final double? heading;

  /// Signed angle from the device nose to the Qibla (-180..180).
  final double angle;
  final bool isOnTarget;
  final bool hasFirstReading;
  final bool qiblaKnown;

  /// Magnetometer unreliable — show the figure-8 calibration banner.
  final bool needsCalibration;

  /// No events at all (missing sensor / web build) — manual guidance banner.
  final bool sensorAbsent;

  CompassReading copyWith({bool sensorAbsent = false}) => CompassReading(
        heading: heading,
        angle: angle,
        isOnTarget: isOnTarget,
        hasFirstReading: hasFirstReading,
        qiblaKnown: qiblaKnown,
        needsCalibration: needsCalibration,
        sensorAbsent: sensorAbsent,
      );
}

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  double? _qiblaDirection;
  double? _userLat;
  double? _userLng;
  bool _loading = true;
  bool _gpsRefreshing = false;
  String? _error;
  String? _distance;
  String? _locationSource;
  bool _showManualInput = false;
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  // Shared minute/second ticker (statuses refresh + countdown text).
  ClockTicker? _ticker;

  // Magnetic declination (degrees, east positive) at the user's location.
  double? _declination;

  // Daily sun-shadow moments for the current location (today + tomorrow).
  List<SunShadowMoment>? _shadowTimes;

  // Solar events (sunrise/sunset/noon) for the current location.
  SolarEvents? _solarEvents;

  // Whether the sun is below the horizon at the current location.
  bool _isNight = false;

  // Accuracy threshold for the "on target" zone — default 3° per user request.
  double _accuracyThreshold = 3.0;

  // The zone the page's SUN/MOON times are rendered in — resolved off the
  // LOCATION (nearest city → settings zone → device), never the device clock.
  ResolvedQiblaZone? _zone;

  // GlobalKey for sharing a screenshot of the compass.
  final _cardKey = GlobalKey();
  bool _shareBusy = false;

  // True when the WMM platform lookup failed — the compass then works on
  // magnetic north only, and the user must be told the angle is approximate.
  bool _declinationError = false;

  /// Active theme-phase palette — this screen's single color source.
  AppPalette get _palette => TimeThemeKit.of(context).palette;

  // ── Compass pipeline ─────────────────────────────────────────────────────
  // ONE subscription feeds a ValueNotifier, so only the dial subtree rebuilds
  // at sensor rate (~31 Hz) instead of the whole page — and smoothing,
  // haptics and the wakelock run in the listener, never as build side effects.
  final ValueNotifier<CompassReading> _compass =
      ValueNotifier(const CompassReading());
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _sensorProbeTimer;
  bool _hasFirstReading = false;
  double _smoothedHeading = 0;
  int _nullHeadingStreak = 0;

  // Hysteresis state for the on-target zone.
  bool _onTargetNow = false;
  bool _wasOnTarget = false;

  // Separate throttle clocks so the on-target buzz and the sun-shadow "now"
  // buzz no longer suppress each other through one shared timestamp.
  DateTime? _lastTargetHapticAt;
  DateTime? _lastShadowHapticAt;

  // Smart wakelock: keep screen on only while actively seeking Qibla.
  Timer? _wakelockReleaseTimer;

  void _scheduleWakelockRelease() {
    _wakelockReleaseTimer?.cancel();
    _wakelockReleaseTimer =
        Timer(const Duration(seconds: 30), () => AppWakelock.release('qibla'));
  }

  void _applySeekWakelock(bool onTarget) {
    if (onTarget) {
      _scheduleWakelockRelease();
    } else {
      _wakelockReleaseTimer?.cancel();
      AppWakelock.acquire('qibla');
    }
  }

  void _startCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      _compass.value = const CompassReading().copyWith(sensorAbsent: true);
      return;
    }
    // Devices (and web builds) without a magnetometer never emit an event —
    // the old streak counter relied on rebuilds that also never happen, so
    // probe instead: no first reading within 4 s ⇒ sensor absent.
    _sensorProbeTimer = Timer(const Duration(seconds: 4), () {
      if (!_compass.value.hasFirstReading) {
        _compass.value = const CompassReading().copyWith(sensorAbsent: true);
      }
    });
    _compassSub = events
        .distinct((a, b) => ((a.heading ?? 0) - (b.heading ?? 0)).abs() < 0.5)
        .listen(_onCompassEvent);
  }

  void _onCompassEvent(CompassEvent event) {
    final raw = event.heading;
    if (raw == null) {
      // The plugin emits null headings when it has no reliable fix; a long
      // run of them means the sensor never delivers — guide the user manually.
      _nullHeadingStreak++;
      if (_nullHeadingStreak > 15) {
        _compass.value = const CompassReading().copyWith(sensorAbsent: true);
      }
      return;
    }
    _nullHeadingStreak = 0;
    // flutter_compass reports magnetic north on Android and true north on
    // iOS; convert Android headings with the local WMM declination.
    final declination =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ? (_declination ?? 0.0)
            : 0.0;
    final trueHeading = applyMagneticDeclination(raw, declination);
    if (!_hasFirstReading) {
      _smoothedHeading = trueHeading;
      _hasFirstReading = true;
    } else {
      // Adaptive smoothing: the factor grows with the distance still to close
      // (floor 0.10 at rest, ceiling 0.50 mid-sweep), so a steady turn catches
      // up without the old three-tier version's factor flip-flop — its 0.08
      // floor is what made the dial trail the sensor while rotating.
      final delta = (trueHeading - _smoothedHeading + 540) % 360 - 180;
      final factor = (0.10 + delta.abs() * 0.02).clamp(0.10, 0.50);
      _smoothedHeading += factor * delta;
      _smoothedHeading = (_smoothedHeading + 360) % 360;
    }
    final qibla = _qiblaDirection;
    final angle = qibla == null ? 0.0 : _computeAngle(qibla, _smoothedHeading);
    // Hysteresis: enter at the threshold, exit only 1° beyond it — a bare
    // comparison lets noise flicker the gold/green state at a 3° setting.
    if (_onTargetNow) {
      if (angle.abs() > _accuracyThreshold + 1.0) _onTargetNow = false;
    } else if (angle.abs() < _accuracyThreshold) {
      _onTargetNow = true;
    }
    _applySeekWakelock(_onTargetNow);
    final enteredTarget = _onTargetNow && !_wasOnTarget;
    _wasOnTarget = _onTargetNow;
    if (enteredTarget && _hapticDue(_lastTargetHapticAt, 3)) {
      _lastTargetHapticAt = DateTime.now();
      HapticFeedback.mediumImpact();
    }
    // Sun-shadow "now" moment → extra heavy buzz (once per minute max).
    if (_shadowTimes != null &&
        _shadowTimes!.any((m) => m.status == SunShadowStatus.now) &&
        _hapticDue(_lastShadowHapticAt, 60)) {
      _lastShadowHapticAt = DateTime.now();
      HapticFeedback.heavyImpact();
    }
    final accuracy = event.accuracy;
    _compass.value = CompassReading(
      heading: _smoothedHeading,
      angle: angle,
      isOnTarget: _onTargetNow,
      hasFirstReading: true,
      qiblaKnown: qibla != null,
      // Android reports coarse buckets (15/30/45); iOS a continuous value.
      // Only ≥25 (and null = unknown) truly warrants the recalibration banner.
      needsCalibration: accuracy == null || accuracy > 25,
    );
  }

  bool _hapticDue(DateTime? last, int seconds) =>
      last == null ||
      DateTime.now().difference(last) > Duration(seconds: seconds);

  @override
  void initState() {
    super.initState();
    _startCompass();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedThenRefresh();
      _maybeShowOnboarding();
      _loadSensitivityState();
    });
    // Status/flag refresh on the shared minute ticker — no page-wide
    // per-second setState. The countdown text binds to the ticker's SECOND
    // notifier inside its own tiny subtree (see _buildCountdownBox).
    _ticker = ref.read(clockTickerProvider);
    _ticker!.minute.addListener(_onMinuteTick);
  }

  void _onMinuteTick() {
    if (!mounted || _shadowTimes == null || _shadowTimes!.isEmpty) return;
    _refreshSolarStatus();
    // Recompute the moment statuses once per minute; repaint the page ONLY
    // when the next actionable moment actually changed identity/status, so
    // idling on the page costs nothing.
    final zone = _zone;
    if (zone == null || _userLat == null || _userLng == null) return;
    final zoneNow = zone.wallOf(DateTime.now().toUtc());
    final off = zone.offsetMinutesForWallDate(zoneNow);
    final fresh = qiblaSunShadowTimes(
      lat: _userLat!,
      lng: _userLng!,
      qiblaBearing: _qiblaDirection ?? 0,
      date: zoneNow,
      now: zoneNow,
      tzOffsetMinutes: off,
    );
    var changed = false;
    if (fresh.length == _shadowTimes!.length) {
      for (var i = 0; i < fresh.length; i++) {
        if (fresh[i].status != _shadowTimes![i].status ||
            fresh[i].time != _shadowTimes![i].time) {
          changed = true;
          break;
        }
      }
    } else {
      changed = true;
    }
    if (changed) {
      _shadowTimes = fresh;
      setState(() {});
    }
  }

  /// Restore the persisted sensitivity step (3/5/10°). The dismissed-flag
  /// half of this loader was dead (nothing writes that pref) — removed in the
  /// 2026-10-15 qibla review.
  Future<void> _loadSensitivityState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final threshold = prefs.getDouble('qibla_sensitivity_degree');
      var changed = false;
      if (threshold != null &&
          const [3.0, 5.0, 10.0].contains(threshold) &&
          threshold != _accuracyThreshold) {
        _accuracyThreshold = threshold;
        changed = true;
      }
      if (mounted && changed) setState(() {});
    } catch (e) {
      AppLogger.warning('qibla_screen', 'sensitivity state load failed: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.minute.removeListener(_onMinuteTick);
    _compassSub?.cancel();
    _sensorProbeTimer?.cancel();
    _wakelockReleaseTimer?.cancel();
    AppWakelock.release('qibla');
    _compass.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedThenRefresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = ref.read(settingsProvider).value ?? const AppSettings();
      if (s.hasLocation && s.manualLat != null && s.manualLng != null) {
        // User-pinned coordinates: honored, never overwritten by GPS here.
        _calculateDirection(s.manualLat!, s.manualLng!);
        _locationSource = 'موقعیت دستی شما';
        setState(() {
          _loading = false;
          _error = null;
        });
        _refreshGps();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final cachedLat = prefs.getDouble('qibla_cached_lat');
      final cachedLng = prefs.getDouble('qibla_cached_lng');
      if (!mounted) return;
      if (cachedLat != null && cachedLng != null) {
        _calculateDirection(cachedLat, cachedLng);
        _locationSource = 'آخرین موقعیت';
        setState(() {
          _loading = false;
          _error = null;
        });
        _refreshGps();
        return;
      }
      final lastPos = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      if (lastPos != null) {
        _calculateDirection(lastPos.latitude, lastPos.longitude);
        _locationSource = 'آخرین موقعیت';
        setState(() {
          _loading = false;
          _error = null;
        });
        _refreshGps();
        return;
      }
    } catch (e) {
      AppLogger.warning('qibla_screen', 'restore cached location failed: $e');
    }
    // Fallback: try saved prayer coordinates from secure storage
    try {
      final ds = ref.read(prayerRepositoryProvider);
      final coords = ds.coordinates;
      if (coords != null) {
        _calculateDirection(coords.latitude, coords.longitude);
        _locationSource = 'موقعیت نماز';
        setState(() {
          _loading = false;
          _error = null;
        });
        _refreshGps();
        return;
      }
    } catch (e) {
      AppLogger.warning(
          'qibla_screen', 'saved prayer coords lookup failed: $e');
    }
    if (_qiblaDirection == null) {
      setState(() {
        _loading = false;
      });
    }
    _refreshGps();
  }

  Future<void> _showEnableGpsDialog({bool isPermissionDenied = false}) async {
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPermissionDenied ? 'دسترسی موقعیت' : 'فعال‌سازی GPS',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: Text(
            isPermissionDenied
                ? 'برای تنظیم دقیق قبله، دسترسی به موقعیت لازم است. لطفاً از تنظیمات، دسترسی موقعیت را فعال کنید.'
                : 'برای تنظیم دقیق قبله، لطفاً GPS دستگاه را روشن کنید.',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('بعداً',
                  style: TextStyle(fontFamily: AppTheme.fontFamily))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('رفتن به تنظیمات',
                  style: TextStyle(fontFamily: AppTheme.fontFamily))),
        ],
      ),
    );
    if (result == true) {
      try {
        if (isPermissionDenied) {
          await Geolocator.openAppSettings();
        } else {
          await Geolocator.openLocationSettings();
        }
      } catch (e) {
        AppLogger.warning('qibla_screen', 'open gps settings failed: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _loadCachedThenRefresh();
    }
  }

  Future<void> _refreshGps() async {
    if (_gpsRefreshing) return;
    setState(() {
      _gpsRefreshing = true;
    });
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _gpsRefreshing = false;
          if (_qiblaDirection == null) _error = 'سرویس موقعیت فعال نیست';
        });
        _showEnableGpsDialog();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsRefreshing = false;
          if (_qiblaDirection == null) {
            _error = permission == LocationPermission.deniedForever
                ? 'دسترسی موقعیت برای همیشه رد شده'
                : 'دسترسی به موقعیت رد شد';
          }
        });
        return;
      }
      final position = await getCurrentPositionWithFallback(
        logTag: 'qibla_screen',
      );
      if (!mounted) return;
      _calculateDirection(position.latitude, position.longitude);
      _locationSource = 'GPS';
      // Cache under qibla's OWN prefs keys: settings.manualLat/Lng belongs to
      // the user and prayer's manual mode — a GPS fix must not rewrite it.
      _cacheCoords(position.latitude, position.longitude);
      setState(() {
        _error = null;
        _gpsRefreshing = false;
      });
    } catch (e) {
      AppLogger.warning('qibla_screen', 'gps refresh failed: $e');
      if (!mounted) return;
      if (_qiblaDirection == null) {
        setState(() {
          _error = 'سرویس موقعیت فعال نیست';
          _gpsRefreshing = false;
        });
      } else {
        setState(() {
          _gpsRefreshing = false;
        });
      }
    }
  }

  Future<void> _calculateQibla({double? manualLat, double? manualLng}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (manualLat != null && manualLng != null) {
        _calculateDirection(manualLat, manualLng);
        _locationSource = 'دستی';
        try {
          if (mounted) {
            final writer = ref.read(settingsProvider.notifier);
            writer.setManualCoords(manualLat, manualLng);
            writer.setHasLocation(true);
          }
        } catch (e) {
          AppLogger.warning('qibla_screen', 'save manual coords failed: $e');
        }
        setState(() {
          _loading = false;
        });
        return;
      }
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _error = 'سرویس موقعیت فعال نیست';
          _loading = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'دسترسی به موقعیت رد شد';
            _loading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'دسترسی موقعیت برای همیشه رد شده';
          _loading = false;
        });
        return;
      }
      final position = await getCurrentPositionWithFallback(
        logTag: 'qibla_screen',
      );
      if (!mounted) return;
      _calculateDirection(position.latitude, position.longitude);
      _locationSource = 'GPS';
      _cacheCoords(position.latitude, position.longitude);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      AppLogger.warning('qibla_screen', 'qibla recalculation failed: $e');
      if (!mounted) return;
      if (_qiblaDirection != null) {
        setState(() {
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'جهت قبله محاسبه نشد؛ دوباره تلاش کنید.';
          _loading = false;
        });
      }
    }
  }

  void _calculateDirection(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _qiblaDirection = qiblaBearingDeg(lat, lng);
    final distKm = kaabaDistanceKm(lat, lng);
    _distance = distKm >= 1000
        ? '${(distKm / 1000).toStringAsFixed(1)} هزار کیلومتر'
        : '${distKm.toStringAsFixed(1)} کیلومتر';
    // B1: the page is FOR THE PLACE — resolve the place's IANA zone (nearest
    // known city → the user's saved zone → device offset) so ALL printed
    // times are that location's wall clock, not the device's.
    final settings = ref.read(settingsProvider).value;
    _zone = resolveQiblaZone(
      lat: lat,
      lng: lng,
      settingsTimezone: settings?.timezone,
    );
    final zone = _zone!;
    final nowInstant = DateTime.now().toUtc();
    final zoneNow = zone.wallOf(nowInstant);
    final todayOffset = zone.offsetMinutesForWallDate(zoneNow);
    _shadowTimes = qiblaSunShadowTimes(
      lat: lat,
      lng: lng,
      qiblaBearing: _qiblaDirection!,
      date: zoneNow,
      now: zoneNow,
      tzOffsetMinutes: todayOffset,
    );
    _solarEvents = computeSolarEvents(
        lat: lat, lng: lng, date: zoneNow, tzOffsetMinutes: todayOffset);
    _refreshSolarStatus();
    _updateDeclination(lat, lng);
  }

  /// Qibla's own last-GPS cache — separate from the user's manual coords.
  void _cacheCoords(double lat, double lng) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('qibla_cached_lat', lat);
      prefs.setDouble('qibla_cached_lng', lng);
    }).catchError((Object e) {
      AppLogger.warning('qibla_screen', 'cache coords failed: $e');
    });
  }

  /// Update the isNight flag based on the current solar elevation —
  /// evaluated at the LOCATION's clock (the same footing as the printed
  /// sun times), not the device's.
  void _refreshSolarStatus() {
    if (_userLat == null || _userLng == null) return;
    if (_zone == null) return;
    final zoneNow = _zone!.wallOf(DateTime.now().toUtc());
    final off = _zone!.offsetMinutesForWallDate(zoneNow);
    _isNight = isNightTime(_userLat!, _userLng!, zoneNow, tzOffsetMinutes: off);
  }

  /// Fetch the local magnetic declination (WMM via the platform) so headings
  /// can be converted from magnetic to true north on Android.
  Future<void> _updateDeclination(double lat, double lng) async {
    try {
      final decl = await MagneticDeclinationService().calculateDeclination(
        latitude: lat,
        longitude: lng,
        date: DateTime.now(),
      );
      if (!mounted) return;
      if (decl == null) {
        // A silent 0° is up to ~20° wrong in some regions — tell the user the
        // compass is only approximate until the next successful lookup.
        setState(() => _declinationError = true);
        return;
      }
      setState(() {
        _declination = decl;
        _declinationError = false;
      });
    } catch (e) {
      AppLogger.warning(
          'qibla_screen', 'magnetic declination lookup failed: $e');
      if (!mounted) return;
      // A silent 0° is up to ~20° wrong in some regions — tell the user the
      // compass is only approximate until the next successful lookup.
      setState(() => _declinationError = true);
    }
  }

  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('qibla_onboarding_done') == true) return;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('راهنمای قبله‌نما', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _onboardRow(Icons.location_on,
                  '1) اجازه موقعیت را تایید کنید تا جهت دقیق محاسبه شود'),
              const SizedBox(height: 8),
              _onboardRow(Icons.screen_rotation,
                  '2) برای دقت بیشتر، گوشی را چند بار به شکل 8 انگلیسی بچرخانید — ترجیحاً در فضای باز و دور از فلز و آهنربا (کیف مغناطیسی، اسپیکر)'),
              const SizedBox(height: 8),
              _onboardRow(Icons.explore,
                  '3) عقربه سبز رو به قبله است — وقتی طلایی شد، رو به قبله هستید'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      );
      await prefs.setBool('qibla_onboarding_done', true);
    } catch (e) {
      AppLogger.warning('qibla_screen', 'onboarding dialog failed: $e');
    }
  }

  Widget _onboardRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: TopicHues.qibla),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    height: 1.5))),
      ],
    );
  }

  /// Compute the signed angle (-180..180) between Qibla direction and heading.
  double _computeAngle(double qiblaDir, double heading) {
    var raw = qiblaDir - heading;
    while (raw < -180) {
      raw += 360;
    }
    while (raw > 180) {
      raw -= 360;
    }
    return raw;
  }

  /// Accept Persian (۳۵٫۷) and Arabic-Indic (٣٥.٧) digits plus the
  /// typographic minus from any keyboard, not just Latin input.
  double? _parseCoordField(String text) {
    final normalized = NumberFormat.toLatin(text.trim())
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll('−', '-');
    return double.tryParse(normalized);
  }

  Future<void> _shareQiblaImage() async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      // Give the RepaintBoundary a couple of frames to settle.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final card = ShareService.cardBoundary(_cardKey);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      // Cap to 2x DPR and max 1200px longest side to avoid OOM on tablets.
      final longest = card.size.width > card.size.height
          ? card.size.width
          : card.size.height;
      final desired = (1200 / longest).clamp(1.0, 2.0);
      final pixelRatio = dpr > desired ? desired : dpr.clamp(1.0, 2.0);
      final bytes = await ShareService.rasterizeCard(card.boundary, pixelRatio);
      await ShareService.sharePng(bytes, 'qibla_share.png',
          text: _buildShareText());
    } on ShareCaptureException {
      // Fallback to text-only sharing.
      await ShareService.shareText(_buildShareText());
    } catch (e) {
      AppLogger.warning('QiblaScreen', 'image share failed, using text: $e');
      await ShareService.shareText(_buildShareText());
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _shareQiblaText() async {
    await ShareService.shareText(_buildShareText());
  }

  String _buildShareText() {
    final qibla = _qiblaDirection!.toStringAsFixed(1);
    final lat = _userLat!.abs().toStringAsFixed(4);
    final lng = _userLng!.abs().toStringAsFixed(4);
    final ns = _userLat! >= 0 ? 'N' : 'S';
    final ew = _userLng! >= 0 ? 'E' : 'W';
    final dist = _distance ?? '-';
    return '🧭 جهت قبله: $qibla° از شمال\n'
        '📍 موقعیت: $lat$ns, $lng$ew\n'
        '📏 فاصله تا کعبه: $dist';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'قبله‌نما',
        actions: [
          if (_gpsRefreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location, size: 20),
              onPressed: _refreshGps,
              tooltip: 'به‌روزرسانی موقعیت',
            ),
          if (!_loading && _qiblaDirection != null)
            IconButton(
              icon: const Icon(Icons.edit_location_alt, size: 20),
              onPressed: () =>
                  setState(() => _showManualInput = !_showManualInput),
              tooltip: _showManualInput ? 'موقعیت خودکار' : 'موقعیت دستی',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _qiblaDirection == null
              ? _buildErrorWidget()
              : _buildCompass(),
    );
  }

  Widget _buildErrorWidget() {
    final isGpsOff = _error!.contains('سرویس موقعیت فعال نیست');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: TopicHues.qibla.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.location_off,
                  size: 48, color: TopicHues.qibla),
            ),
            const SizedBox(height: 24),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: AppTheme.scaledFontSize(context, 16))),
            const SizedBox(height: 24),
            if (isGpsOff)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.location_on, size: 18),
                  label: const Text('فعال کردن موقعیت'),
                  onPressed: () async {
                    try {
                      await Geolocator.openLocationSettings();
                    } catch (e) {
                      AppLogger.warning(
                          'qibla_screen', 'open location settings failed: $e');
                    }
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) _loadCachedThenRefresh();
                  },
                ),
              ),
            if (isGpsOff) const SizedBox(height: 12),
            _buildManualInputForm(),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _loadCachedThenRefresh,
                child: const Text('تلاش دوباره')),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInputForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TopicHues.qibla.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_location_alt,
                  size: 16, color: TopicHues.qibla),
              const SizedBox(width: 8),
              Text('موقعیت دستی',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.bold,
                      color: TopicHues.qibla)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'عرض جغرافیایی',
                    hintText: 'مثلاً 35.6892',
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    labelStyle: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12)),
                  ),
                  style:
                      TextStyle(fontSize: AppTheme.scaledFontSize(context, 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'طول جغرافیایی',
                    hintText: 'مثلاً 51.3890',
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    labelStyle: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12)),
                  ),
                  style:
                      TextStyle(fontSize: AppTheme.scaledFontSize(context, 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('اعمال'),
              onPressed: () {
                final lat = _parseCoordField(_latController.text);
                final lng = _parseCoordField(_lngController.text);
                String? err;
                if (lat == null || lng == null) {
                  err = 'لطفاً هر دو مقدار را به صورت عدد وارد کنید';
                } else if (lat < -90 || lat > 90) {
                  err = 'عرض جغرافیایی باید بین ‎−90 و ‎+90 باشد';
                } else if (lng < -180 || lng > 180) {
                  err = 'طول جغرافیایی باید بین ‎−180 و ‎+180 باشد';
                } else if (lat == 0 && lng == 0) {
                  err = 'مختصات ‎0,0 در اقیانوس است — مقدار واقعی وارد کنید';
                }
                if (err != null) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(err),
                        backgroundColor:
                            isDark ? AppTheme.darkError : AppTheme.lightError),
                  );
                  return;
                }
                _calculateQibla(manualLat: lat, manualLng: lng);
                setState(() => _showManualInput = false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: _shareBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share, size: 16),
              label: const Text('اشتراک تصویر'),
              onPressed: _shareBusy ? null : _shareQiblaImage,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.text_snippet, size: 16),
              label: const Text('اشتراک متن'),
              onPressed: _shareQiblaText,
            ),
          ),
        ],
      ),
    );
  }

  /// Sun-times card — flat AppCard, one row of three small stats. Every
  /// time is the TARGET LOCATION's wall clock (B1) and LTR-isolated (B3).
  Widget _buildSolarInfoCard() {
    final e = _solarEvents!;
    final p = _palette;
    final sunHue = dsContentColor(context, PrayerHues.sunrise);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isNight ? Icons.nights_stay : Icons.wb_sunny,
                    size: 17, color: _isNight ? TopicHues.qibla : sunHue),
                const SizedBox(width: 8),
                Text(
                  _isNight ? 'شب — خورشید زیر افق' : 'روز — خورشید بالای افق',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w500,
                      color: _isNight ? TopicHues.qibla : sunHue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (e.sunrise != null) ...[
                  Expanded(
                    child: _buildSolarInfo(
                      icon: Icons.wb_twilight,
                      label: 'طلوع',
                      value: _fmtTime(e.sunrise!),
                      color: PrayerHues.sunrise,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (e.sunset != null) ...[
                  Expanded(
                    child: _buildSolarInfo(
                      icon: Icons.brightness_3,
                      label: 'غروب',
                      value: _fmtTime(e.sunset!),
                      color: TopicHues.qibla,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (e.solarNoon != null)
                  Expanded(
                    child: _buildSolarInfo(
                      icon: Icons.light_mode,
                      label: 'ظهر شمسی',
                      value: _fmtTime(e.solarNoon!),
                      color: PrayerHues.dhuhr,
                    ),
                  ),
              ],
            ),
            if (e.maxElevation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: p.textMuted),
                    children: [
                      const TextSpan(text: 'حداکثر ارتفاع خورشید: '),
                      TextSpan(text: GeoFormat.degrees(e.maxElevation!)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolarInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final p = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 9),
                  color: p.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  color: dsContentColor(context, color))),
        ],
      ),
    );
  }

  /// Night guide — B6: ONE source value, the qibla bearing itself, so the
  /// guidance text and the result row can never disagree again: facing
  /// Polaris (due north), the qibla is CLOCKWISE («راست‌گرد») for bearings
  /// 0–180° and COUNTER-CLOCKWISE («چپ‌گرد») for 180–360°, by the unwrapped
  /// turn angle to the bearing. North-hemisphere only, night only.
  Widget _buildPolarisGuideCard() {
    final polarisAz =
        polarisPositionDeg(_userLat!, _userLng!, DateTime.now()).$1;
    final angleDiff = _computeAngle(_qiblaDirection!, polarisAz);
    final qiblaFromPolaris = polarisAz + angleDiff;
    // The one value everything below derives from:  ..
    final turn = qiblaFromPolaris % 360;
    final isClockwise = turn <= 180;
    final turnAmount = isClockwise ? turn : (360 - turn);
    final directionWord = isClockwise ? 'راست‌گرد' : 'چپ‌گرد';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, size: 17, color: TopicHues.qibla),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('راهنمای شب — ستارهٔ قطبی',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w500,
                          color: TopicHues.qibla)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ستارهٔ قطبی (Polaris) تقریباً در شمال جغرافیایی قرار دارد. '
              'برای یافتن قبله در شب، اول به سمت ستارهٔ قطبی بایستید (شمال) سپس '
              'به سمت ${isClockwise ? 'راست' : 'چپ'} ${turnAmount.toStringAsFixed(0)} درجه بچرخید.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: _palette.textMuted,
                  height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? TopicHues.qibla.withValues(alpha: 0.14)
                    : TopicHues.qibla.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore, size: 14, color: TopicHues.qibla),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'قبله: '),
                        TextSpan(
                            text:
                                '${turnAmount.toStringAsFixed(0)}° $directionWord از شمال'),
                      ],
                    ),
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: TopicHues.qibla),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'برای پیدا کردن ستارهٔ قطبی: دست خود را دراز کنید و انگشت اشاره را '
              'از خوشهٔ شش‌تایی (پلک شش‌تایی) 5 برابر به بالا ببرید.',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: _palette.textMuted,
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final userPoint = latlng.LatLng(_userLat!, _userLng!);
    const kaabaPoint = latlng.LatLng(kaabaLat, kaabaLng);
    final center = latlng.LatLng(
      (_userLat! + kaabaLat) / 2,
      (_userLng! + kaabaLng) / 2,
    );
    // Rough zoom heuristic based on distance.
    final distKm = kaabaDistanceKm(_userLat!, _userLng!);
    double zoom;
    if (distKm > 5000) {
      zoom = 2.5;
    } else if (distKm > 2000) {
      zoom = 3.5;
    } else if (distKm > 800) {
      zoom = 4.5;
    } else {
      zoom = 6.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _palette.outline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.islamic.tawheeed',
                // Online + http cache (flutter_map caches tiles in memory/disk via provider)
              ),
              PolylineLayer(
                polylines: [
                  // The great circle, not a two-point line: on a Mercator map a
                  // straight segment leaves the bearing the dial shows as soon
                  // as the two places are far apart.
                  Polyline(
                    points: [
                      for (final p in kaabaGreatCirclePath(_userLat!, _userLng!))
                        latlng.LatLng(p.$1, p.$2),
                    ],
                    strokeWidth: 3,
                    color: TopicHues.qibla,
                    borderStrokeWidth: 1,
                    borderColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: userPoint,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TopicHues.sciences,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  Marker(
                    point: kaabaPoint,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TopicHues.qibla,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.mosque,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _palette.textPrimary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'شما → کعبه',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${GeoFormat.degrees(_qiblaDirection!)} • $_distance',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: AppTheme.scaledFontSize(context, 10)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// کارت موقعیت لحظه‌ای ماه — ارتفاع، آزیموت، فاز (مکمل خورشید)
  /// B2: روشنایی an INTEGER percent (round half up), never 15 decimals.
  Widget _buildMoonPositionCard() {
    final now = DateTime.now();
    final alt = LunarCalculator.moonAltitude(now, _userLat!, _userLng!);
    final az = LunarCalculator.moonAzimuth(now, _userLat!, _userLng!);
    final illum = LunarCalculator.illumination(now);
    final phaseName = LunarCalculator.phaseName(now);
    final visible = alt > 0;
    final color =
        visible ? dsContentColor(context, TopicHues.moon) : _palette.textMuted;
    final illumPercent = (illum.clamp(0.0, 100.0) + 0.5).floor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(visible ? Icons.brightness_3 : Icons.brightness_2_outlined,
                    size: 17, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'ماه — ${phaseName.persian} ('),
                        TextSpan(
                            text:
                                '${GeoFormat.percent(illumPercent.toDouble())} روشنایی'),
                        const TextSpan(text: ')'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w500,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _moonStat(
                    'ارتفاع',
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: GeoFormat.degrees(alt.abs(), decimals: 0)),
                          TextSpan(text: alt >= 0 ? ' بالای افق' : ' زیر افق'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                    child: _moonStat(
                        'سمت', Text(GeoFormat.degrees(az, decimals: 0)))),
                Expanded(
                    child: _moonStat(
                        'وضعیت', Text(visible ? 'قابل رؤیت' : 'پایین افق'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moonStat(String label, Widget value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 9),
                color: _palette.textMuted)),
        value,
      ],
    );
  }

  /// Sensitivity selector — the kit's SegmentedTabs in flat mode (selected
  /// = solid dark pill). The choice PERSISTS (3 / 5 / 10 % off-target zone).
  Widget _buildAccuracyThresholdSelector() {
    final p = _palette;
    const values = [3.0, 5.0, 10.0];
    final idx = values.indexOf(_accuracyThreshold);
    final selected = idx < 0 ? 0 : idx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 15, color: p.textMuted),
                const SizedBox(width: 7),
                Text('حساسیت قبله',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: p.textSecondary)),
                const Spacer(),
                Text('محدودهٔ «روبرو قبله هستید»',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: p.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedTabs(
              index: selected,
              tabs: [
                for (final t in values)
                  SegmentedTab(label: '${t.toStringAsFixed(0)} درجه'),
              ],
              onChanged: (i) async {
                setState(() => _accuracyThreshold = values[i]);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('qibla_sensitivity_degree', values[i]);
                } catch (e) {
                  AppLogger.warning(
                      'qibla_screen', 'sensitivity save failed: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// SUN SIGN card — flat AppCard; the countdown box binds ONLY to the
  /// clock ticker (per-minute normally, per-second under a minute left);
  /// the rest of the page never rebuilds on ticks.
  Widget _buildSunShadowCard() {
    final times = _shadowTimes!;
    final next = times
        .where((m) => m.status != SunShadowStatus.passed)
        .cast<SunShadowMoment?>()
        .firstWhere((_) => true, orElse: () => null);
    final isNowActive = times.any((m) => m.status == SunShadowStatus.now);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        borderColor:
            isNowActive ? TopicHues.qibla.withValues(alpha: 0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny,
                    size: 17,
                    color: isNowActive
                        ? TopicHues.qibla
                        : TopicHues.qibla.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('نشانه خورشید',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w500,
                          color: TopicHues.qibla)),
                ),
                _StatusChip(
                  text: isNowActive
                      ? 'الان نزدیک نشانه است'
                      : (next?.day == SunShadowDay.today
                          ? 'نشانه امروز: ${_fmtTime(next!.time)}'
                          : 'نشانه امروز گذشت'),
                  icon: isNowActive
                      ? Icons.my_location
                      : (next?.day == SunShadowDay.today
                          ? Icons.schedule
                          : Icons.schedule_outlined),
                  color: isNowActive
                      ? TopicHues.qibla
                      : (next?.day == SunShadowDay.today
                          ? TopicHues.qibla
                          : _palette.textMuted),
                  bgColor: isNowActive
                      ? TopicHues.qibla.withValues(alpha: 0.1)
                      : _palette.surfaceAlt,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isNowActive)
              _buildSignNowBox()
            else if (next != null)
              _buildCountdownBox(next),
            // Moment rows: today done / next updatable.
            for (final m in times) _buildMomentRow(m),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 13, color: _palette.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'یک چسب یا میلهٔ عمودی را روی زمین بگذارید؛ در لحظهٔ نشانه، سایهٔ آن دقیقاً در جهت قبله است. (دقت: حدود 1 درجه)',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          color: _palette.textMuted,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignNowBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: TopicHues.qibla.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 15, color: TopicHues.qibla),
          const SizedBox(width: 6),
          Expanded(
            child: Text('اکنون — سایه به سمت قبله است!',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: TopicHues.qibla)),
          ),
        ],
      ),
    );
  }

  /// The countdown box — tokens only (warningBg paper, heroGold border,
  /// dark-gold inks). Inner subtree listens to the shared ticker's SECOND
  /// notifier so the page itself never rebuilds per tick; the duration is
  /// Persian words, never the «15س 36د» bidi trap.
  Widget _buildCountdownBox(SunShadowMoment next) {
    final labelInk = mix(AppPalette.goldDark, Colors.black, 0.25);
    final valueInk = mix(AppPalette.goldDark, Colors.black, 0.5);
    return ValueListenableBuilder<DateTime>(
      valueListenable: _ticker!.second,
      builder: (context, _, __) {
        final secondsLeft =
            next.utcInstant.difference(DateTime.now().toUtc()).inSeconds;
        if (secondsLeft < 0) return const SizedBox.shrink();
        final dayLabel = next.day == SunShadowDay.tomorrow ? 'فردا' : 'امروز';
        final dur = GeoFormat.durationWords(Duration(seconds: secondsLeft));
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.warningBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.heroGoldDeep.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تا لحظهٔ نشانه ($dayLabel · ${_fmtTime(next.time)})',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: labelInk),
              ),
              const SizedBox(height: 2),
              Text(
                dur,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w500,
                  color: valueInk,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Moment rows — flat colors only; past rows use ALPHA ink (never an
  /// Opacity layer).
  Widget _buildMomentRow(SunShadowMoment m) {
    final isPassed = m.status == SunShadowStatus.passed;
    final isNow = m.status == SunShadowStatus.now;
    final dayLabel = m.day == SunShadowDay.tomorrow ? 'فردا' : 'امروز';
    final kindLabel =
        m.shadowTowardQibla ? 'سایه به سمت قبله' : 'خورشید در جهت قبله';
    final accent = isPassed
        ? _palette.textMuted.withValues(alpha: 0.65)
        : (isNow ? TopicHues.qibla : TopicHues.qibla.withValues(alpha: 0.85));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            m.shadowTowardQibla
                ? Icons.north_east_outlined
                : Icons.south_west_outlined,
            size: 15,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            '$dayLabel ${_fmtTime(m.time)}',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kindLabel,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: accent),
            ),
          ),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: TopicHues.qibla.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('اکنون',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w700,
                      color: TopicHues.qibla)),
            )
          else if (isPassed)
            Icon(Icons.check_circle_outline,
                size: 15, color: _palette.textMuted.withValues(alpha: 0.55)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) => GeoFormat.clock(t.hour, t.minute);
}

/// Tinted status chip (declination warning, sun-sign state). Local to the
/// qibla library: the old kit's FlatStatusChip did not survive the design
/// unification, and nothing else in the app needs these exact colors.
/// Type is on the shared scale (10, not the old 10.5).
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10),
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
