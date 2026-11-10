/// Endpoints + sizes for the QCF4 (quran-qcf4) live-font mushaf.
///
/// JSON data is served from `raw.githubusercontent.com` (always up to date);
/// TTF font files from `cdn.jsdelivr.net` (cached for speed). Per the
/// dataset's README the `raw` host is used for JSON and jsDelivr for fonts.
///
/// Fonts are downloaded as **TTF** (not woff2): the QCF4 fonts have no
/// GSUB/ligature table, so each code point maps straight to one precomposed
/// glyph and a plain `FontLoader` renders them correctly — no runtime
/// woff2/Brotli decode is needed (and `es_compression`, the Brotli backend
/// `woff2` relies on, ships no Android `.so`, which is why on-device woff2
/// decode could never work).
class Qcf4Config {
  Qcf4Config._();

  static const String dataBase =
      'https://raw.githubusercontent.com/MohamadHajjRabee/quran-qcf4/main';

  static const String fontCdnBase =
      'https://cdn.jsdelivr.net/gh/MohamadHajjRabee/quran-qcf4@main';

  /// Number of Mushaf pages in QCF4 (same 604 as the 1441 Madinah print).
  static const int pageCount = 604;

  /// Number of per-page Hafs font files (`QCF4_Hafs_01`..`QCF4_Hafs_47`).
  static const int hafsFontCount = 47;

  /// The surah-header / bismillah font family (a single shared font).
  static const String qbsmlFontFamily = 'QCF4_QBSML';

  /// Bundled calligraphic surah-name font (surah N → `U+E000 + N`). Unlike the
  /// QCF4 fonts it ships with the app, so the header renders while offline.
  static const String surahNameFontFamily = 'SurahNameV4';

  /// The PUA glyph in [surahNameFontFamily] for a given surah (1..114), or
  /// null when [sura] is out of range. No shaping/GSUB is required — it is a
  /// plain cmap lookup, so it always renders in Flutter.
  static String? surahNameGlyph(int? sura) {
    if (sura == null || sura < 1 || sura > 114) return null;
    return String.fromCharCode(0xE000 + sura);
  }

  // ── Ornamental band font (assets/fonts/quran-common.ttf) ───────────────
  // The QUL mushaf's common ornament font, bundled with the app. The surah
  // header is a SINGLE glyph, [quranHeaderGlyph] (U+E000): a floral band
  // whose middle cartouche carries the calligraphic surah name and whose
  // two ring medallions carry the surah number (right) and the revelation
  // place (left). All geometry below was measured from the TTF outlines
  // (UPM 1024, hhea ascent 819 / descent 205): at fontSize = bannerW ×
  // [quranHeaderFontScale] the glyph spans exactly the banner box, and its
  // mid-line sits [quranHeaderMidFromTop] × fontSize below the widget top.

  /// Family name registered in `pubspec.yaml` for the bundled TTF.
  static const String quranCommonFontFamily = 'QuranCommon';

  /// The surah-header ornament glyph (the font's `header` ligature).
  static const String quranHeaderGlyph = '\uE000';

  /// Glyph advance (font units); the ink box spans exactly this width.
  static const double quranHeaderAdvance = 8240;

  /// Glyph ink height (font units).
  static const double quranHeaderInkHeight = 1016;

  /// The ornament's mid-line (cartouche and both ring centres, y = 320 font
  /// units above the baseline) as a fraction of the fontSize, measured down
  /// from the text widget's top: (hhea ascent 819 − 320) / 1024.
  static const double quranHeaderMidFromTop = 499 / 1024;

  /// TextStyle fontSize for a banner of width [w]: w × this.
  static const double quranHeaderFontScale = 1024 / quranHeaderAdvance;

  /// Ring-medallion centres, as fractions of the banner width (symmetric
  /// about the centre: left + right = 1).
  static const double quranHeaderCircleLeftCx = 1699 / 8240;
  static const double quranHeaderCircleRightCx = 6541 / 8240;

  /// Clear interior diameter of each ring medallion (fraction of bannerW).
  static const double quranHeaderCircleInnerD = 590 / 8240;

  /// Middle name-cartouche size (fractions of bannerW; its un-inset clear
  /// box runs x 2100..6140, y −61..701 font units).
  static const double quranHeaderCartoucheW = 4040 / 8240;
  static const double quranHeaderCartoucheH = 762 / 8240;

  // ── Surah-banner ornament (assets/quran/surah_header.png) ─────────────
  // The PNG is the user's full-color artwork (gold/maroon floral frame,
  // 2165×381 RGBA, transparency cropped tight): three opaque tan-gold
  // cartouches — the surah name in the large middle one, the verse count
  // in the right one and the revelation-place (مكية/مدنية) in the left
  // one. Texts are painted DIRECTLY on the artwork (no backings; see
  // qcf4_page_viewer) in the frame's dark maroon. All fractions below were
  // measured from the PNG pixels so text always lands on the artwork's
  // clear areas.

  /// Asset path of the ornament PNG (bundled, renders while offline).
  static const String surahHeaderAsset = 'assets/quran/surah_header.png';

  /// Pixel size of [surahHeaderAsset].
  static const double surahHeaderVbW = 2165;
  static const double surahHeaderVbH = 381;

  /// Height of the banner as a fraction of its width (381 / 2165).
  static const double surahHeaderAspect = surahHeaderVbH / surahHeaderVbW;

  /// Left/right x of the surah-name cartouche (fill x 674–1495,
  /// fractions 0.310–0.689; tightened slightly for the lobed rim),
  /// as fractions of the ornament width.
  static const double surahHeaderInnerL = 0.322;
  static const double surahHeaderInnerR = 0.678;

  /// Top/bottom y of the surah-name cartouche as fractions of the height:
  /// the fill runs y 297–498 (0.236–0.764); the box uses ~95% of it so the
  /// name renders large while staying clear of the lobed rim.
  static const double surahHeaderInnerT = 0.25;
  static const double surahHeaderInnerB = 0.75;

  /// Left/right x of the left (revelation-place) cartouche (fill
  /// x 272–460, fractions 0.124–0.211), as fractions of the ornament width.
  static const double surahHeaderPanelLeftL = 0.128;
  static const double surahHeaderPanelLeftR = 0.207;

  /// Left/right x of the right (verse-count) cartouche (fill
  /// x 1709–1895, fractions 0.788–0.874), as fractions of the width.
  static const double surahHeaderPanelRightL = 0.792;
  static const double surahHeaderPanelRightR = 0.870;

  /// Vertical extent of the side cartouches (fills y 280–491,
  /// fractions 0.192–0.745; narrowed because the quatrefoil lobes taper
  /// top/bottom), as fractions of the ornament height.
  static const double surahHeaderPanelT = 0.28;
  static const double surahHeaderPanelB = 0.72;

  /// Advance widths (font units, UPM 1024) of the SurahNameV4 glyphs, indexed
  /// by surah (index 0 = the «سورة» icon). Measured from the bundled TTF
  /// hmtx table. Glyph widths vary ~2.5× (732–1879), so names are sized
  /// inversely to their advance to fill the banner compartment uniformly.
  static const List<int> surahNameAdvances = <int>[
    1145,
    1546,
    1328,
    1672,
    1108,
    1264,
    1458,
    1509,
    1518,
    1330,
    1112,
    926,
    1282,
    1162,
    1592,
    1255,
    1154,
    1024,
    1492,
    1353,
    931,
    1394,
    846,
    1504,
    1138,
    1513,
    1342,
    1268,
    1478,
    1693,
    1288,
    1156,
    1271,
    1464,
    890,
    1229,
    787,
    1645,
    1127,
    1150,
    1273,
    1457,
    1458,
    1504,
    1620,
    1503,
    1695,
    1335,
    1106,
    1575,
    854,
    1724,
    1310,
    1405,
    1292,
    1384,
    1544,
    1530,
    1620,
    1398,
    1844,
    1206,
    1427,
    1724,
    1443,
    1439,
    1459,
    1094,
    1164,
    1466,
    1385,
    732,
    1009,
    1281,
    1334,
    1466,
    1516,
    1611,
    1025,
    1638,
    1096,
    1757,
    1769,
    1691,
    1674,
    1268,
    1469,
    1283,
    1768,
    1168,
    1297,
    1385,
    1055,
    1364,
    1191,
    1041,
    1264,
    1510,
    1024,
    1390,
    1868,
    1603,
    1487,
    1384,
    1342,
    1390,
    1184,
    1683,
    1380,
    1879,
    1274,
    1258,
    1854,
    1024,
    1462,
  ];

  /// Font size rendering surah [sura]'s calligraphic name so its advance
  /// fills [width] (the banner's name compartment). Null out of range.
  static double? surahNameSizeForWidth(int? sura, double width) {
    if (sura == null || sura < 1 || sura > 114) return null;
    final adv = surahNameAdvances[sura];
    if (adv <= 0) return null;
    return width * 1024 / adv;
  }

  /// Ink heights (font units, UPM 1024) of the SurahNameV4 glyphs, indexed
  /// by surah (index 0 = the icon). Generated from the bundled TTF glyf
  /// bounds; caps each name inside the banner cartouche exactly.
  static const List<int> surahNameInkHeights = <int>[
    769,
    753,
    797,
    939,
    837,
    755,
    899,
    861,
    910,
    800,
    771,
    826,
    736,
    825,
    837,
    801,
    892,
    876,
    828,
    819,
    811,
    932,
    826,
    766,
    797,
    783,
    795,
    810,
    805,
    773,
    804,
    897,
    785,
    940,
    831,
    815,
    743,
    789,
    805,
    801,
    786,
    834,
    792,
    823,
    820,
    773,
    836,
    833,
    868,
    811,
    701,
    865,
    794,
    786,
    762,
    786,
    772,
    770,
    859,
    780,
    796,
    758,
    753,
    797,
    794,
    831,
    810,
    878,
    891,
    785,
    795,
    791,
    879,
    886,
    750,
    803,
    831,
    833,
    827,
    789,
    730,
    894,
    824,
    794,
    774,
    769,
    792,
    886,
    778,
    781,
    857,
    791,
    974,
    820,
    772,
    822,
    880,
    781,
    862,
    917,
    784,
    766,
    769,
    779,
    785,
    780,
    799,
    813,
    813,
    853,
    805,
    773,
    923,
    910,
    755,
  ];

  /// Ink height of surah [sura]'s calligraphic name (font units), or null
  /// out of range. Index 0 holds the icon's height.
  static int? surahNameInkHeight(int? sura) {
    if (sura == null || sura < 0 || sura > 114) return null;
    return surahNameInkHeights[sura];
  }

  /// Vertical ink centres ((yMin+yMax)/2, font units) of the SurahNameV4
  /// glyphs, indexed by surah (index 0 = the icon): the per-glyph baseline
  /// offset that centres each calligraphic name in the header cartouche.
  /// Generated from the bundled TTF glyf bounds.
  static const List<int> surahNameInkCenters = <int>[
    331,
    306,
    326,
    380,
    348,
    306,
    380,
    360,
    384,
    330,
    316,
    342,
    298,
    342,
    348,
    330,
    375,
    367,
    343,
    338,
    334,
    385,
    342,
    312,
    328,
    320,
    326,
    335,
    332,
    316,
    331,
    378,
    322,
    380,
    344,
    336,
    300,
    324,
    332,
    330,
    322,
    347,
    326,
    340,
    339,
    316,
    348,
    346,
    363,
    334,
    280,
    362,
    326,
    322,
    310,
    322,
    315,
    314,
    358,
    319,
    327,
    308,
    306,
    328,
    326,
    344,
    334,
    369,
    376,
    322,
    326,
    324,
    368,
    372,
    305,
    330,
    344,
    346,
    342,
    324,
    294,
    377,
    342,
    326,
    316,
    314,
    325,
    372,
    318,
    320,
    358,
    324,
    365,
    339,
    316,
    340,
    370,
    320,
    360,
    388,
    321,
    312,
    312,
    318,
    322,
    319,
    328,
    336,
    336,
    356,
    332,
    316,
    380,
    384,
    308,
  ];

  /// Ink centre of surah [sura]'s name (font units), or null out of range.
  static int? surahNameInkCenter(int? sura) {
    if (sura == null || sura < 0 || sura > 114) return null;
    return surahNameInkCenters[sura];
  }

  /// Fixed banner width at a [fontSize] body — identical on every page so
  /// the header (and its texts) render one size everywhere. Calibrated from
  /// measured QCF4 advances: full verse lines run ~16.3× the body size, so
  /// the banner spans the column with slim side margins, parallel with the
  /// verses. Null when [sura] is out of range (caller falls back to the
  /// dataset char).
  static double? surahHeaderBannerWidth(int? sura, double fontSize) {
    if (sura == null || sura < 1 || sura > 114) return null;
    return (fontSize * 16.3).clamp(200.0, 800.0);
  }

  /// Disk folder (under `quran_content/`) holding downloaded QCF4 assets.
  static const String cacheDirName = 'qcf4';

  /// Font family → TTF file name. Hafs fonts append `_W`; QBSML does not.
  /// The repo ships the TTF versions alongside the woff2 under `fonts/`.
  static String fontTtfFileName(String fontFamily) {
    if (fontFamily == qbsmlFontFamily) return '$fontFamily.ttf';
    return '${fontFamily}_W.ttf';
  }

  /// URL of a page's JSON (`pages/NNN.json`).
  static String pageJsonUrl(int page) =>
      '$dataBase/pages/${page.toString().padLeft(3, '0')}.json';

  /// URL of a font's TTF file (`fonts/…`).
  static String fontTtfUrl(String fontFamily) =>
      '$fontCdnBase/fonts/${fontTtfFileName(fontFamily)}';
}
