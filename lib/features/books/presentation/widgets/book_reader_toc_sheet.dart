import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/features/books/services/book_toc.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// فهرست واقعی کتاب.
///
/// از همان `toc` که فایل کتاب همراه دارد ساخته می‌شود (هر مدخل شمارهٔ صفحهٔ
/// چاپی خودش را دارد) و پرش مستقیم به همان صفحه می‌کند. پیش‌تر فهرست از
/// تشخیص سربرگ «باب/فصل» در متن حدس زده می‌شد و بیشتر کتاب را جا می‌گذاشت؛
/// اگر کتابی `toc` نداشت، همان سربرگ‌های حدسی به‌عنوان جایگزین می‌آیند.
class BookReaderTocSheet extends StatelessWidget {
  final List<BookPage> pages;
  final List<BookTocItem> entries;

  /// Count of the printed edition's volumes (`volumes` in the book file); `0`
  /// when the file does not say. Shown as a header chip.
  final int volumes;

  /// Page index where each volume starts, ascending — empty or single-entry
  /// when the content cannot be split by volume, in which case only the
  /// header chip shows the count and there is nothing to jump to.
  final List<int> volumeStarts;

  final int currentPage;
  final ScrollController scrollController;
  final void Function(int index) onTap;

  const BookReaderTocSheet({
    super.key,
    required this.pages,
    required this.entries,
    required this.currentPage,
    required this.scrollController,
    required this.onTap,
    this.volumes = 0,
    this.volumeStarts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // The edition's own contents when the file has one; otherwise fall back to
    // the detected headings, which is what this sheet used to show always.
    final headings = [
      for (final p in pages)
        if ((p.heading ?? '').trim().isNotEmpty) p,
    ];
    final useEdition = entries.isNotEmpty;
    final fallbackOnlyHeadings = headings.length >= (pages.length * 0.15);
    final itemCount = useEdition
        ? entries.length
        : fallbackOnlyHeadings
            ? headings.length
            : pages.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.toc, color: t.primary, size: 20),
              const SizedBox(width: 8),
              Text('فهرست کتاب',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTheme.fontFamily)),
              const SizedBox(width: 8),
              if (volumes > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('نسخهٔ چاپی: ${NumberFormat.ltrIsolated('$volumes')} جلد',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          color: t.primary,
                          fontFamily: AppTheme.fontFamily)),
                ),
              const Spacer(),
              Text('${NumberFormat.ltrIsolated('$itemCount')} مدخل',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily)),
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Divider(height: 1, color: t.outline),
        // انتخابگر جلد: چیپ هر جلد به ابتدای همان جلد می‌پرد؛ جلدِ روی
        // صفحهٔ کنونی پررنگ است، مثل نشانِ فهرستِ کنارِ صفحه.
        if (volumeStarts.length > 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var v = 0; v < volumeStarts.length; v++)
                  _volumeChip(context, v),
              ],
            ),
          ),
        Expanded(
          child: itemCount == 0
              ? const Center(child: Text('فهرست موجود نیست'))
              : ListView.separated(
                  controller: scrollController,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: t.outline.withValues(alpha: 0.4)),
                  itemBuilder: (context, index) {
                    if (!useEdition) {
                      final page =
                          fallbackOnlyHeadings ? headings[index] : pages[index];
                      return _row(
                        context,
                        title: page.label,
                        label: page.pageLabel,
                        active: page.index == currentPage,
                        onTap: () {
                          Navigator.pop(context);
                          onTap(page.index);
                        },
                      );
                    }
                    final entry = entries[index];
                    final target = entry.printPage == null
                        ? null
                        : BookToc.indexForPage(pages, entry.printPage!);
                    return _row(
                      context,
                      title: entry.title,
                      label: entry.printPage == null
                          ? '—'
                          : NumberFormat.ltrIsolated('${entry.printPage}'),
                      active: target == currentPage,
                      muted: target == null,
                      onTap: target == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              onTap(target);
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// One جلد chip: jump to that volume's first page.
  Widget _volumeChip(BuildContext context, int v) {
    final t = TimeThemeKit.of(context).palette;
    final from = volumeStarts[v];
    final to = v + 1 < volumeStarts.length ? volumeStarts[v + 1] : pages.length;
    final active = currentPage >= from && currentPage < to;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap(from);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? t.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? t.primary : t.outline.withValues(alpha: 0.6)),
        ),
        child: Text(
          'جلد ${NumberFormat.ltrIsolated('${v + 1}')}',
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? t.primary : t.textPrimary,
              fontFamily: AppTheme.fontFamily),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required String label,
    required bool active,
    required VoidCallback? onTap,
    bool muted = false,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  height: 1.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active
                      ? t.primary
                      : muted
                          ? t.textMuted
                          : t.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: active ? t.primary : t.textMuted,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.arrow_back, size: 14, color: t.primary),
              ),
          ],
        ),
      ),
    );
  }
}
