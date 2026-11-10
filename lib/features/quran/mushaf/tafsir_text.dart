import 'package:flutter/material.dart';

import 'package:tawheeed/features/quran/services/tafsir_markup.dart';

/// Draws a tafsir body, rendering the marked-up Arabic (the verse quote and
/// the honorifics) in the Arabic face while the commentary keeps [style].
///
/// Plain tafsirs — 18 of the 19 hosted books — take the single-[Text] path
/// unchanged, so nothing moves for a book that carries no markup.
class TafsirText extends StatelessWidget {
  const TafsirText(
    this.text, {
    super.key,
    required this.style,
    required this.arabicStyle,
    required this.honorificStyle,
    this.textAlign = TextAlign.right,
  });

  final String text;
  final TextStyle style;
  final TextStyle arabicStyle;
  final TextStyle honorificStyle;
  final TextAlign textAlign;

  static TextStyle? _spanStyle(
    TafsirRunKind kind,
    TextStyle arabic,
    TextStyle honorific,
  ) =>
      switch (kind) {
        TafsirRunKind.plain => null,
        TafsirRunKind.verse => arabic,
        TafsirRunKind.honorific => honorific,
      };

  @override
  Widget build(BuildContext context) {
    final runs = TafsirMarkup.parse(text);
    if (runs.length == 1 && runs.first.kind == TafsirRunKind.plain) {
      return Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final run in runs)
            TextSpan(
              text: run.text,
              style: _spanStyle(run.kind, arabicStyle, honorificStyle),
            ),
        ],
      ),
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      style: style,
    );
  }
}
