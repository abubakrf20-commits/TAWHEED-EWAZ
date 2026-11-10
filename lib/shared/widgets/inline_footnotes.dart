import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';

// ═══════════════════════════════════════════════════════════════
//  پانوشت‌ها همان‌جا در متن — زیر همان حدیث یا بندی که در نسخهٔ چاپی
//  پانوشت زیرش آمده. نسخهٔ چاپی هر صفحه شماره‌گذاری را از نو شروع می‌کند
//  (`numRestart=eachPage`)، پس شمارهٔ نمایشی این‌جا محلی و پیوسته از ۱ است؛
//  `footnote_no` چاپی فقط سندِ منبع است و به خواننده نشان داده نمی‌شود.
// ═══════════════════════════════════════════════════════════════

/// پانوشت‌هایی که واقعاً چاپ می‌شوند، به همان ترتیبی که شماره می‌خورند.
///
/// فهرست زیر متن و نشانه‌های شماره در خودِ متن هر دو از همین می‌خوانند، پس
/// هیچ نشانه‌ای نمی‌تواند به ردیفی اشاره کند که پایین نیامده است.
List<Map<String, dynamic>> visibleFootnotes(
    List<Map<String, dynamic>> footnotes) {
  return [
    for (final f in footnotes)
      if (((f['text'] ?? '') as String).trim().isNotEmpty) f,
  ];
}

/// پانوشت‌های یک قطعهٔ متن، بی‌کادر، با یک خط جداکنندهٔ نازک از خودِ متن.
class InlineFootnotes extends StatelessWidget {
  const InlineFootnotes({
    super.key,
    required this.footnotes,
    this.accent = SectionColors.taraghib,
  });

  final List<Map<String, dynamic>> footnotes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rows = visibleFootnotes(footnotes);
    if (rows.isEmpty) return const SizedBox.shrink();
    final ink = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: .22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        height: 1.9,
                        color: accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      ((rows[i]['text'] ?? '') as String).trim(),
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        height: 1.9,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// یادداشت ناشر (پاراگراف مقدمهٔ باب یا کتاب) — همان‌جا در متن، بی‌کادر.
class PublisherNotice extends StatelessWidget {
  const PublisherNotice({
    super.key,
    required this.text,
    this.footnotes = const [],
    this.accent = SectionColors.taraghib,
  });

  final String text;
  final List<Map<String, dynamic>> footnotes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.only(start: 10),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: accent.withValues(alpha: .35), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              height: 1.95,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          InlineFootnotes(footnotes: footnotes, accent: accent),
        ],
      ),
    );
  }
}
