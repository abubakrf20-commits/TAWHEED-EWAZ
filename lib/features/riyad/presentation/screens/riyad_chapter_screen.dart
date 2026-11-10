import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';

// ═══════════════════════════════════════════════════════════════
//  یک باب از ریاض الصالحین — باکس عنوان باب در ابتدای متن،
//  احادیث با شمارهٔ پیوستهٔ همین نسخه («حدیث X»، 1 تا 1897)،
//  پرش بین احادیث با scrollable_positioned_list (دقیق برای هر فاصله‌ای،
//  حتی انتهای لیست). پانوشت‌ها همان‌جا که در نسخهٔ چاپی چاپ شده‌اند
//  زیر میزبان خود می‌آیند: زیر هر حدیث، زیر عنوان باب و زیر بندهای
//  آیه‌ها/یادداشتِ آغاز باب. بابی که در این شرح حدیث تازه‌ای ندارد،
//  همان‌جا شرحِ خودش را نشان می‌دهد.
// ═══════════════════════════════════════════════════════════════

const _riyadAccent = TopicHues.riyad;

class RiyadChapterScreen extends StatefulWidget {
  const RiyadChapterScreen({
    super.key,
    required this.chapterIndex,
    required this.chapterTitle,
    this.initialHadithNumber,
    this.initialQuery = '',
    @visibleForTesting this.service,
  });

  final num chapterIndex;
  final String chapterTitle;
  final int? initialHadithNumber;

  /// The word a deep-search hit was opened for — highlighted in the text and
  /// used to pick the entry when no hadith number was handed over.
  final String initialQuery;

  /// Test seam: the caller's service, so a widget test can drive a fake
  /// database without the download flow.
  @visibleForTesting
  final RiyadService? service;

  @override
  State<RiyadChapterScreen> createState() => _RiyadChapterScreenState();
}

class _RiyadChapterScreenState extends State<RiyadChapterScreen> {
  late final RiyadService _service = widget.service ?? RiyadService();
  List<Map<String, dynamic>>? _entries;
  List<Map<String, dynamic>> _preambles = const [];
  Map<int, List<Map<String, dynamic>>> _hadithFootnotes = const {};
  Map<int, List<Map<String, dynamic>>> _preambleFootnotes = const {};
  List<Map<String, dynamic>> _headingFootnotes = const [];

  /// The thrown object, not its text: the panel renders it in debug builds
  /// only, so a reader never meets a table name where an explanation belongs.
  Object? _error;

  // item 0 = کارت عنوان باب؛ item i+1 = ورودی i
  final _itemCtrl = ItemScrollController();
  final _posListener = ItemPositionsListener.create();
  int _current = 0;
  Timer? _saveDebounce;

  String get _prefKey => 'riyad_last_${widget.chapterIndex}';

  bool _isHadithAt(int i) {
    final no = _entries?[i]['hadith_number'];
    return no is int && no > 0;
  }

  int _printNoAt(int i) {
    final no = _entries?[i]['hadith_number'];
    return (no is int) ? no : 0;
  }

  List<int> _hadithEntryIndices() {
    final out = <int>[];
    for (var i = 0; i < (_entries?.length ?? 0); i++) {
      if (_isHadithAt(i)) out.add(i);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _posListener.itemPositions.addListener(_onPositions);
  }

  @override
  void dispose() {
    _posListener.itemPositions.removeListener(_onPositions);
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _onPositions() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _entries == null || _entries!.isEmpty) return;
      final positions = _posListener.itemPositions.value.toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      for (final p in positions) {
        if (p.itemTrailingEdge > 0.15) {
          final entry =
              (p.index > 0 ? p.index - 1 : 0).clamp(0, _entries!.length - 1);
          if (entry != _current) setState(() => _current = entry);
          _savePos(entry);
          return;
        }
      }
    });
  }

  Future<void> _savePos(int i) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefKey, i);
  }

  Future<int?> _loadSavedPos() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_prefKey);
  }

  /// The first entry whose actual text carries [query] under the reader's own
  /// normalizer — the same one the highlight uses, so a jump always lands on a
  /// card that really paints the word.
  int _firstQueryEntry(String query) {
    final entries = _entries;
    if (entries == null || query.trim().isEmpty) return -1;
    for (var i = 0; i < entries.length; i++) {
      final raw = (entries[i]['arabic'] ?? '') as String;
      if (TextHighlight.findMatches(raw, query).isNotEmpty) return i;
    }
    return -1;
  }

  Future<void> _load() async {
    // A retry must clear the previous failure before it starts, or the panel
    // stays on screen on top of the loading state it was replaced by.
    if (_error != null) setState(() => _error = null);
    try {
      await _service.ensureReady();
      final chapter = await _service.chapterOf(widget.chapterIndex);
      final rows = await _service.entriesOfChapter(widget.chapterIndex);
      final chapterId = (chapter?['id'] as num?)?.toInt();
      final footnotes = chapterId == null
          ? const <Map<String, dynamic>>[]
          : await _service.footnotesOfChapter(chapterId);
      final preambles = chapterId == null
          ? const <Map<String, dynamic>>[]
          : await _service.preamblesOfChapter(chapterId);
      final hadithNotes = <int, List<Map<String, dynamic>>>{};
      final preambleNotes = <int, List<Map<String, dynamic>>>{};
      final headingNotes = <Map<String, dynamic>>[];
      for (final note in footnotes) {
        final hadithId = (note['hadith_id'] as num?)?.toInt();
        final preambleId = (note['preamble_id'] as num?)?.toInt();
        if (hadithId != null) {
          (hadithNotes[hadithId] ??= []).add(note);
        } else if (preambleId != null) {
          (preambleNotes[preambleId] ??= []).add(note);
        } else {
          headingNotes.add(note);
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _preambles = preambles;
        _hadithFootnotes = hadithNotes;
        _preambleFootnotes = preambleNotes;
        _headingFootnotes = headingNotes;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _entries == null || _entries!.isEmpty) return;
        int target = 0;
        if (widget.initialHadithNumber != null) {
          final idx = _entries!.indexWhere((e) =>
              (e['hadith_number'] as int?) == widget.initialHadithNumber);
          if (idx != -1) target = idx;
        } else if (widget.initialQuery.trim().isNotEmpty) {
          final idx = _firstQueryEntry(widget.initialQuery);
          if (idx != -1) target = idx;
        } else {
          final saved = await _loadSavedPos();
          if (saved != null && saved >= 0 && saved < _entries!.length) {
            target = saved;
          }
        }
        setState(() => _current = target);
        if (target > 0 && _itemCtrl.isAttached) {
          _itemCtrl.jumpTo(index: target + 1);
        }
      });
    } catch (e) {
      AppLogger.warning('riyad_chapter_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _jumpTo(int entryIndex, {bool animate = true}) {
    if (_entries == null || entryIndex < 0 || entryIndex >= _entries!.length) {
      return;
    }
    setState(() => _current = entryIndex);
    _savePos(entryIndex);
    if (!_itemCtrl.isAttached) return;
    _itemCtrl.scrollTo(
      index: entryIndex + 1,
      alignment: 0.02,
      duration: Duration(milliseconds: animate ? 380 : 1),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = _riyadAccent;
    final total = _entries?.length ?? 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text('باب ${_num(widget.chapterIndex.toInt())}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: AppTheme.scaledFontSize(context, 15))),
            if (total > 0)
              Text(
                  _isHadithAt(_current)
                      ? 'حدیث ${_num(_printNoAt(_current))}'
                      : 'مقدمهٔ باب',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .9))),
          ],
        ),
        actions: [
          if (total > 1)
            IconButton(
              tooltip: 'پرش به حدیث',
              icon: const Icon(Icons.numbers_outlined, size: 20),
              onPressed: _showJumpSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(widget.chapterTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w700,
                    height: 1.9,
                    color: Colors.white)),
          ),
          if (total > 1) _buildJumpBar(accent),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBabHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _riyadAccent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _riyadAccent.withValues(alpha: .25)),
          ),
          child: Text(widget.chapterTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w800,
                  height: 1.9,
                  color: _riyadAccent)),
        ),
        if (_headingFootnotes.isNotEmpty)
          InlineFootnotes(footnotes: _headingFootnotes, accent: _riyadAccent),
        for (final preamble in _preambles)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PublisherNotice(
              text: ((preamble['arabic'] ?? '') as String).trim(),
              footnotes:
                  _preambleFootnotes[(preamble['id'] as num?)?.toInt()] ??
                      const [],
              accent: _riyadAccent,
            ),
          ),
      ],
    );
  }

  Widget _buildJumpBar(Color accent) {
    final hadithIdx = _hadithEntryIndices();
    if (hadithIdx.isEmpty) return const SizedBox.shrink();
    // A fixed 46 px bar clipped its chips as soon as the reader raised the
    // text scale; size it from the scaled font instead.
    final chipHeight = AppTheme.scaledFontSize(context, 12) + 20;
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.switch_access_shortcut,
              size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 4),
          Text('احادیث:',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: chipHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: hadithIdx.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, hi) {
                  final entryIdx = hadithIdx[hi];
                  final sel = entryIdx == _current;
                  return GestureDetector(
                    onTap: () => _jumpTo(entryIdx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(minWidth: 36),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? accent : accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color:
                                sel ? accent : accent.withValues(alpha: .18)),
                      ),
                      child: Text(_num(_printNoAt(entryIdx)),
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : accent)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showJumpSheet() {
    final hadithIdx = _hadithEntryIndices();
    if (hadithIdx.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: TimeThemeKit.of(context).palette.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              Text('پرش به حدیث',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: AppTheme.scaledFontSize(context, 14))),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  // Six columns only where six numbers fit: on a 320 dp phone
                  // a fixed six made each cell ~40 dp wide.
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 62,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.4),
                  itemCount: hadithIdx.length,
                  itemBuilder: (_, hi) {
                    final entryIdx = hadithIdx[hi];
                    final sel = entryIdx == _current;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pop(context);
                        _jumpTo(entryIdx);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel
                              ? _riyadAccent
                              : _riyadAccent.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _riyadAccent.withValues(
                                  alpha: sel ? 1 : .18)),
                        ),
                        child: Text(_num(_printNoAt(entryIdx)),
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : _riyadAccent)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return FailureView(
        id: 'riyad_chapter_load',
        title: 'متن این باب باز نشد',
        detail: 'متن از پایگاه‌دادهٔ خودِ کتاب خوانده می‌شود و جایی نرفته است؛ '
            'این صفحه فقط نتوانست بخواندش.',
        onRetry: _load,
        layout: FailureLayout.page,
        error: _error,
      );
    }
    if (_entries == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_entries!.isEmpty) {
      // 7 ببs of the edition carry no new narration: their text is the verses
      // and the شرح itself, which arrive as the باب's opening.
      if (_preambles.isEmpty && _headingFootnotes.isEmpty) {
        return Center(
            child: Text('موردی در این باب ثبت نشده است.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Theme.of(context).textTheme.bodySmall?.color)));
      }
      return ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 24),
        children: [
          _buildBabHeading(),
          const SizedBox(height: 14),
          Text('در این نسخه، این باب حدیث تازه‌ای ندارد و شرحِ آن همین‌جاست.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      );
    }
    return ScrollablePositionedList.builder(
      itemScrollController: _itemCtrl,
      itemPositionsListener: _posListener,
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 24),
      itemCount: _entries!.length + 1,
      itemBuilder: (context, item) {
        if (item == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildBabHeading(),
          );
        }
        final i = item - 1;
        final row = _entries![i];
        final raw = ((row['arabic'] ?? '') as String).trim();
        final isHadith = _isHadithAt(i);
        final printNo = _printNoAt(i);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _EntryCard(
            badgeLabel: isHadith ? 'حدیث ${_num(printNo)}' : '',
            isHadith: isHadith,
            rawText: raw,
            highlightQuery: widget.initialQuery,
            isCurrent: i == _current,
            footnotes:
                _hadithFootnotes[(row['id'] as num?)?.toInt()] ?? const [],
            onTapCard: () {
              setState(() => _current = i);
              _savePos(i);
            },
          ),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(
      {required this.badgeLabel,
      required this.isHadith,
      required this.rawText,
      required this.highlightQuery,
      required this.isCurrent,
      required this.onTapCard,
      this.footnotes = const []});
  final String badgeLabel;
  final bool isHadith;
  final String rawText;
  final String highlightQuery;
  final bool isCurrent;
  final VoidCallback onTapCard;

  /// The print edition's notes printed under this very hadith, in order.
  final List<Map<String, dynamic>> footnotes;

  /// The number each printed note wears, keyed by the line of [rawText] the
  /// print edition sets it against. Several notes may share one line.
  Map<int, List<int>> _markersByLine(int lineCount) {
    final notes = visibleFootnotes(footnotes);
    final out = <int, List<int>>{};
    for (var i = 0; i < notes.length; i++) {
      final line = (notes[i]['anchor_line'] as num?)?.toInt();
      if (line == null || line < 0 || line >= lineCount) continue;
      (out[line] ??= <int>[]).add(i + 1);
    }
    return out;
  }

  /// The hadith as it is read on screen: each printed note's number set against
  /// the line the print edition anchors it to. The markers live in this display
  /// string only — [rawText] stays byte-exact for copy and share.
  Widget _buildText(BuildContext context) {
    final style = TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 13.5),
        height: 1.9);
    final markerStyle = style.copyWith(
        fontSize: AppTheme.scaledFontSize(context, 9.5),
        fontWeight: FontWeight.w800,
        color: _riyadAccent);
    final query = highlightQuery.trim();
    final lines = rawText.split('\n');
    final marks = _markersByLine(lines.length);
    if (query.isEmpty && marks.isEmpty) {
      return SelectableText(rawText,
          style: style,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl);
    }
    final children = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) children.add(const TextSpan(text: '\n'));
      if (lines[i].isNotEmpty) {
        if (query.isEmpty) {
          children.add(TextSpan(text: lines[i]));
        } else {
          children.addAll(TextHighlight.spans(lines[i], query,
              baseStyle: style,
              highlightStyle:
                  TextHighlight.defaultHighlightStyle(context, base: style)));
        }
      }
      final numbers = marks[i];
      if (numbers != null) {
        // Glued to the line's last word on purpose: no space means no break
        // opportunity and nothing for justify to stretch, so the number can
        // never drift away from the word it marks.
        children.add(TextSpan(text: numbers.join(','), style: markerStyle));
      }
    }
    return SelectableText.rich(TextSpan(style: style, children: children),
        textAlign: TextAlign.justify, textDirection: TextDirection.rtl);
  }

  @override
  Widget build(BuildContext context) {
    const accent = _riyadAccent;
    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCurrent ? accent : accent.withValues(alpha: 0.12),
              width: isCurrent ? 1.4 : 1),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The badge and the «در حال مطالعه» chip are the only flexible
                // part of this row: at 2× text they together outgrew the card
                // and pushed the copy/share buttons off it.
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHadith)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: isCurrent
                                    ? accent
                                    : accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(badgeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isCurrent ? Colors.white : accent)),
                          ),
                        ),
                      if (isHadith) const SizedBox(width: 8),
                      if (isCurrent)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(999)),
                            child: Text('در حال مطالعه',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 9),
                                    fontWeight: FontWeight.w700,
                                    color: accent)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'کپی متن',
                  icon: Icon(Icons.copy_rounded,
                      size: 18,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: rawText));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        content: Text('متن کپی شد',
                            style:
                                TextStyle(fontFamily: AppTheme.fontFamily))));
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'اشتراک‌گذاری',
                  icon: Icon(Icons.share_outlined,
                      size: 18,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                  onPressed: () async {
                    // Same footer contract as every other share: the app line
                    // is what carries the signature, never a hand-written
                    // header alone.
                    await ShareService.shareText(
                      'ریاض الصالحین\n\n$rawText\n\n'
                      '${ShareService.appLine('ریاض الصالحین')}',
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: isHadith ? 8 : 4),
            _buildText(context),
            if (footnotes.isNotEmpty)
              InlineFootnotes(footnotes: footnotes, accent: accent),
          ],
        ),
      ),
    );
  }
}

String _num(Object? n) => '$n';
