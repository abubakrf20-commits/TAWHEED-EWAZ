import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/document_editor_sheet.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/photo_gallery_screen.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// اسناد هویتی متصل به یک پروفایل — با list + editor در یک صفحه. وقتی از
/// کارت یک عضو وارد می‌شود، اپ‌بار با «ویرایش عضو» (سمت چپ) بسته می‌شود.
class DocumentsScreen extends ConsumerStatefulWidget {
  final String? profileId;
  const DocumentsScreen({super.key, this.profileId});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final Color _accent = TopicHues.personalDocs;
  List<IdentityDocumentTableData>? _docs;

  /// Bound member (when opened from a profile card); null when showing everyone.
  PersonalProfileTableData? _owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      List<IdentityDocumentTableData> docs;
      if (widget.profileId != null) {
        docs = await repo.getDocumentsForProfile(widget.profileId!);
        _owner = await repo.getProfile(widget.profileId!);
      } else {
        final profiles = await repo.getAllProfiles();
        docs = <IdentityDocumentTableData>[];
        for (final pr in profiles) {
          docs.addAll(await repo.getDocumentsForProfile(pr.id));
        }
        docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
      if (mounted) setState(() => _docs = docs);
    } catch (e) {
      AppLogger.warning('documents_screen', 'load failed: $e');
      if (mounted) {
        setState(() => _docs = const []);
        AppSnackBar.error(context, 'بارگذاری داده‌ها ناموفق بود.');
      }
    }
  }

  Future<void> _openEditor([IdentityDocumentTableData? doc]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DocumentEditor(
        accent: _accent,
        profileId: widget.profileId,
        doc: doc,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          ref.invalidate(personalProfilesProvider);
        },
      ),
    );
  }

  Future<void> _delete(IdentityDocumentTableData doc) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مدرک؟'),
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
    final repo = ref.read(personalInfoRepositoryProvider);
    try {
      await repo.deleteDocument(doc.id);
      if (doc.imagesJson.isNotEmpty) {
        await AttachmentStorage.deleteStoredList(_jsonList(doc.imagesJson));
      }
    } catch (e) {
      // Uncaught before this: the delete threw, `_load` never ran, and the row
      // sat there with no message — so the reader could not tell a failed
      // delete from a slow one. The document is still there; say so.
      AppLogger.warning('documents_screen', 'document delete failed: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'مدرک حذف نشد و هنوز در فهرست است.',
        onRetry: () => _delete(doc),
      );
      return;
    }
    _load();
  }

  static List<String> _jsonList(String json) {
    try {
      return (jsonDecode(json) as List<dynamic>).whereType<String>().toList();
    } catch (e) {
      AppLogger.warning('documents_screen', 'operation failed: $e');
      return const [];
    }
  }

  /// Small «تصاویر n» badge next to the chevron; hidden when no photos.
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
              message: 'مشاهده عکس ${i + 1}',
              child: GestureDetector(
                onTap: () => _openGallery(paths, i, title),
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
                      color: _accent.withValues(alpha: 0.1),
                      child:
                          Icon(Icons.image_outlined, size: 18, color: _accent),
                    ),
                  ),
                ),
              ),
            ),
          if (extra > 0)
            GestureDetector(
              onTap: () => _openGallery(paths, 0, title),
              child: Container(
                width: thumb,
                height: thumb,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openGallery(List<String> paths, int index, String title) {
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

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final docs = _docs;
    final owner = _owner;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: owner == null ? 'مدارک و اسناد' : 'مدارک ${owner.name}',
        // In RTL the actions land on the physical LEFT side.
        actions: [
          if (owner != null)
            TextButton.icon(
              onPressed: () async {
                await context.push(
                  RouteNames.personalProfileEditor,
                  extra: owner,
                );
                if (mounted) _load();
              },
              style: TextButton.styleFrom(foregroundColor: _accent),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('ویرایش عضو'),
            ),
        ],
      ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن مدرک',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: _openEditor,
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: docs == null
            ? const Center(child: CircularProgressIndicator())
            : docs.isEmpty
                ? _empty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 90),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => _openEditor(d),
                          onLongPress: () => _delete(d),
                          borderColor: _accent.withValues(alpha: 0.25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_docIcon(d.docType),
                                        color: _accent),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.title,
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: AppTheme.scaledFontSize(
                                                context, 15),
                                            fontWeight: FontWeight.w700,
                                            color: t.textPrimary,
                                          ),
                                        ),
                                        if (_docTypeLabel(d.docType)
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            _docTypeLabel(d.docType),
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 12),
                                              color: t.textMuted,
                                            ),
                                          ),
                                        ],
                                        if (d.expiryDate.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'انقضا: ${_faDate(d.expiryDate)}',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 11),
                                              color: _expiryColor(d.expiryDate),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _photoCount(context, _jsonList(d.imagesJson)),
                                  Icon(Icons.chevron_left, color: t.textMuted),
                                ],
                              ),
                              if (_jsonList(d.imagesJson).isNotEmpty)
                                _photoStrip(
                                    context, _jsonList(d.imagesJson), d.title),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _empty() {
    return AppEmptyState(
      icon: Icons.folder_special_outlined,
      message: 'مدرکی ثبت نشده',
      subtitle:
          'کارت ملی، شناسنامه، پاسپورت، گواهی‌نامه و... را با عکس اضافه کنید.',
      accent: _accent,
    );
  }

  IconData _docIcon(String type) => switch (type) {
        'national_id' => Icons.badge_outlined,
        'birth_cert' => Icons.menu_book_outlined,
        'passport' => Icons.assignment_ind_outlined,
        'card' => Icons.credit_card_outlined,
        _ => Icons.description_outlined,
      };

  String _docTypeLabel(String type) => switch (type) {
        'national_id' => 'کارت ملی',
        'birth_cert' => 'شناسنامه',
        'passport' => 'پاسپورت',
        'card' => 'کارت ویژه',
        _ => 'سند',
      };

  /// Cards show the Jalali calendar the user picked in, not the stored
  /// Gregorian digits (see jalali_format.dart).
  String _faDate(String iso) => jalaliDayMonth(iso);

  Color _expiryColor(String iso) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    try {
      final p = iso.split('-');
      final due = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final now = DateTime.now();
      final days = due.difference(now).inDays;
      if (days < 0) return danger;
      if (days <= 30) return warn;
      return success;
    } catch (e) {
      AppLogger.warning('documents_screen', 'operation failed: $e');
      return t.textMuted;
    }
  }
}
