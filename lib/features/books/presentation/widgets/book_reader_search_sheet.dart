import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/book_palette.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// نتایج جست‌وجوی درون‌کتاب، یک ردیف برای هر صفحه.
///
/// پیش‌تر جست‌وجو فقط «۳ نتیجه» می‌گفت و با فلش بالا/پایین صفحه‌به‌صفحه
/// می‌پرید؛ کاربر نمی‌دانست کدام صفحه چه چیزی دارد. این شیت همان نتیجه‌ها را
/// با متنِ پیرامون نشان می‌دهد تا پرش، آگاهانه باشد.
class BookReaderSearchSheet extends StatelessWidget {
  final List<BookPage> pages;

  /// Indexes into [pages].
  final List<int> matches;
  final String query;
  final int currentPage;
  final ScrollController scrollController;
  final void Function(int index) onTap;

  const BookReaderSearchSheet({
    super.key,
    required this.pages,
    required this.matches,
    required this.query,
    required this.currentPage,
    required this.scrollController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.search, color: t.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '«$query» — ${NumberFormat.ltrIsolated('${matches.length}')} صفحه',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTheme.fontFamily),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Divider(height: 1, color: t.outline),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: t.outline.withValues(alpha: 0.4)),
            itemBuilder: (context, i) {
              final pageIndex = matches[i];
              if (pageIndex < 0 || pageIndex >= pages.length) {
                return const SizedBox.shrink();
              }
              final page = pages[pageIndex];
              final hits = TextHighlight.findMatches(page.text, query).length;
              final active = pageIndex == currentPage;
              final base = TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.7,
                color: t.textSecondary,
                fontFamily: AppTheme.fontFamily,
              );
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onTap(pageIndex);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            NumberFormat.ltrIsolated(page.pageLabel),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w700,
                                color: active ? t.primary : t.textMuted,
                                fontFamily: AppTheme.fontFamily),
                          ),
                          const SizedBox(width: 8),
                          Text('${NumberFormat.ltrIsolated('$hits')} مورد',
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 10),
                                  color: t.textMuted,
                                  fontFamily: AppTheme.fontFamily)),
                          if ((page.heading ?? '').trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                page.heading!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 10),
                                    color: t.primary.withValues(alpha: 0.8),
                                    fontFamily: AppTheme.fontFamily),
                              ),
                            ),
                          ],
                          if (active)
                            Icon(Icons.arrow_back, size: 14, color: t.primary),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          style: base,
                          children: TextHighlight.snippetSpans(
                            page.text,
                            query,
                            context: 46,
                            baseStyle: base,
                            highlightStyle: base.copyWith(
                              backgroundColor:
                                  BookPalette.searchWash.withValues(alpha: 0.5),
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
