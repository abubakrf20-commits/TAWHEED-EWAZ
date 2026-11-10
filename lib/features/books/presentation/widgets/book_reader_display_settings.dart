import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/presentation/book_palette.dart';

/// فونت‌های متن اصلی کتاب‌ها.
///
/// The two app-wide faces are offered here too: «حریر» and «تیکا» are book
/// faces, and a reader should not have to change the whole app's font to read
/// one chapter in them. Keys are the pubspec families, which is also what
/// `reader_font` persists.
const readerFonts = <String, String>{
  'TKT-Tika': 'تیکا (پیش‌فرض)',
  'Vazirmatn': 'وزیرمتن',
  'Amiri': 'امیری',
  'Harir': 'حریر',
  'Calibri': 'کالیبری',
  'Parastoo': 'پرستو',
  'Sakkal Majalla': 'سکّال مجله',
  'Sultan Medium': 'سلطان میدیوم',
  'Tabliq': 'تبلیغ',
};

/// عرض حاشیهٔ متن در سه پله — باریک/عادی/پهن.
const readerMarginSteps = <double>[16, 26, 38];
const readerMarginLabels = <String>['باریک', 'عادی', 'پهن'];

class BookReaderDisplaySettings extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final String paperKey;
  final int marginStep;
  final bool justify;
  final BookFootnoteMode footnoteMode;
  final bool mirrorMargin;
  final bool chapterRecto;
  final bool titlePage;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<String> onPaperChanged;
  final ValueChanged<int> onMarginChanged;
  final ValueChanged<bool> onJustifyChanged;
  final ValueChanged<BookFootnoteMode> onFootnoteModeChanged;
  final ValueChanged<bool> onMirrorMarginChanged;
  final ValueChanged<bool> onChapterRectoChanged;
  final ValueChanged<bool> onPageTitleChanged;

  const BookReaderDisplaySettings({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.paperKey,
    required this.marginStep,
    required this.justify,
    required this.footnoteMode,
    required this.mirrorMargin,
    required this.chapterRecto,
    required this.titlePage,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onFontFamilyChanged,
    required this.onPaperChanged,
    required this.onMarginChanged,
    required this.onJustifyChanged,
    required this.onFootnoteModeChanged,
    required this.onMirrorMarginChanged,
    required this.onChapterRectoChanged,
    required this.onPageTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return SafeArea(
      top: false,
      // The sheet grew a row (margin + alignment): on a 320 dp screen at a
      // large text scale it no longer fits a fixed sheet, so it scrolls
      // instead of overflowing.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_size, size: 18, color: t.primary),
                const SizedBox(width: 8),
                Text('تنظیمات نمایش',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTheme.fontFamily)),
              ],
            ),
            const SizedBox(height: 12),
            _label(context, 'اندازهٔ متن'),
            Row(
              children: [
                Icon(Icons.text_decrease, size: 18, color: t.textMuted),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    onChanged: onFontSizeChanged,
                  ),
                ),
                Icon(Icons.text_increase, size: 18, color: t.textMuted),
                SizedBox(
                  width: 30,
                  child: Text('${fontSize.round()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily)),
                ),
              ],
            ),
            _label(context, 'فاصلهٔ خطوط'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: lineHeight,
                    min: 1.2,
                    max: 3.0,
                    divisions: 18,
                    onChanged: onLineHeightChanged,
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(lineHeight.toStringAsFixed(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily)),
                ),
              ],
            ),
            _label(context, 'فونت متن'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in readerFonts.entries)
                  _Chip(
                    label: entry.value,
                    fontFamily: entry.key,
                    selected: fontFamily == entry.key,
                    onTap: () => onFontFamilyChanged(entry.key),
                  ),
              ],
            ),
            _label(context, 'کاغذ صفحه'),
            Row(
              children: [
                for (final paper in BookPalette.papers)
                  _PaperDot(
                    paper: paper,
                    selected: paperKey == paper.key,
                    onTap: () => onPaperChanged(paper.key),
                  ),
                const Spacer(),
                Text(
                  BookPalette.paperFor(paperKey).label,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily),
                ),
              ],
            ),
            _label(context, 'حاشیهٔ صفحه'),
            Row(
              children: [
                for (var i = 0; i < readerMarginLabels.length; i++)
                  _Chip(
                    label: readerMarginLabels[i],
                    selected: marginStep == i,
                    onTap: () => onMarginChanged(i),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: justify,
              onChanged: onJustifyChanged,
              title: Text('متن دو طرف تراز',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontFamily: AppTheme.fontFamily)),
              subtitle: Text('هر دو لبهٔ سطرها صاف؛ خاموش = لبهٔ چپ آزاد',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            ),
            _label(context, 'پاورقی پایین صفحه'),
            Row(
              children: [
                for (final mode in BookFootnoteMode.values)
                  Expanded(
                    child: _ModeChip(
                      label: mode.label,
                      selected: footnoteMode == mode,
                      onTap: () => onFootnoteModeChanged(mode),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                footnoteMode.description,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                    fontFamily: AppTheme.fontFamily),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: titlePage,
              onChanged: onPageTitleChanged,
              title: Text('صفحهٔ عنوان',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontFamily: AppTheme.fontFamily)),
              subtitle: Text('کتاب با صفحهٔ عنوان باز شود، مثل چاپ',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: chapterRecto,
              onChanged: onChapterRectoChanged,
              title: Text('فصل از برگ درست',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontFamily: AppTheme.fontFamily)),
              subtitle: Text(
                  'پشتِ هر فصلِ تازه یک برگ سفید بینداز تا فصل از برگ نخست آغاز شود',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: mirrorMargin,
              onChanged: onMirrorMarginChanged,
              title: Text('حاشیهٔ آینه‌ای',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontFamily: AppTheme.fontFamily)),
              subtitle: Text('حاشیهٔ شیرازه با هر ورق‌زدن به طرف دیگر برود',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: TimeThemeKit.of(context).palette.textSecondary,
                fontFamily: AppTheme.fontFamily)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.primary : t.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? t.primary : t.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontFamily ?? AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One of the three footnote modes.
///
/// Taller than [_Chip] on purpose: this row is the only control for the
/// page's apparatus, and a 26 dp pill missed the 44 dp tap floor.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? t.primary : t.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? t.primary : t.outline),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : t.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperDot extends StatelessWidget {
  const _PaperDot({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final ({String key, String label, Color surface, Color ink}) paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'کاغذ ${paper.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: paper.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? t.primary : t.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected ? Icon(Icons.check, size: 14, color: paper.ink) : null,
        ),
      ),
    );
  }
}
