import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/prayer/services/location_resolver.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  final _cityController = TextEditingController();
  int _step = 0;
  ThemeModeOption _theme = ThemeModeOption.system;
  bool _locationLoading = false;
  bool _locationSelected = false;
  bool _notificationsGranted = false;
  bool _exactAlarmGranted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionStates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The exact-alarm grant happens on a system settings screen — re-read it
    // when the user comes back so the card reflects reality without a tap.
    if (state == AppLifecycleState.resumed) _refreshPermissionStates();
  }

  Future<void> _refreshPermissionStates() async {
    try {
      final exact = await PermissionService().isExactAlarmGranted();
      final notif = await PermissionService().isNotificationGranted();
      if (mounted) {
        setState(() {
          _exactAlarmGranted = exact;
          _notificationsGranted = notif || _notificationsGranted;
        });
      }
    } catch (_) {
      // Diagnostics-only refresh — never block onboarding on it.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locationLoading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        throw Exception('ابتدا موقعیت مکانی گوشی را فعال کنید.');
      }
      // PHASE-1 FIX: single source of truth for the permission *check* —
      // PermissionService (native channel) is what BootCoordinator and the
      // diagnostics screen read too. The runtime *dialog* still goes through
      // Geolocator, because the native requestPermission('location') opens
      // the app-settings page instead of the system dialog (wrong UX for a
      // first-run ask).
      var granted = await PermissionService().isLocationGranted();
      if (!granted) {
        await Geolocator.requestPermission();
        granted = await PermissionService().isLocationGranted();
      }
      if (!granted) {
        throw Exception(
            'دسترسی موقعیت مکانی داده نشد. اگر «هرگز» زدید، از تنظیمات برنامه مجاز کنید.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      var city = _cityController.text.trim();
      if (city.isEmpty) {
        city = await LocationResolver.resolvePlaceName(
                position.latitude, position.longitude) ??
            'موقعیت فعلی';
      }
      final notifier = ref.read(settingsProvider.notifier);
      final savedCity = city.isEmpty ? 'موقعیت فعلی' : city;
      await notifier.patch((s) => s.copyWith(
            useLocation: true,
            hasLocation: true,
            city: savedCity,
            manualLat: position.latitude,
            manualLng: position.longitude,
          ));
      final saved = ref.read(settingsProvider).value;
      if (saved?.hasLocation != true || saved?.city != savedCity) {
        throw StateError('ذخیره موقعیت ناموفق بود.');
      }
      if (mounted) {
        setState(() {
          _cityController.text = savedCity;
          _locationSelected = true;
        });
      }
    } catch (e) {
      AppLogger.warning('onboarding_screen', 'error: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _saveCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty && !_locationSelected) {
      setState(
          () => _error = 'شهر را وارد کنید یا از موقعیت فعلی استفاده کنید.');
      return;
    }
    setState(() => _error = null);
    if (!_locationSelected) {
      final coords = await LocationResolver.resolveCoordinates(city);
      if (coords == null) {
        // Not in the bundled city table and no geocoder (offline). Step 0 has
        // no «بعداً», so trapping the user here blocked the whole first launch:
        // keep the chosen name, leave location lookup on GPS, and continue.
        await ref.read(settingsProvider.notifier).patch((s) => s.copyWith(
              city: city,
              useLocation: true,
              hasLocation: false,
            ));
        if (mounted) {
          setState(() {
            _error = 'مختصات این شهر پیدا نشد؛ موقعیت فعلی را انتخاب کنید یا '
                'پس از اتصال از تنظیمات شهر را دوباره ثبت کنید.';
            _step = 2;
          });
        }
        return;
      }
      await ref.read(settingsProvider.notifier).patch((s) => s.copyWith(
            city: city,
            useLocation: false,
            hasLocation: true,
            manualLat: coords.lat,
            manualLng: coords.lng,
          ));
      final saved = ref.read(settingsProvider).value;
      if (saved?.hasLocation != true || saved?.city != city) {
        if (mounted) setState(() => _error = 'ذخیره شهر ناموفق بود.');
        return;
      }
    }
    if (mounted) setState(() => _step = 2);
  }

  Future<void> _requestNotifications() async {
    setState(() => _error = null);
    final granted = await PermissionService().requestNotificationPermission();
    if (mounted) {
      setState(() {
        _notificationsGranted = granted;
        _step = 3;
      });
    }
  }

  /// Explicit user tap → force:true bypasses the 24h auto-cooldown (the
  /// PermissionService contract for user-initiated requests).
  Future<void> _requestExactAlarm() async {
    setState(() => _error = null);
    final granted =
        await PermissionService().ensureExactAlarmPermission(force: true);
    if (mounted) setState(() => _exactAlarmGranted = granted);
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.patch((s) => s.copyWith(
            themeMode: _theme,
            firstLaunch: false,
            onboardingCompleted: true,
          ));
      if (ref.read(settingsProvider).value?.onboardingCompleted != true) {
        throw StateError('ذخیره تنظیمات ناموفق بود.');
      }
      // PHASE-1 FIX: persist the routing flag SplashScreen reads — splash no
      // longer depends on the settings DB row to decide shell vs onboarding.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_done_v1', true);
      } catch (_) {
        AppLogger.warning('onboarding_screen', 'operation failed');
      }
      if (mounted) context.go(RouteNames.shell);
    } catch (e) {
      AppLogger.warning('onboarding_screen', 'error: $e');
      if (mounted) {
        setState(() => _error = 'ذخیره تنظیمات ناموفق بود. دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('شروع کار با توحید'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / 4),
              const SizedBox(height: 28),
              Expanded(child: _buildStep(colors)),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.error, fontSize: AppTheme.scaledFontSize(context, 12))),
              ],
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ColorScheme colors) {
    switch (_step) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildLocationStep(colors);
      case 2:
        return _buildNotificationStep(colors);
      default:
        return _buildThemeStep(colors);
    }
  }

  /// Step 0 — the welcome.
  ///
  /// The first screen used to be the city field: a permission-shaped form with
  /// no word about what the app is. This step is static (no animation, no
  /// network) and says in four lines what the user is about to set up, so the
  /// two permission asks that follow arrive with a reason.
  Widget _buildWelcomeStep() {
    final t = TimeThemeKit.of(context).palette;
    const features = <(IconData, String, String)>[
      (
        Icons.access_time_rounded,
        'اوقات شرعی و اذان',
        'محاسبه دقیق برای شهر شما، با اذان و اقامه هر نماز'
      ),
      (
        Icons.menu_book_outlined,
        'قرآن، اذکار و دعا',
        'مصحف، اذکار صبح و شب و دعاهای روزانه'
      ),
      (
        Icons.checklist_rounded,
        'ردیاب عبادات',
        'نمازها، روزه‌ها و اهداف روزانه در یک نگاه'
      ),
      (
        Icons.notifications_active_outlined,
        'یادآوری‌ها',
        'اذان و اذکار سر وقت، حتی وقتی برنامه بسته است'
      ),
    ];
    return ListView(
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.mosque_outlined, size: 44, color: t.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'به توحید خوش آمدید',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 20),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'در سه مرحله کوتاه، برنامه را برای خودتان تنظیم می‌کنیم.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        for (final (icon, title, subtitle) in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: t.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          height: 1.5,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocationStep(ColorScheme colors) {
    return ListView(
      children: [
        Icon(Icons.location_on_outlined, size: 64, color: colors.primary),
        const SizedBox(height: 14),
        Text('اوقات شرعی دقیق‌تر',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'شهر خود را وارد کنید یا موقعیت فعلی را انتخاب کنید تا زمان نماز و قبله درست محاسبه شود.',
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        TextField(
          controller: _cityController,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveCity(),
          decoration: const InputDecoration(
            labelText: 'نام شهر',
            hintText: 'مثلاً تهران یا شیراز',
            prefixIcon: Icon(Icons.location_city_outlined),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _locationSelected = false),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _locationLoading ? null : _useCurrentLocation,
          icon: _locationLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: Text(_locationSelected
              ? 'موقعیت فعلی انتخاب شد'
              : 'استفاده از موقعیت فعلی'),
        ),
      ],
    );
  }

  Widget _buildNotificationStep(ColorScheme colors) {
    return ListView(
      children: [
        Icon(Icons.notifications_active_outlined,
            size: 64, color: colors.primary),
        const SizedBox(height: 14),
        Text('یادآوری‌های به‌موقع',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'برای دریافت اذان، اوقات نماز و یادآوری اذکار اجازه اعلان‌ها را فعال کنید. هر زمان خواستید از تنظیمات قابل تغییر است.',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
            child: ListTile(
          leading: Icon(
              _notificationsGranted
                  ? Icons.check_circle
                  : Icons.notifications_none,
              color: colors.primary),
          title: Text(_notificationsGranted
              ? 'اعلان‌ها فعال است'
              : 'اعلان‌ها هنوز فعال نشده است'),
          subtitle: const Text(
              'بدون این مجوز، زمان‌بندی اعلان‌ها ممکن است کار نکند.'),
        )),
        const SizedBox(height: 12),
        // PHASE-1 FIX: the exact-alarm ask used to jump to a system settings
        // screen from BootCoordinator with zero rationale; it now gets an
        // explained, consented step right where notifications are set up.
        Card(
          child: ListTile(
            leading: Icon(
                _exactAlarmGranted
                    ? Icons.alarm_on_outlined
                    : Icons.alarm_outlined,
                color: _exactAlarmGranted ? colors.primary : colors.outline),
            title: Text(_exactAlarmGranted
                ? 'اعلان دقیق فعال است'
                : 'اعلان دقیق (مهم)'),
            subtitle: Text(_exactAlarmGranted
                ? 'اذان و یادآوری‌ها دقیقاً سر وقت می‌آیند.'
                : 'برای اینکه اذان و یادآوری‌ها حتی در حالت صرفه‌جویی باتری سر وقت برسند، اجازه «هشدار دقیق» را بدهید. اندروید 12 به بعد این مجوز را جداگانه می‌خواهد.'),
            trailing: _exactAlarmGranted
                ? null
                : TextButton(
                    onPressed: _requestExactAlarm,
                    child: const Text('فعال کردن'),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeStep(ColorScheme colors) {
    return ListView(
      children: [
        Icon(Icons.palette_outlined, size: 64, color: colors.primary),
        const SizedBox(height: 14),
        Text('ظاهر مورد علاقه شما',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('تم برنامه را انتخاب کنید؛ بعداً از تنظیمات قابل تغییر است.',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        // PHASE-2 FIX: migrated off the deprecated RadioListTile
        // groupValue/onChanged pair to the RadioGroup wrapper.
        RadioGroup<ThemeModeOption>(
          groupValue: _theme,
          onChanged: (value) => setState(() => _theme = value ?? _theme),
          child: Column(
            children: [
              for (final option in ThemeModeOption.values)
                RadioListTile<ThemeModeOption>(
                  value: option,
                  title: Text(_themeLabel(option)),
                  secondary: Icon(_themeIcon(option)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_step == 0) {
      return SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('شروع')));
    }
    if (_step == 1) {
      return SizedBox(
          width: double.infinity,
          child:
              FilledButton(onPressed: _saveCity, child: const Text('ادامه')));
    }
    if (_step == 2) {
      return Row(children: [
        Expanded(
            child: TextButton(
                onPressed: () => setState(() => _step = 3),
                child: const Text('بعداً'))),
        Expanded(
            child: FilledButton(
                onPressed: _requestNotifications,
                child: const Text('فعال‌سازی اعلان‌ها'))),
      ]);
    }
    return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saving ? null : _finish,
          child: _saving
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator())
              : const Text('شروع استفاده از برنامه'),
        ));
  }

  String _themeLabel(ThemeModeOption option) => switch (option) {
        ThemeModeOption.light => 'روشن',
        ThemeModeOption.dark => 'تاریک',
        ThemeModeOption.system => 'هماهنگ با سیستم',
      };

  IconData _themeIcon(ThemeModeOption option) => switch (option) {
        ThemeModeOption.light => Icons.light_mode_outlined,
        ThemeModeOption.dark => Icons.dark_mode_outlined,
        ThemeModeOption.system => Icons.brightness_auto_outlined,
      };
}
