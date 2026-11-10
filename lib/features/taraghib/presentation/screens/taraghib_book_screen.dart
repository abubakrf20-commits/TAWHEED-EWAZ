import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// یک کتاب از صحیح الترغیب و الترهیب — فهرست باب‌های همان کتاب.
///
/// ساختار چاپی اثر سه سطح دارد: کتاب ← باب ← حدیث. شمارهٔ باب در هر کتاب از
/// یک شروع می‌شود، پس یک باب تنها با (کتاب، شمارهٔ باب) شناخته می‌شود و هر
/// ردیف همین جفت را به صفحهٔ باب می‌فرستد.
///
/// پانوشت‌های خودِ سرِ کتاب (پانوشت عنوان و یادداشت ناشر) بالای فهرست باب‌ها،
/// همان‌جا که در نسخهٔ چاپی چاپ شده‌اند، نمایش داده می‌شوند.
class TaraghibBookScreen extends StatefulWidget {
  const TaraghibBookScreen({
    super.key,
    required this.book,
    @visibleForTesting this.service,
  });

  /// The `books` row this page lists — `id`, `title_persian`, `book_no`,
  /// `hadith_count`, `chapter_count`.
  final Map<String, dynamic> book;

  /// Test seam: a fake service can drive the list without a real database.
  @visibleForTesting
  final TaraghibService? service;

  @override
  State<TaraghibBookScreen> createState() => _TaraghibBookScreenState();
}

class _TaraghibBookScreenState extends State<TaraghibBookScreen> {
  late final TaraghibService _service = widget.service ?? TaraghibService();

  List<Map<String, dynamic>>? _chapters;
  Map<num, int>? _hadithCounts;
  List<Map<String, dynamic>> _headingFootnotes = const [];
  Map<int, List<Map<String, dynamic>>> _preambleFootnotes = const {};
  List<Map<String, dynamic>> _preambles = const [];
  String? _error;

  int get _bookId => (widget.book['id'] as num).toInt();

  String get _title => (widget.book['title_persian'] ?? '') as String;

  /// The printed book number — null for the divider book the edition prints
  /// without a numeral, which must not borrow the next book's number.
  Object? get _bookNo => widget.book['book_no'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _service.ensureReady();
      final chapters = await _service.chaptersForBook(_bookId);
      final counts = await _service.hadithCountsPerChapter(_bookId);
      final footnotes = await _service.footnotesOfBook(_bookId);
      final preambles = await _service.preamblesOfBook(_bookId);
      final headingNotes = <Map<String, dynamic>>[];
      final preambleNotes = <int, List<Map<String, dynamic>>>{};
      for (final note in footnotes) {
        final preambleId = (note['preamble_id'] as num?)?.toInt();
        if (preambleId != null) {
          (preambleNotes[preambleId] ??= []).add(note);
        } else {
          headingNotes.add(note);
        }
      }
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _hadithCounts = counts;
        _headingFootnotes = headingNotes;
        _preambleFootnotes = preambleNotes;
        _preambles = preambles;
        _error = null;
      });
    } catch (e) {
      AppLogger.warning('taraghib_book_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = SectionColors.taraghib;
    final t = TimeThemeKit.of(context).palette;
    final chapters = _chapters ?? const <Map<String, dynamic>>[];
    final total = chapters.length;
    final hadiths = widget.book['hadith_count'] as num? ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'کتاب',
        titleWidget: Column(
          children: [
            Text(_bookNo == null ? 'کتاب' : 'کتاب ${_num(_bookNo)}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.primary)),
            if (total > 0)
              Text('${_num(total)} باب · ${_num(hadiths)} حدیث',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: t.primary.withValues(alpha: .72))),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody(context, accent, chapters)),
    );
  }

  Widget _buildBody(
      BuildContext context, Color accent, List<Map<String, dynamic>> chapters) {
    final error = _error;
    if (error != null) {
      return FailureView(
        id: 'taraghib_book_load',
        title: 'فهرست باب‌های این کتاب باز نشد',
        detail: 'متن ترغیب همراه برنامه ذخیره شده است؛ فقط خواندن فهرست '
            'ناموفق بود.',
        onRetry: _load,
        layout: FailureLayout.page,
      );
    }
    if (_chapters == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final intro = _buildBookIntro(accent);
    return Column(
      children: [
        _buildHeaderBand(accent),
        Expanded(
          child: chapters.isEmpty
              ? Center(
                  child: Text('بابی برای این کتاب ثبت نشده است.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: Theme.of(context).textTheme.bodySmall?.color)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.page, 10, DsSpacing.page, 32),
                  itemCount: chapters.length + (intro == null ? 0 : 1),
                  itemBuilder: (context, i) {
                    if (intro != null && i == 0) return intro;
                    return _chapterTile(chapters[intro == null ? i : i - 1],
                        accent);
                  },
                ),
        ),
      ],
    );
  }

  /// The book's own printed matter — its heading notes and the publisher's
  /// notice with the notes printed under it. It rides the chapter list, so a
  /// long notice scrolls away instead of pinning itself under the title.
  Widget? _buildBookIntro(Color accent) {
    if (_headingFootnotes.isEmpty && _preambles.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineFootnotes(footnotes: _headingFootnotes, accent: accent),
          for (final preamble in _preambles)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PublisherNotice(
                text: ((preamble['arabic'] ?? '') as String).trim(),
                footnotes: _preambleFootnotes[
                        (preamble['id'] as num?)?.toInt()] ??
                    const [],
                accent: accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderBand(Color accent) {
    return Container(
      width: double.infinity,
      color: accent,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        _title,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14),
            fontWeight: FontWeight.w700,
            height: 1.9,
            color: Colors.white),
      ),
    );
  }

  Widget _chapterTile(Map<String, dynamic> ch, Color accent) {
    final idx = ch['chapter_index'] as num;
    final printed = ch['printed_number'] as num?;
    final badge = printed ?? idx.toInt();
    final count = _hadithCounts?[idx.toDouble()] ?? 0;
    final title = (ch['name_persian'] ?? '') as String;
    final arabic = (ch['name_arabic'] ?? '') as String;
    final note = (ch['note'] ?? '') as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibChapterScreen(
              bookId: _bookId,
              bookTitle: _title,
              chapterIndex: idx,
              chapterTitle: arabic.isNotEmpty ? arabic : title,
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(_num(badge),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : arabic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            height: 1.7,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      if (count == 0 && note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('یادداشت ناشر',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w600,
                                  color: accent)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  count == 0 ? 'بدون حدیث' : '${_num(count)} حدیث',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: Theme.of(context).textTheme.bodySmall?.color),
                ),
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
