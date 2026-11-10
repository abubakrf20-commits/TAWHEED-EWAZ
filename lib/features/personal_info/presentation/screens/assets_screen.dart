import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/photo_gallery_screen.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// «خودرو و املاک» — دارایی‌ها.
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final Color _accent = TopicHues.personalAssets;
  List<AssetTableData>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      final all = await repo.getAssets();
      if (mounted) setState(() => _items = all);
    } catch (e) {
      AppLogger.warning('assets_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _items = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  Future<void> _openEditor([AssetTableData? a]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssetEditor(
        accent: _accent,
        asset: a,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'خودرو و املاک'),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن دارایی',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: _openEditor,
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? _empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 90),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final a = items[i];
                      return _AssetCard(
                        asset: a,
                        accent: _accent,
                        onTap: () => _openEditor(a),
                        onDeleted: _load,
                      );
                    },
                  ),
      ),
    );
  }

  Widget _empty() {
    return AppEmptyState(
      icon: Icons.directions_car_outlined,
      message: 'دارایی‌ای ثبت نشده',
      subtitle: 'خودرو، ملک و سایر دارایی‌ها را با سند ضمیمه ثبت کنید.',
      accent: _accent,
    );
  }
}

class _AssetCard extends ConsumerWidget {
  final AssetTableData asset;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  const _AssetCard({
    required this.asset,
    required this.accent,
    required this.onTap,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    // Decoded once. This used to run three times per rebuild of the same card
    // — a full JSON parse of the attachment list for the count badge, again
    // for the strip's visibility check, and again to build the strip.
    final attachments = _jsonList(asset.attachmentsJson);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        onLongPress: () => _confirmDelete(context, ref),
        borderColor: accent.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon(asset.category), color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      if (asset.details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          asset.details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _photoCount(context, attachments),
                Icon(Icons.chevron_left, color: t.textMuted),
              ],
            ),
            if (attachments.isNotEmpty)
              _photoStrip(context, attachments, asset.title),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این دارایی؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(personalInfoRepositoryProvider).deleteAsset(asset.id);
    } catch (e) {
      // Uncaught before this: the row stayed, `onDeleted` never ran, and the
      // reader got no signal — a failed delete read exactly like a slow one.
      AppLogger.warning('assets_screen', 'asset delete failed: $e');
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        'دارایی حذف نشد و هنوز در فهرست است.',
        onRetry: () => _confirmDelete(context, ref),
      );
      return;
    }
    // Attachment cleanup stays best-effort: the row is already gone, so a
    // failed file sweep leaves an orphan, not a lie on screen.
    if (asset.attachmentsJson.isNotEmpty) {
      try {
        final paths = (jsonDecode(asset.attachmentsJson) as List<dynamic>)
            .whereType<String>()
            .toList();
        await AttachmentStorage.deleteStoredList(paths);
      } catch (e) {
        AppLogger.warning('AssetsScreen', 'attachment cleanup failed: $e');
      }
    }
    onDeleted();
  }

  IconData _icon(String cat) => switch (cat) {
        'car' => Icons.directions_car_outlined,
        'house' => Icons.home_outlined,
        'property' => Icons.corporate_fare_outlined,
        _ => Icons.inventory_2_outlined,
      };

  static List<String> _jsonList(String json) {
    if (json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List<dynamic>).whereType<String>().toList();
    } catch (e) {
      AppLogger.warning(
          'assets_screen', 'attachment list is not valid JSON, showing none: $e');
      return const [];
    }
  }

  /// Small «تصاویر n» badge next to the chevron; hidden when no files.
  Widget _photoCount(BuildContext context, List<String> paths) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final muted = TimeThemeKit.of(context).palette.textMuted;
    final fontSize = AppTheme.scaledFontSize(context, 11);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 16, color: muted),
        const SizedBox(width: 2),
        Text(
          '${paths.length}',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: fontSize,
            color: muted,
            inherit: false,
          ),
        ),
      ],
    );
  }

  /// Thumbnail strip on the card — tapping opens the full-screen gallery.
  Widget _photoStrip(BuildContext context, List<String> paths, String title) {
    const thumb = 46.0;
    const gap = 6.0;
    final visible = paths.take(4).toList();
    final extra = paths.length - visible.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < visible.length; i++)
            Tooltip(
              message: 'مشاهده سند ${i + 1}',
              child: GestureDetector(
                onTap: () => _openGallery(context, paths, i, title),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(paths[i]),
                    width: thumb,
                    height: thumb,
                    cacheWidth:
                        (thumb * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: thumb,
                      height: thumb,
                      color: accent.withValues(alpha: 0.1),
                      child:
                          Icon(Icons.image_outlined, size: 18, color: accent),
                    ),
                  ),
                ),
              ),
            ),
          if (extra > 0)
            GestureDetector(
              onTap: () => _openGallery(context, paths, 0, title),
              child: Container(
                width: thumb,
                height: thumb,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openGallery(
      BuildContext context, List<String> paths, int index, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoGalleryScreen(
          imagePaths: paths,
          initialIndex: index,
          title: title,
        ),
      ),
    );
  }
}

class _AssetEditor extends ConsumerStatefulWidget {
  final Color accent;
  final AssetTableData? asset;
  final VoidCallback onSaved;
  const _AssetEditor({
    required this.accent,
    this.asset,
    required this.onSaved,
  });

  @override
  ConsumerState<_AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends ConsumerState<_AssetEditor> {
  late final _titleCtrl =
      TextEditingController(text: widget.asset?.title ?? '');
  late final _detailsCtrl =
      TextEditingController(text: widget.asset?.details ?? '');
  late final _regCtrl =
      TextEditingController(text: widget.asset?.registrationNo ?? '');
  late final _notesCtrl =
      TextEditingController(text: widget.asset?.notes ?? '');
  late String _category = widget.asset?.category ?? 'car';
  late final List<String> _files = _parse(widget.asset?.attachmentsJson ?? '');
  bool _saving = false;

  static const _cats = {
    'car': 'خودرو',
    'house': 'خانه',
    'property': 'ملک / زمین',
    'other': 'سایر',
  };

  @override
  void initState() {
    super.initState();
    final vault = ref.read(secretVaultProvider).asData?.value;
    if (vault != null && (widget.asset?.registrationNo ?? '').isNotEmpty) {
      _regCtrl.text = vault.decrypt(widget.asset!.registrationNo);
    }
  }

  static List<String> _parse(String json) {
    // Must be mutable: the editor appends picked attachments to this list.
    if (json.isEmpty) return <String>[];
    try {
      return (jsonDecode(json) as List<dynamic>).whereType<String>().toList();
    } catch (e) {
      AppLogger.warning('assets_screen', 'attachment list parse failed: $e');
      return <String>[];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _detailsCtrl.dispose();
    _regCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;
    for (final f in result) {
      final src = await _pathFor(f);
      if (src.isEmpty) continue;
      final saved = await AttachmentStorage.storeFile(src, 'asset');
      // An oversized or missing file returns '' - show why, don't add it.
      if (saved.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
              context, 'فایل انتخابی پذیرفته نشد (حداکثر 10 مگابایت).');
        }
        continue;
      }
      if (mounted) setState(() => _files.add(saved));
    }
  }

  /// Resolves a picker file to a real disk path; some Android providers only
  /// expose a content stream, so those are copied to a temp file first.
  static Future<String> _pathFor(PlatformFile f) async {
    final direct = f.path;
    if (direct != null) return direct;
    try {
      final tmp = File('${Directory.systemTemp.path}/${f.name}');
      await tmp.openWrite().addStream(f.readAsByteStream());
      return tmp.path;
    } catch (e) {
      AppLogger.warning('assets_screen', 'stream copy failed: $e');
      return '';
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(context, 'عنوان را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    // Without this the sheet stayed open with a dead «ذخیره» button whenever
    // the write or the vault encryption threw.
    try {
      final vault = await ref.read(secretVaultProvider.future);
      final now = DateTime.now();
      final entry = AssetTableCompanion(
        id: Value(widget.asset?.id ??
            DateTime.now().millisecondsSinceEpoch.toString()),
        category: Value(_category),
        title: Value(title),
        details: Value(_detailsCtrl.text.trim()),
        registrationNo: Value(vault.encrypt(_regCtrl.text.trim())),
        attachmentsJson: Value(jsonEncode(_files)),
        notes: Value(_notesCtrl.text.trim()),
        updatedAt: Value(now),
        createdAt: Value(widget.asset?.createdAt ?? now),
      );
      await ref.read(personalInfoRepositoryProvider).upsertAsset(entry);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved();
    } catch (e) {
      AppLogger.error('assets_screen', e);
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.error(context, 'ذخیره دارایی ناموفق بود.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.page,
        right: DsSpacing.page,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: t.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text(
                widget.asset == null ? 'افزودن دارایی' : 'ویرایش دارایی',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _cats.entries)
                  ChoiceChip(
                    label: Text(e.value, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                    selected: _category == e.key,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _category = e.key),
                    selectedColor: widget.accent.withValues(alpha: 0.2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_titleCtrl, 'عنوان (مثلاً «پراید 1400»)'),
            _field(_detailsCtrl, 'جزئیات (مدل، رنگ...)'),
            _field(_regCtrl, 'شماره پلاک / شماره سند', encrypted: true),
            _field(_notesCtrl, 'توضیحات', maxLines: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: widget.accent),
                  tooltip: 'افزودن پیوست',
                  onPressed: _pickFiles,
                ),
                const SizedBox(width: 4),
                Text(
                  _files.isEmpty
                      ? 'ضمیمه سند / عکس'
                      : '${_files.length} فایل ضمیمه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: widget.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'شماره پلاک/سند رمزنگاری می‌شود.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: widget.accent),
                icon: const Icon(Icons.check),
                label: const Text('ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool encrypted = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12)),
          border: const OutlineInputBorder(),
          suffixIcon:
              encrypted ? const Icon(Icons.lock_outline, size: 16) : null,
        ),
      ),
    );
  }
}
