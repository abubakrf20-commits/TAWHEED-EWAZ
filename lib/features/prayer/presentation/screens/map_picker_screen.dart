import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/services/location_resolver.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Full-screen map to pick a manual location for prayer time calculation.
///
/// Tapping anywhere on the map drops a pin; the place name (reverse geocoded)
/// and the elevation above sea level are resolved live and shown in the bottom
/// card. Confirming saves the coordinates (+ city name + altitude) so the home
/// clock box shows the picked location right away.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final MapController _mapController = MapController();

  LatLng? _picked;
  String? _placeName;

  /// Name typed by the user (overrides the auto-resolved name).
  String? _customName;
  double? _altitude;
  bool _resolving = false;
  bool _confirming = false;
  bool _locating = false;

  /// Latched on the first failed map tile: the tiles need internet, but the
  /// pin, the coordinates and the confirm flow are all local and keep
  /// working. The banner below explains the blank map instead of leaving
  /// the user staring at a grey void.
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).value;
    final lat = s?.manualLat;
    final lng = s?.manualLng;
    _picked = (lat != null && lng != null && (lat != 0.0 || lng != 0.0))
        ? LatLng(lat, lng)
        : const LatLng(35.6892, 51.3890); // default: تهران
    _resolve(_picked!);
  }

  Future<void> _resolve(LatLng point) async {
    setState(() => _resolving = true);
    final name = await LocationResolver.resolvePlaceName(
        point.latitude, point.longitude);
    final elevation =
        await LocationResolver.fetchElevation(point.latitude, point.longitude);
    if (!mounted || _picked != point) return;
    setState(() {
      _placeName = name;
      _altitude = elevation;
      _resolving = false;
    });
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _picked = point;
      _placeName = null;
      _customName = null;
      _altitude = null;
    });
    _resolve(point);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('سرویس موقعیت فعال نیست. لطفاً GPS را روشن کنید.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('دسترسی به موقعیت رد شد.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _picked = point;
        _placeName = null;
        _customName = null;
        _altitude = null;
      });
      try {
        _mapController.move(point, 14);
      } catch (e) {
        // Map not attached yet — the pin still updates, so this is cosmetic.
        AppLogger.warning('MapPicker', 'Recentering failed: $e');
      }
      _resolve(point);
    } catch (e) {
      AppLogger.warning('MapPicker', e.toString());
      _showSnack('خطا در دریافت موقعیت فعلی');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// The name that will be saved: the user-typed one wins over the
  /// auto-resolved one.
  String? get _finalName => _customName?.isNotEmpty == true
      ? _customName
      : (_placeName?.isNotEmpty == true ? _placeName : null);

  Future<void> _confirm() async {
    final point = _picked;
    if (point == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final writer = ref.read(settingsProvider.notifier);
      await writer.setManualCoords(point.latitude, point.longitude);
      final name = _finalName;
      if (name != null && name.isNotEmpty) {
        await writer.setCity(name);
      }
      if (_altitude != null) {
        await ref.read(prayerTimeServiceProvider).setAltitude(_altitude);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(name != null ? 'موقعیت «$name» ذخیره شد' : 'موقعیت ذخیره شد'),
      ));
      Navigator.of(context).pop();
    } catch (e) {
      AppLogger.error('MapPicker._confirm', e);
      if (!mounted) return;
      setState(() => _confirming = false);
      _showSnack('خطا در ذخیره موقعیت');
    }
  }

  /// Lets the user type (or correct) the city name manually — for places the
  /// reverse geocoder names wrong (e.g. a nearby city instead of the actual
  /// one). The typed name overrides the resolved one.
  Future<void> _editName() async {
    final current = _finalName ?? '';
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نام شهر / منطقه'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: const InputDecoration(
            hintText: 'مثلاً تهران',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _customName = result);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final picked = _picked;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'انتخاب موقعیت از روی نقشه'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: picked ?? const LatLng(35.6892, 51.3890),
              initialZoom: 12,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.islamic.tawheeed',
                // flutter_map v8 has no error-tile widget hook — failed
                // tiles stay blank. Latch the banner once (not once per
                // tile) so the blank map reads as "offline" instead of
                // "broken"; the pin and the confirm card below are local
                // and keep working either way.
                errorTileCallback: (tile, error, stackTrace) {
                  if (!_tilesFailed && mounted) {
                    setState(() => _tilesFailed = true);
                  }
                },
              ),
              if (picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: picked,
                      width: 46,
                      height: 46,
                      child: const Icon(Icons.location_on,
                          size: 46, color: AppTheme.error),
                    ),
                  ],
                ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap'),
              ),
            ],
          ),
          if (picked != null)
            Positioned(
              left: 14,
              bottom: 236,
              child: FloatingActionButton.small(
                heroTag: 'map_my_location',
                onPressed: _locating ? null : _useMyLocation,
                backgroundColor: t.surface,
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 20),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildBottomCard(context),
          ),
          if (_tilesFailed)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: t.outline.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'نقشه بدون اینترنت بار نمی‌شود؛ نقطه را روی صفحه بزنید و «تأیید این موقعیت» را بزنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    color: t.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final picked = _picked;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (picked == null)
            const SizedBox(height: 40)
          else ...[
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: AppTheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: _resolving
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text('در حال یافتن نام مکان...',
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    color: t.textMuted)),
                          ],
                        )
                      : Text(
                          _finalName ?? 'نام مکان در دسترس نیست',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                ),
                // Manual name correction (pencil): the auto-resolved name is
                // often a nearby city — typing the real name fixes it.
                IconButton(
                  onPressed: _editName,
                  icon: Icon(
                    _customName?.isNotEmpty == true
                        ? Icons.edit
                        : Icons.edit_outlined,
                    size: 17,
                    color: t.primary,
                  ),
                  tooltip: 'ویرایش نام شهر',
                  visualDensity: VisualDensity.compact,
                ),
                if (_altitude != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terrain, size: 13, color: t.primary),
                        const SizedBox(width: 3),
                        Text('${_altitude!.round()} متر',
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: t.primary,
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${picked.latitude.toStringAsFixed(4)}، ${picked.longitude.toStringAsFixed(4)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _confirming ? null : _confirm,
                icon: _confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('تأیید این موقعیت'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'برای تغییر نقطه روی نقشه ضربه بزنید • برای اصلاح نام روی مداد بزنید',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: t.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
