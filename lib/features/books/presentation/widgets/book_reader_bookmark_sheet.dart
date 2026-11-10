import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/providers/book_bookmark_provider.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

class BookReaderBookmarkSheet extends ConsumerWidget {
  final String bookId;
  final ScrollController scrollController;
  final void Function(int page) onPageTap;

  const BookReaderBookmarkSheet({
    super.key,
    required this.bookId,
    required this.scrollController,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookBookmarkProvider(bookId));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.bookmarks,
                  color: TimeThemeKit.of(context).palette.primary),
              const SizedBox(width: 8),
              Text('نشانک‌ها',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                  )),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Divider(height: 1, color: TimeThemeKit.of(context).palette.outline),
        Expanded(
          child: bookmarksAsync.when(
            data: (bookmarks) => bookmarks.isEmpty
                ? const AppEmptyState(
                    icon: Icons.bookmark_border,
                    message: 'نشانکی ثبت نشده',
                    subtitle: 'هر صفحه‌ای را که می‌خواهید بعداً پیدا کنید، '
                        'از همان صفحه نشانک کنید.',
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) => _BookmarkTile(
                      bookmark: bookmarks[index],
                      onTap: () {
                        Navigator.pop(context);
                        onPageTap(bookmarks[index].page);
                      },
                      onEdit: () =>
                          _editBookmarkNote(context, ref, bookmarks[index]),
                      onDelete: () {
                        ref
                            .read(bookBookmarkProvider(bookId).notifier)
                            .removeBookmark(bookmarks[index].id);
                      },
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            // A failed read is not «no bookmarks»: the tile list failed, the
            // marks are still there. Retry re-runs the provider.
            error: (error, __) => _BookmarkError(
              error: error,
              onRetry: () => ref.invalidate(bookBookmarkProvider(bookId)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editBookmarkNote(
      BuildContext context, WidgetRef ref, BookBookmarkData bm) async {
    final ctrl = TextEditingController(text: bm.note ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('یادداشت نشانک - صفحه ${bm.page + 1}',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontFamily,
                )),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'یادداشت خود را بنویسید...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('انصراف',
                      style: TextStyle(fontFamily: AppTheme.fontFamily)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(bookBookmarkProvider(bm.bookId).notifier)
                        .updateNote(bm.id,
                            ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: Text('ذخیره',
                      style: TextStyle(fontFamily: AppTheme.fontFamily)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  }
}

class _BookmarkError extends StatelessWidget {
  const _BookmarkError({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    // Bookmarks live in the local database, so the glyph is the generic one
    // rather than `cloud_off`: nothing here touches the network, and telling a
    // reader to check their connection would send them after the wrong thing.
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FailureView(
        id: 'book_bookmarks_load',
        title: 'نشانک‌ها باز نشدند',
        detail: 'نشانک‌های شما پاک نشده‌اند؛ فقط این فهرست باز نشد.',
        onRetry: onRetry,
        layout: FailureLayout.page,
        error: error,
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final BookBookmarkData bookmark;
  final VoidCallback onTap, onEdit, onDelete;

  const _BookmarkTile(
      {required this.bookmark,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: TimeThemeKit.of(context)
                .palette
                .outline
                .withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              TimeThemeKit.of(context).palette.primary.withValues(alpha: 0.1),
          child: Text('${bookmark.page + 1}',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: TimeThemeKit.of(context).palette.primary,
                  fontFamily: AppTheme.fontFamily)),
        ),
        title: Text('صفحه ${bookmark.page + 1}',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontFamily: AppTheme.fontFamily)),
        subtitle: bookmark.note != null && bookmark.note!.isNotEmpty
            ? Text(bookmark.note!,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontFamily: AppTheme.fontFamily,
                    color: TimeThemeKit.of(context).palette.textMuted))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit, size: 16),
                tooltip: 'ویرایش یادداشت',
                onPressed: onEdit),
            IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18,
                    color: TimeThemeKit.of(context).palette.textMuted),
                tooltip: 'حذف نشان',
                onPressed: onDelete),
          ],
        ),
        onTap: onTap,
        onLongPress: onEdit,
      ),
    );
  }
}
