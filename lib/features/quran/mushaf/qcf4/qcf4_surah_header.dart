import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'qcf4_config.dart';
import 'qcf4_page_chrome.dart';

/// Decorative surah header («سر سوره») for the Mushaf page, replacing the old
/// full-color PNG banner. Custom-painted so it scales with the banner box the
/// page-justification pipeline already reserves (width: bannerW, height:
/// bannerH) without any bitmap asset.
enum SurahHeaderStyle { royal, banner, medallion, ribbon }

class SurahHeader extends StatelessWidget {
  final String name; // e.g. الفاتحة
  final int? number; // surah number (optional)
  final SurahHeaderStyle style;
  final Color gold;
  final Color green;
  final Color paper;
  final double height;
  final String? fontFamily;
  final String prefix; // default: «سورة»

  const SurahHeader({
    super.key,
    required this.name,
    this.number,
    this.style = SurahHeaderStyle.royal,
    this.gold = const Color(0xFFC9A227),
    this.green = const Color(0xFF0F5E4D),
    this.paper = const Color(0xFFFFF8E7),
    this.height = 72,
    this.fontFamily,
    this.prefix = 'سورة',
  });

  @override
  Widget build(BuildContext context) {
    final isRibbon = style == SurahHeaderStyle.ribbon;
    final textColor =
        isRibbon ? (Color.lerp(gold, Colors.white, .55) ?? gold) : green;
    final padFactor = switch (style) {
      SurahHeaderStyle.royal => 1.35,
      SurahHeaderStyle.banner => 1.05,
      SurahHeaderStyle.medallion => 1.25,
      SurahHeaderStyle.ribbon => 0.45,
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _HeaderPainter(
            style: style,
            gold: gold,
            green: green,
            paper: paper,
            number: number,
            fontFamily: fontFamily,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: height * padFactor),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  prefix.isEmpty ? name : '$prefix $name',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: height * 0.36,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  final SurahHeaderStyle style;
  final Color gold, green, paper;
  final int? number;
  final String? fontFamily;

  _HeaderPainter({
    required this.style,
    required this.gold,
    required this.green,
    required this.paper,
    required this.number,
    required this.fontFamily,
  });

  Color get _light => Color.lerp(gold, Colors.white, .5) ?? gold;
  Color get _dark => Color.lerp(gold, Colors.black, .35) ?? gold;

  Paint _goldStroke(Rect r, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..shader = LinearGradient(
      colors: [_light, gold, _dark, gold],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(r);

  Paint _goldFill(Rect r) => Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      colors: [_light, gold, _dark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(r);

  Paint _fill(Color c) => Paint()
    ..style = PaintingStyle.fill
    ..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = c;

  Path _star(Offset c, double r, {int n = 8, double k = .62}) {
    final p = Path();
    for (int i = 0; i < n * 2; i++) {
      final rad = i.isEven ? r : r * k;
      final a = -math.pi / 2 + i * math.pi / n;
      final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _banner(Rect r, double inset) {
    final rr = r.deflate(inset);
    final tip = rr.height * 0.45;
    return Path()
      ..moveTo(rr.left, rr.center.dy)
      ..lineTo(rr.left + tip, rr.top)
      ..lineTo(rr.right - tip, rr.top)
      ..lineTo(rr.right, rr.center.dy)
      ..lineTo(rr.right - tip, rr.bottom)
      ..lineTo(rr.left + tip, rr.bottom)
      ..close();
  }

  String _digits(int n) => n
      .toString()
      .split('')
      .map((d) => String.fromCharCode(0x06F0 + int.parse(d)))
      .join();

  void _text(Canvas c, String t, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Round medallion with an eight-point star.
  void _medallion(Canvas c, Rect all, Offset ctr, double rad, {int? num}) {
    c.drawPath(_star(ctr, rad, k: .72), _goldFill(all));
    c.drawCircle(ctr, rad * .66, _fill(green));
    c.drawCircle(ctr, rad * .66, _goldStroke(all, 1.6));
    if (num != null) {
      _text(c, _digits(num), ctr, rad * .66 * (num > 99 ? .8 : 1.0), _light);
    } else {
      c.drawPath(_star(ctr, rad * .42, k: .55), _fill(_light));
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    switch (style) {
      case SurahHeaderStyle.royal:
        _royal(canvas, s, r);
      case SurahHeaderStyle.banner:
        _bannerStyle(canvas, s, r);
      case SurahHeaderStyle.medallion:
        _medallionStyle(canvas, s, r);
      case SurahHeaderStyle.ribbon:
        _ribbon(canvas, s, r);
    }
  }

  // ---- 1) Royal: double frame + two side medallions ----
  void _royal(Canvas c, Size s, Rect r) {
    final outer =
        RRect.fromRectAndRadius(r.deflate(3), const Radius.circular(12));
    final inner =
        RRect.fromRectAndRadius(r.deflate(9), const Radius.circular(8));
    c.drawRRect(outer, _fill(paper));
    c.drawRRect(outer, _goldStroke(r, 3));
    c.drawRRect(inner, _goldStroke(r, 1.2));

    final rad = s.height * 0.34;
    final cxL = s.height * 0.62;
    final cxR = s.width - cxL;
    final cy = s.height / 2;

    // Decorative dotted rows top and bottom.
    for (double x = cxL + rad + 10; x < cxR - rad - 6; x += 12) {
      c.drawPath(_star(Offset(x, 17), 2.6, n: 4, k: .45), _goldFill(r));
      c.drawPath(
          _star(Offset(x, s.height - 17), 2.6, n: 4, k: .45), _goldFill(r));
    }

    _medallion(c, r, Offset(cxL, cy), rad);
    _medallion(c, r, Offset(cxR, cy), rad, num: number);
  }

  // ---- 2) Banner: pointed ends, three concentric lines ----
  void _bannerStyle(Canvas c, Size s, Rect r) {
    c.drawPath(_banner(r, 3), _fill(paper));
    c.drawPath(_banner(r, 3), _goldStroke(r, 3));
    c.drawPath(_banner(r, 9), _stroke(green, 1.3));
    c.drawPath(_banner(r, 13), _goldStroke(r, 1));

    final cy = s.height / 2;
    final x = s.height * 0.5;
    for (final cx in [x, s.width - x]) {
      c.drawPath(_star(Offset(cx, cy), s.height * 0.17), _fill(green));
      c.drawCircle(Offset(cx, cy), s.height * 0.05, _fill(_light));
    }
    if (number != null) {
      // Small number below the name, bottom-center.
      _text(c, _digits(number!), Offset(s.width / 2, s.height - 10),
          s.height * 0.12, _dark);
    }
  }

  // ---- 3) Medallion: central pill + two end circles ----
  void _medallionStyle(Canvas c, Size s, Rect r) {
    final h = s.height;
    final cy = h / 2;
    final bigR = h * 0.46;
    final cxL = bigR + 3;
    final cxR = s.width - bigR - 3;

    final pill = RRect.fromLTRBR(
      cxL,
      cy - h * 0.31,
      cxR,
      cy + h * 0.31,
      Radius.circular(h * 0.31),
    );
    c.drawRRect(pill, _fill(paper));
    c.drawRRect(pill, _goldStroke(r, 2.5));
    c.drawRRect(pill.deflate(5), _stroke(green, 1));

    // Pearls.
    for (double x = cxL + bigR; x < cxR - bigR; x += 11) {
      c.drawCircle(Offset(x, pill.top + 11), 1.8, _goldFill(r));
      c.drawCircle(Offset(x, pill.bottom - 11), 1.8, _goldFill(r));
    }

    // Two end circles.
    for (final cx in [cxL, cxR]) {
      final ctr = Offset(cx, cy);
      c.drawCircle(ctr, bigR, _fill(paper));
      c.drawCircle(ctr, bigR, _goldStroke(r, 3));
      c.drawCircle(ctr, bigR * .82, _stroke(green, 1.2));
      c.drawPath(_star(ctr, bigR * .72, k: .7), _goldFill(r));
      c.drawCircle(ctr, bigR * .44, _fill(green));
      c.drawCircle(ctr, bigR * .44, _goldStroke(r, 1.4));
      if (cx == cxR && number != null) {
        _text(c, _digits(number!), ctr, bigR * .44 * (number! > 99 ? .8 : 1.0),
            _light);
      } else {
        c.drawPath(_star(ctr, bigR * .28, k: .55), _fill(_light));
      }
    }
  }

  // ---- 4) Green ribbon with golden stars ----
  void _ribbon(Canvas c, Size s, Rect r) {
    final rr = RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(8));
    c.drawRRect(rr, _fill(green));
    c.drawRRect(rr.deflate(4), _goldStroke(r, 1.8));

    final h = s.height;
    for (double x = 22; x < s.width - 10; x += 24) {
      c.drawPath(_star(Offset(x, 13), 4.5), _goldFill(r));
      c.drawPath(_star(Offset(x, h - 13), 4.5), _goldFill(r));
    }
    final line = _goldStroke(r, 0.8);
    c.drawLine(const Offset(14, 23), Offset(s.width - 14, 23), line);
    c.drawLine(Offset(14, h - 23), Offset(s.width - 14, h - 23), line);

    if (number != null) {
      _text(c, _digits(number!), Offset(26, h / 2), h * 0.28, _light);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter o) =>
      o.style != style ||
      o.gold != gold ||
      o.green != green ||
      o.paper != paper ||
      o.number != number ||
      o.fontFamily != fontFamily;
}

/// The QUL-style surah header band used by the QCF4 mushaf: the floral
/// ornament glyph U+E000 of the bundled `assets/fonts/quran-common.ttf`
/// (family «QuranCommon») — a band with a middle name cartouche and two ring
/// medallions. The calligraphic surah name fills the cartouche; the surah
/// number (Arabic-Indic) sits in the right ring and the revelation place
/// («مكية»/«مدنية») in the left one. Every size derives from the glyph's
/// measured outlines ([Qcf4Config] fractions), so the composition scales
/// exactly with the banner box the page pipeline reserves.
///
/// This is a fixed-geometry illustration rather than text: every Text here
/// disables text scaling ([TextScaler.noScaling]) — the outer page FittedBox
/// already scales the whole column proportionally.
class QuranCommonSurahHeader extends StatelessWidget {
  const QuranCommonSurahHeader({
    super.key,
    required this.glyph,
    required this.nameSize,
    required this.color,
    this.number,
    this.place,
  });

  /// Calligraphic name glyph (see [Qcf4Config.surahNameGlyph]).
  final String glyph;

  /// Font size for [glyph] (the viewer sizes it to the cartouche).
  final double nameSize;

  /// Ink color of every band element (matches the page chrome).
  final Color color;

  /// Surah number (1..114) → Arabic-Indic digits in the right medallion.
  final int? number;

  /// Revelation place («مكية» / «مدنية») in the left medallion.
  final String? place;

  /// Text field as a fraction of each ring's clear interior diameter.
  static const double _medallionFill = 0.84;

  /// Base font sizes (of the interior diameter) for the number / place.
  static const double _numberFill = 0.55;
  static const double _placeFill = 0.42;

  // Amiri digit/word ink centres (em units above the baseline, measured from
  // the bundled outlines) and the hhea mid ratio of its line box
  // (UPM 1000, hhea 1124/−634): 1124/1758 − 1/2. Shifting a Text by
  // baseSize × (inkCenter − _amiriMidRatio) centres the INK, not the box.
  static const double _amiriMidRatio = 1124 / 1758 - 0.5;
  static const double _digitInkCenter = 0.225;
  static const double _makkahInkCenter = 0.138;
  static const double _madinahInkCenter = 0.050;

  // Name vertical centring in the cartouche (SurahNameV4, UPM 1024,
  // hhea 882/−142): the mid of the line box sits 882 − 512 units above the
  // baseline, so the correction for a per-surah ink centre (font units) is
  // nameSize × (inkCenter − (882 − 512)) / 1024.
  static const double _nameMidFromBaseline = 882 - 512;
  static const double _nameInkCenterDefault = 370; // = 882 − 512

  static const String _madinahWord = 'مدنية';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bannerW = constraints.maxWidth;
      final bannerH = constraints.maxHeight;
      // At this size the ornament's advance spans exactly `bannerW`, and its
      // mid-line (cartouche and both ring centres) sits
      // [Qcf4Config.quranHeaderMidFromTop] × fontSize below the text top.
      final fontF = bannerW * Qcf4Config.quranHeaderFontScale;
      final midY = bannerH / 2;
      final sura = number;
      final word = place;
      final innerD = bannerW * Qcf4Config.quranHeaderCircleInnerD;
      final cartW = bannerW * Qcf4Config.quranHeaderCartoucheW;
      final cartH = bannerW * Qcf4Config.quranHeaderCartoucheH;
      // The name's line box (hhea ascender + descender) is taller than the
      // cartouche, so its Positioned box covers whichever is taller: a
      // shorter box would clamp the paragraph — RenderParagraph clips its
      // paint to its own height — and drop the ink below the cartouche
      // centre. `nameSize` is capped to the cartouche's ink height upstream,
      // so only the empty line-box padding may spill out.
      final nameBoxH = math.max(cartH, nameSize);
      return SizedBox(
        width: bannerW,
        height: bannerH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1) The floral band itself.
            Positioned(
              left: 0,
              top: midY - fontF * Qcf4Config.quranHeaderMidFromTop,
              width: bannerW,
              height: fontF,
              child: Text(
                Qcf4Config.quranHeaderGlyph,
                maxLines: 1,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: Qcf4Config.quranCommonFontFamily,
                  fontSize: fontF,
                  height: 1.0,
                  color: color,
                ),
              ),
            ),
            // 2) Surah number → right ring medallion.
            if (sura != null)
              _medallion(
                text: Qcf4PageChrome.toArabicIndic(sura),
                baseSize: innerD * _numberFill,
                inkCenter: _digitInkCenter,
                cx: bannerW * Qcf4Config.quranHeaderCircleRightCx,
                cy: midY,
                box: innerD * _medallionFill,
              ),
            // 3) Revelation place → left ring medallion.
            if (word != null)
              _medallion(
                text: word,
                baseSize: innerD * _placeFill,
                inkCenter:
                    word == _madinahWord ? _madinahInkCenter : _makkahInkCenter,
                cx: bannerW * Qcf4Config.quranHeaderCircleLeftCx,
                cy: midY,
                box: innerD * _medallionFill,
              ),
            // 4) Calligraphic surah name → middle cartouche.
            Positioned(
              left: (bannerW - cartW) / 2,
              top: midY - nameBoxH / 2,
              width: cartW,
              height: nameBoxH,
              child: Center(
                child: Transform.translate(
                  // Ink-centre (per-surah table), not line box — the
                  // calligraphic ascenders vary from surah to surah.
                  offset: Offset(
                    0,
                    nameSize *
                        ((Qcf4Config.surahNameInkCenter(sura) ??
                                _nameInkCenterDefault) -
                            _nameMidFromBaseline) /
                        1024,
                  ),
                  child: Text(
                    glyph,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: Qcf4Config.surahNameFontFamily,
                      fontSize: nameSize,
                      height: 1.0,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// One ring medallion text: scaled into a [box]×[box] field centred on
  /// ([cx], [cy]) and shifted so its ink sits on the ring's centreline.
  Widget _medallion({
    required String text,
    required double baseSize,
    required double inkCenter,
    required double cx,
    required double cy,
    required double box,
  }) {
    return Positioned(
      left: cx - box / 2,
      top: cy - box / 2,
      width: box,
      height: box,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.translate(
          offset: Offset(0, baseSize * (inkCenter - _amiriMidRatio)),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: baseSize,
              height: 1.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
