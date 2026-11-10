import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadith/services/part_books.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_chapter_screen.dart';

/// یک «کتاب» از معالم السنه — فهرست باب‌های همان کتاب.
///
/// معالم در پایگاه‌داده یک کتاب است و ۴۹ «کتاب»ِ خودِ اثر در برچسب `part` هر
/// باب می‌آیند. این صفحه همان گام میانی است: از فهرست کتاب‌ها وارد می‌شویم و
/// اینجا فقط باب‌های همین کتاب دیده می‌شوند — همان سه‌گامی که صحیح الترغیب
/// دارد (کتاب › باب › حدیث).
class MaalimBookScreen extends StatelessWidget {
  const MaalimBookScreen({
    super.key,
    required this.book,
    required this.hadithCounts,
  });

  final PartBook book;

  /// Per-bab narration counts, keyed by `chapter_index`.
  final Map<num, int> hadithCounts;

  static bool _isBab(Map<String, dynamic> ch) =>
      ((ch['is_bab'] as num?)?.toInt() ?? 1) != 0;

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.maalim;
    final t = TimeThemeKit.of(context).palette;
    final hadiths = book.chapters.fold<int>(
        0, (sum, ch) => sum + (hadithCounts[ch['chapter_index']] ?? 0));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'کتاب',
        titleWidget: Column(
          children: [
            Text('کتاب',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.primary)),
            Text('${_num(book.babCount)} باب · ${_num(hadiths)} حدیث',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: t.primary.withValues(alpha: .72))),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _band(context, accent),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 10, DsSpacing.page, 32),
                itemCount: book.chapters.length,
                itemBuilder: (context, i) =>
                    _chapterTile(context, book.chapters[i], accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _band(BuildContext context, Color accent) {
    return Container(
      width: double.infinity,
      color: accent,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          if (book.parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(book.parent!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .8))),
            ),
          Text(book.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  height: 1.9,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _chapterTile(
      BuildContext context, Map<String, dynamic> ch, Color accent) {
    final idx = ch['chapter_index'] as num;
    final printed = ch['printed_number'] as num?;
    final count = hadithCounts[idx] ?? 0;
    // `is_bab` marks a printed «N - باب»; a فصل section that opens with no باب
    // line keeps its letter instead of borrowing the next باب's number.
    final badge = _isBab(ch) ? _num(printed ?? idx) : 'ف';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MaalimChapterScreen(
              chapterIndex: idx,
              chapterTitle: (ch['name_arabic'] ?? '') as String,
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: accent)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    (ch['name_arabic'] ?? '') as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w600,
                        height: 1.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(count == 0 ? 'شرح' : '${_num(count)} حدیث',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _num(Object? n) => '$n';
