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
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/photo_gallery_screen.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Bottom-sheet editor for an identity document (add/edit).
class DocumentEditor extends ConsumerStatefulWidget {
  final String? profileId;
  final IdentityDocumentTableData? doc;
  final Color accent;
  final VoidCallback onSaved;
  const DocumentEditor({
    super.key,
    this.profileId,
    this.doc,
    required this.accent,
    required this.onSaved,
  });

  @override
  ConsumerState<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends ConsumerState<DocumentEditor> {
  late final Color _accent = widget.accent;

  late final _titleCtrl = TextEditingController(text: widget.doc?.title ?? '');
  late final _docNoCtrl =
      TextEditingController(text: widget.doc?.documentNo ?? '');
  late final _placeCtrl =
      TextEditingController(text: widget.doc?.issuedPlace ?? '');
  late final _issuedCtrl =
      TextEditingController(text: widget.doc?.issuedDate ?? '');
  late final _expiryCtrl =
      TextEditingController(text: widget.doc?.expiryDate ?? '');
  late final _notesCtrl = TextEditingController(text: widget.doc?.notes ?? '');
  late String _docType = widget.doc?.docType ?? 'national_id';

  /// Owning member. The all-documents dashboard opens this editor with a null
  /// [DocumentEditor.profileId]; saving `''` there used to park the document on
  /// no profile at all, so it vanished from every list.
  late String _ownerId = widget.profileId ?? widget.doc?.profileId ?? '';
  late final List<String> _images = _parseImg(widget.doc?.imagesJson ?? '');

  /// Paths persisted when the editor opened — files detached during this
  /// session are only deleted from disk after a successful save.
  late final List<String> _initialImages =
      _parseImg(widget.doc?.imagesJson ?? '');
  bool _saving = false;

  /// Optional details (place of issue, issue date, notes) live in a
  /// collapsible section so the add-document form stays one glance simple;
  /// it opens by default when editing a row that has them.
  late bool _showDetails = widget.doc != null &&
      ((widget.doc!.issuedPlace.isNotEmpty) ||
          (widget.doc!.issuedDate.isNotEmpty) ||
          (widget.doc!.notes.isNotEmpty));

  @override
  void initState() {
    super.initState();
    final vault = ref.read(secretVaultProvider).asData?.value;
    if (vault != null && (widget.doc?.documentNo ?? '').isNotEmpty) {
      _docNoCtrl.text = vault.decrypt(widget.doc!.documentNo);
    }
  }

  /// Growable (never const): the editor mutates the parsed list in place
  /// when photos are picked or detached; a const [] made the first add on a
  /// fresh document throw "Cannot add to an unmodifiable list".
  static List<String> _parseImg(String json) {
    if (json.isEmpty) return <String>[];
    try {
      return (jsonDecode(json) as List<dynamic>).whereType<String>().toList();
    } catch (e) {
      AppLogger.warning('document_editor_sheet', 'operation failed: $e');
      return <String>[];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _docNoCtrl.dispose();
    _placeCtrl.dispose();
    _issuedCtrl.dispose();
    _expiryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    for (final f in result) {
      final src = await _pathFor(f);
      if (src.isEmpty) continue;
      final saved = await AttachmentStorage.storeFile(src, 'document');
      // An oversized or missing file returns '' — show why, don't add it.
      if (saved.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
              context, 'فایل انتخابی پذیرفته نشد (حداکثر 10 مگابایت).');
        }
        continue;
      }
      if (mounted) setState(() => _images.add(saved));
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
      AppLogger.warning('document_editor_sheet', 'stream copy failed: $e');
      return '';
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(context, 'عنوان مدرک را وارد کنید.');
      return;
    }
    if (_ownerId.isEmpty) {
      AppSnackBar.show(context, 'صاحب مدرک را انتخاب کنید.');
      return;
    }
    setState(() => _saving = true);
    final vault = await ref.read(secretVaultProvider.future);
    final now = DateTime.now();
    String enc(String v) => vault.encrypt(v);

    final entry = IdentityDocumentTableCompanion(
      id: Value(
          widget.doc?.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      profileId: Value(_ownerId),
      docType: Value(_docType),
      title: Value(title),
      documentNo: Value(enc(_docNoCtrl.text.trim())),
      issuedPlace: Value(_placeCtrl.text.trim()),
      issuedDate: Value(_issuedCtrl.text.trim()),
      expiryDate: Value(_expiryCtrl.text.trim()),
      notes: Value(_notesCtrl.text.trim()),
      imagesJson: Value(jsonEncode(_images)),
      updatedAt: Value(now),
      createdAt: Value(widget.doc?.createdAt ?? now),
    );
    try {
      await ref.read(personalInfoRepositoryProvider).upsertDocument(entry);
    } catch (e) {
      // Without this the sheet stayed open with a permanently disabled save
      // button and the failure was never logged.
      AppLogger.error('document_editor_sheet', e);
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'ذخیرهٔ مدرک ناموفق بود.');
      return;
    }
    // Now safe to delete files the user detached during this edit (or on a
    // pre-existing row): the new imagesJson is persisted above.
    await AttachmentStorage.deleteStoredList(
        _initialImages.where((p) => !_images.contains(p)).toList());
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
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
                widget.doc == null ? 'افزودن مدرک' : 'ویرایش مدرک',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _docTypePicker(),
            if (widget.profileId == null) ...[
              const SizedBox(height: 12),
              _ownerPicker(),
            ],
            const SizedBox(height: 12),
            _field(_titleCtrl, 'عنوان مدرک (مثلاً کارت ملی جدید)'),
            _field(_docNoCtrl, 'شماره / سریال مدرک (اختیاری)', encrypted: true),
            const SizedBox(height: 2),
            _dateTile(
              context,
              label: 'تاریخ انقضا (اختیاری)',
              value: _expiryCtrl.text,
              onPicked: (iso) => setState(() => _expiryCtrl.text = iso),
              onClear: () => setState(() => _expiryCtrl.text = ''),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: t.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'جزئیات بیشتر (اختیاری)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showDetails) ...[
              _field(_placeCtrl, 'محل صدور'),
              _dateTile(
                context,
                label: 'تاریخ صدور',
                value: _issuedCtrl.text,
                onPicked: (iso) => setState(() => _issuedCtrl.text = iso),
                onClear: () => setState(() => _issuedCtrl.text = ''),
              ),
              _field(_notesCtrl, 'توضیحات', maxLines: 3),
            ],
            const SizedBox(height: 8),
            Text(
              'عکس‌ها / اسکن مدرک',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      // Tap a thumbnail to preview it full-screen.
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoGalleryScreen(
                              imagePaths: _images,
                              initialIndex: i,
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_images[i]),
                            width: 72,
                            height: 72,
                            cacheWidth:
                                (72 * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: _accent.withValues(alpha: 0.1),
                              child: Icon(Icons.description_outlined,
                                  color: _accent),
                            ),
                          ),
                        ),
                      ),
                      // Removing here only detaches the path — the stored
                      // file is cleaned up after saving, so cancelling the
                      // sheet can't lose a photo still referenced in the DB.
                      Semantics(
                        button: true,
                        label: 'حذف تصویر',
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: danger,
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                Semantics(
                  button: true,
                  label: 'افزودن تصویر',
                  child: Material(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _addImages,
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        child: Icon(Icons.add_a_photo_outlined, color: _accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    icon: const Icon(Icons.check),
                    label: const Text('ذخیره'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _docTypePicker() {
    const types = {
      'national_id': 'کارت ملی',
      'birth_cert': 'شناسنامه',
      'passport': 'پاسپورت',
      'card': 'کارت ویژه',
      'other': 'سایر اسناد',
    };
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in types.entries)
          ChoiceChip(
            label: Text(entry.value, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
            selected: _docType == entry.key,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() => _docType = entry.key),
            selectedColor: _accent.withValues(alpha: 0.2),
          ),
      ],
    );
  }

  /// Owner selector for the all-documents dashboard, which opens this editor
  /// without a bound profile. Without it a new document saved an empty
  /// `profileId` and disappeared from every member's list.
  Widget _ownerPicker() {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    const label = 'صاحب مدرک';
    final profiles = ref.watch(personalProfilesProvider).asData?.value;
    if (profiles == null) {
      return Text(label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: t.textMuted,
          ));
    }
    if (profiles.isEmpty) {
      return Text(
        'برای ثبت مدرک اول یک عضو در «پروفایل‌های هویتی» بسازید.',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          color: danger,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in profiles)
              ChoiceChip(
                label: Text(p.name.isEmpty ? 'بی‌نام' : p.name,
                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
                selected: _ownerId == p.id,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _ownerId = p.id),
                selectedColor: _accent.withValues(alpha: 0.2),
              ),
          ],
        ),
      ],
    );
  }

  /// Compact tappable Jalali date row with a clear button — replaces the
  /// free-text date fields (a Persian-keyboard «1404/07/03» never parsed).
  Widget _dateTile(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onPicked,
    required VoidCallback onClear,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final picked = await ShamsiDatePicker.show(
            context,
            initialDate: _parseIso(value),
            maxYearOffset: 12,
          );
          if (picked == null) return;
          onPicked('${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}');
        },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12)),
            border: const OutlineInputBorder(),
            suffixIcon: value.isEmpty
                ? const Icon(Icons.calendar_month_outlined, size: 20)
                : IconButton(
                    tooltip: 'پاک کردن تاریخ',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
          ),
          child: Text(
            value.isEmpty ? '—' : _faDate(value),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: value.isEmpty ? t.textMuted : t.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  static DateTime? _parseIso(String iso) {
    if (iso.isEmpty) return null;
    final p = iso.split('-');
    if (p.length != 3) return null;
    return DateTime.tryParse(iso) ??
        (int.tryParse(p[0]) != null && int.tryParse(p[1]) != null
            ? DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]))
            : null);
  }

  String _faDate(String iso) => jalaliDayMonth(iso);

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
