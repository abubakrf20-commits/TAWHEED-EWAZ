import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// یک بخش از مقدمه/خاتمهٔ صحیح الترغیب.
///
/// این بخش‌ها در نسخهٔ چاپی جزو احادیث شماره‌دار نیستند و در جدول‌های جداگانه
/// نگهداری می‌شوند. هر بخش فهرستی از بندهای متن است؛ سبک `a8` زیرعنوانِ
/// شماره‌دار است.
///
/// پانوشت‌ها پایین صفحه جمع نمی‌شوند: هر بند پانوشت‌های خودش را همان‌جا زیر
/// خودش دارد (`InlineFootnotes`)، چون در نسخهٔ چاپی هم پانوشت زیر همان صفحه
/// است. شماره‌گذاری چاپی هر صفحه از نو شروع می‌شود، پس شمارهٔ نمایشی محلی است.
class TaraghibMatterScreen extends StatefulWidget {
  const TaraghibMatterScreen({
    super.key,
    required this.section,
    @visibleForTesting this.service,
  });

  /// The `matter_sections` row — `id`, `kind`, `title`, `source_title`.
  final Map<String, dynamic> section;

  /// Test seam: a fake service can drive the list without a real database.
  @visibleForTesting
  final TaraghibService? service;

  @override
  State<TaraghibMatterScreen> createState() => _TaraghibMatterScreenState();
}

class _TaraghibMatterScreenState extends State<TaraghibMatterScreen> {
  late final TaraghibService _service = widget.service ?? TaraghibService();

  List<Map<String, dynamic>>? _paragraphs;

  /// Footnotes keyed by the `source_para` of the paragraph they belong to —
  /// the same paragraph index the print edition prints them under.
  Map<int, List<Map<String, dynamic>>> _footnotesByPara = const {};

  String? _error;

  String get _title => (widget.section['title'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _service.ensureReady();
      final id = (widget.section['id'] as num).toInt();
      final rows = await _service.matterParagraphs(id);
      final footnotes = await _service.footnotesOfSection(id);
      if (!mounted) return;
      setState(() {
        _paragraphs = rows;
        _footnotesByPara = _groupByParagraph(footnotes);
        _error = null;
      });
    } catch (e) {
      AppLogger.warning('taraghib_matter_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  static Map<int, List<Map<String, dynamic>>> _groupByParagraph(
      List<Map<String, dynamic>> footnotes) {
    final out = <int, List<Map<String, dynamic>>>{};
    for (final f in footnotes) {
      final p = f['source_para'];
      if (p is int) (out[p] ??= []).add(f);
    }
    return out;
  }

  Future<void> _copyAll() async {
    final rows = _paragraphs;
    if (rows == null || rows.isEmpty) return;
    final buffer = StringBuffer();
    for (final row in rows) {
      final line = _plainText((row['arabic'] ?? '') as String);
      if (line.trim().isEmpty) continue;
      buffer.writeln(line);
      final para = row['source_para'];
      final notes = para is int ? _footnotesByPara[para] : null;
      if (notes != null) {
        for (var i = 0; i < notes.length; i++) {
          final text = ((notes[i]['text'] ?? '') as String).trim();
          if (text.isNotEmpty) buffer.writeln('${i + 1}. $text');
        }
      }
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('متن این بخش کپی شد.',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5))),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = SectionColors.taraghib;
    final t = TimeThemeKit.of(context).palette;
    final total = _paragraphs?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'متن',
        titleWidget: Column(
          children: [
            Text(_title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.primary)),
            if (total > 0)
              Text('${_num(total)} بند',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: t.primary.withValues(alpha: .72))),
          ],
        ),
        actions: [
          if (total > 0)
            IconButton(
              tooltip: 'کپی متن',
              icon: const Icon(Icons.copy_all_outlined, size: 20),
              onPressed: _copyAll,
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, accent)),
    );
  }

  Widget _buildBody(BuildContext context, Color accent) {
    if (_error != null) {
      return FailureView(
        id: 'taraghib_matter_load',
        title: 'متن این بخش باز نشد',
        detail: 'متن ترغیب همراه برنامه ذخیره شده است؛ فقط خواندنش ناموفق '
            'بود.',
        onRetry: _load,
        layout: FailureLayout.page,
      );
    }
    if (_paragraphs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _paragraphs!;
    if (rows.isEmpty) {
      return Center(
        child: Text('متنی برای این بخش ثبت نشده است.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: Theme.of(context).textTheme.bodySmall?.color)),
      );
    }
    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) => _paragraph(context, rows[i], accent),
    );
  }

  Widget _paragraph(
      BuildContext context, Map<String, dynamic> row, Color accent) {
    final raw = (row['arabic'] ?? '') as String;
    final style = (row['style'] ?? '') as String;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final para = row['source_para'];
    // Both branches must be typed. A bare `const []` makes the whole ternary
    // `List<dynamic>`, which then fails to match InlineFootnotes' parameter.
    final notes = para is int
        ? (_footnotesByPara[para] ?? const <Map<String, dynamic>>[])
        : const <Map<String, dynamic>>[];

    if (style == 'a8') {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(raw,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w800,
                    height: 1.9,
                    color: accent)),
            InlineFootnotes(footnotes: notes, accent: accent),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(raw,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  height: 2,
                  color: textColor)),
          InlineFootnotes(footnotes: notes, accent: accent),
        ],
      ),
    );
  }

  /// The page numbers belong to the printed volumes, not to this screen.
  static String _plainText(String raw) => raw.replaceAll('\t', ' — ');
}

String _num(Object? n) => '$n';
