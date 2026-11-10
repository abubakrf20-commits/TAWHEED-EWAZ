import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show SheetHandle;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';
import 'package:tawheeed/shared/services/sound_preview_service.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/services/system_sound_catalog.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The one sound picker in the app: silent, the system default, the bundled
/// app tone, every notification tone / alarm / ringtone on the phone, and a
/// file picked from storage.
///
/// Returns the chosen wire value (see [SoundChoice]) or null when dismissed.
/// Each row has its own play/stop control and the header keeps a single
/// «توقف» action, so a long clip can always be silenced.
Future<String?> showSoundPickerSheet(
  BuildContext context, {
  required String current,
  bool includeAppTone = true,
  Future<String?> Function()? pickFile,
  String title = 'انتخاب صدای اعلان',
}) {
  // No local shape/backgroundColor here on purpose: the theme's
  // bottomSheetTheme owns the corner and the surface, exactly like every
  // other sheet in the app (see the sheet-radius contract test).
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _SoundPickerSheet(
      current: current,
      includeAppTone: includeAppTone,
      pickFile: pickFile,
      title: title,
    ),
  );
}

class _SoundPickerSheet extends StatefulWidget {
  const _SoundPickerSheet({
    required this.current,
    required this.includeAppTone,
    required this.title,
    this.pickFile,
  });

  final String current;
  final bool includeAppTone;
  final String title;
  final Future<String?> Function()? pickFile;

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  final TextEditingController _search = TextEditingController();
  final SystemSoundCatalog _catalog = SystemSoundCatalog.instance;
  final SoundPreviewService _preview = SoundPreviewService.instance;

  String _query = '';
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.addListener(_onCatalog);
    _preview.addListener(_onPreview);
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  void _onPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog.removeListener(_onCatalog);
    _preview.removeListener(_onPreview);
    _search.dispose();
    _preview.stop();
    super.dispose();
  }

  Future<void> _previewOrStop(SoundPreviewServiceCall call) async {
    final wasPlaying = _preview.isPlaying(call.key);
    final ok = await _preview.toggle(
      key: call.key,
      asset: call.asset,
      file: call.file,
      systemUri: call.systemUri,
      alarm: call.alarm,
    );
    if (!ok && !wasPlaying && mounted && !_preview.isPlaying(call.key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پخش این صدا ممکن نشد')),
      );
    }
  }

  void _choose(String wire) {
    _preview.stop();
    Navigator.pop(context, wire);
  }

  Future<void> _pickFile() async {
    final pick = widget.pickFile;
    if (pick == null || _picking) return;
    setState(() => _picking = true);
    try {
      final path = await pick();
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        _choose('custom:$path');
      }
    } on PlatformException catch (e) {
      AppLogger.warning('sound_picker', 'pick sound failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('انتخاب فایل صوتی ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool _matches(String text) {
    if (_query.isEmpty) return true;
    return text.toLowerCase().contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final accent = p.accent;
    final textStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.scaledFontSize(context, 13.5),
      color: p.textPrimary,
    );

    // The height belongs to the sheet, the radius to the THEME: a local
    // `shape:` (or a hand-copied corner) is what the sheet-radius contract
    // exists to stop.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 17),
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (_preview.playingKey != null)
                    TextButton.icon(
                      onPressed: _preview.stop,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('توقف صدا'),
                      style: TextButton.styleFrom(foregroundColor: accent),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Text(
                'صدای سیستم گوشی یا فایل خودتان — با دکمهٔ ▶ نمونه را بشنوید',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  color: p.textMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: p.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'جست‌وجوی صدا…',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    color: p.textMuted,
                  ),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: p.textMuted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: p.textMuted,
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: p.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                children: [
                  if (SoundChoice.customPath(widget.current)
                      case final customPath?) ...[
                    _sectionLabel(context, 'فایل شخصی فعلی'),
                    _row(
                      context,
                      title: customPath.split(RegExp(r'[\\/]')).last,
                      subtitle: 'فایل انتخاب‌شده از گوشی',
                      icon: Icons.audio_file_outlined,
                      wire: 'custom:$customPath',
                      textStyle: textStyle,
                      preview: SoundPreviewServiceCall(
                        key: 'custom:$customPath',
                        file: customPath,
                      ),
                    ),
                  ],
                  _sectionLabel(context, 'پایه'),
                  _row(
                    context,
                    title: 'بی‌صدا',
                    icon: Icons.volume_off_outlined,
                    wire: SoundChoice.silent,
                    textStyle: textStyle,
                  ),
                  _row(
                    context,
                    title: 'صدای پیش‌فرض سیستم',
                    icon: Icons.volume_up_outlined,
                    wire: SoundChoice.systemDefault,
                    textStyle: textStyle,
                    previewable: false,
                  ),
                  if (widget.includeAppTone)
                    _row(
                      context,
                      title: 'صدای اعلان برنامه',
                      subtitle: 'notif',
                      icon: Icons.notifications_active_outlined,
                      wire: SoundChoice.appNotification,
                      textStyle: textStyle,
                      preview: SoundPreviewServiceCall(
                        key: 'app:${SoundChoice.appNotification}',
                        asset: SoundRegistry.reminder.asset,
                      ),
                    ),
                  ..._systemSection(
                    context,
                    label: 'زنگ اعلان گوشی',
                    kind: SoundChoice.kindNotification,
                    icon: Icons.notifications_none_rounded,
                    textStyle: textStyle,
                    allowPreview: true,
                  ),
                  ..._systemSection(
                    context,
                    label: 'آلارم‌های گوشی',
                    kind: SoundChoice.kindAlarm,
                    icon: Icons.alarm_rounded,
                    textStyle: textStyle,
                    allowPreview: true,
                    alarm: true,
                  ),
                  ..._systemSection(
                    context,
                    label: 'زنگ‌های گوشی',
                    kind: SoundChoice.kindRingtone,
                    icon: Icons.ring_volume_outlined,
                    textStyle: textStyle,
                    allowPreview: true,
                  ),
                  if (widget.pickFile != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: OutlinedButton.icon(
                        onPressed: _picking ? null : _pickFile,
                        icon: _picking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.audio_file, size: 19),
                        label: Text(
                          'انتخاب فایل صوتی از گوشی',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.textPrimary,
                          side: BorderSide(color: p.outline),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _systemSection(
    BuildContext context, {
    required String label,
    required String kind,
    required IconData icon,
    required TextStyle textStyle,
    required bool allowPreview,
    bool alarm = false,
  }) {
    final p = TimeThemeKit.of(context).palette;
    final all = _catalog.ofKind(kind);
    final visible = all.where((s) => _matches(s.title)).toList();

    if (_catalog.isLoading && !_catalog.isLoaded && all.isEmpty) {
      return [
        _sectionLabel(context, label),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (visible.isEmpty) {
      return [
        _sectionLabel(context, label),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Text(
            _query.isEmpty ? 'صدایی در گوشی پیدا نشد' : 'موردی با این نام نیست',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11.5),
              color: p.textMuted,
            ),
          ),
        ),
      ];
    }
    return [
      _sectionLabel(context, label),
      for (final sound in visible)
        _row(
          context,
          title: sound.title,
          icon: icon,
          wire: sound.wire,
          textStyle: textStyle,
          preview: allowPreview
              ? SoundPreviewServiceCall(
                  key: '${sound.kind}:${sound.uri}',
                  systemUri: sound.uri,
                  alarm: alarm,
                )
              : null,
        ),
    ];
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final p = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w700,
          color: p.accent,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String wire,
    required TextStyle textStyle,
    String? subtitle,
    SoundPreviewServiceCall? preview,
    bool previewable = true,
  }) {
    final p = TimeThemeKit.of(context).palette;
    final selected = widget.current == wire;
    final playing = preview != null && _preview.isPlaying(preview.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? p.accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _choose(wire),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? p.accent : p.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? p.textPrimary : p.textSecondary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color: p.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (preview != null && previewable)
                  IconButton(
                    tooltip: playing ? 'توقف' : 'پخش نمونه',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      playing
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 22,
                      color: playing ? p.accent : p.textMuted,
                    ),
                    onPressed: () => _previewOrStop(preview),
                  ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.check_circle, size: 18, color: p.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a row's play button should preview.
class SoundPreviewServiceCall {
  const SoundPreviewServiceCall({
    required this.key,
    this.asset,
    this.file,
    this.systemUri,
    this.alarm = false,
  });

  final String key;
  final String? asset;
  final String? file;
  final String? systemUri;
  final bool alarm;
}
