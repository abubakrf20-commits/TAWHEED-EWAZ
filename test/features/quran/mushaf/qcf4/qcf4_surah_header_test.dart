import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_surah_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Qcf4Config surah-header banner', () {
    test('banner width is uniform across all surahs and spans the column', () {
      final widths = <double>{
        for (var s = 1; s <= 114; s++)
          Qcf4Config.surahHeaderBannerWidth(s, 30)!,
      };
      expect(widths, hasLength(1));
      // Calibrated to full verse-line width (~16.3× the body size, measured
      // from QCF4 advances): one size on every page, slim side margins.
      expect(widths.first, closeTo(30 * 16.3, 0.5));
    });

    test('banner width grows with the body font size', () {
      final small = Qcf4Config.surahHeaderBannerWidth(2, 20)!;
      final large = Qcf4Config.surahHeaderBannerWidth(2, 40)!;
      expect(large, greaterThan(small));
    });

    test('banner width is null for out-of-range surahs', () {
      expect(Qcf4Config.surahHeaderBannerWidth(null, 30), isNull);
      expect(Qcf4Config.surahHeaderBannerWidth(0, 30), isNull);
      expect(Qcf4Config.surahHeaderBannerWidth(115, 30), isNull);
    });

    test('name size fills the compartment width (advance-inverse)', () {
      // سورة الفاتحة: advance 1546 font units at UPM 1024.
      final size = Qcf4Config.surahNameSizeForWidth(1, 100);
      expect(size, closeTo(100 * 1024 / 1546, 0.001));
    });

    test('name size is null for out-of-range surahs', () {
      expect(Qcf4NameGuard.nameSize(null), isNull);
      expect(Qcf4NameGuard.nameSize(0), isNull);
      expect(Qcf4NameGuard.nameSize(115), isNull);
    });

    test('name ink heights cover every surah with sane values', () {
      expect(Qcf4Config.surahNameInkHeights, hasLength(115));
      for (final h in Qcf4Config.surahNameInkHeights) {
        // Glyph ink fills a large part of the em, never the whole box.
        expect(h, greaterThan(500));
        expect(h, lessThan(1024));
      }
      expect(Qcf4Config.surahNameInkHeight(2), isNotNull);
      expect(Qcf4Config.surahNameInkHeight(null), isNull);
      expect(Qcf4Config.surahNameInkHeight(0), isNotNull);
      expect(Qcf4Config.surahNameInkHeight(115), isNull);
    });

    test('ornament geometry fractions stay consistent', () {
      // Side cartouches live outside the name cartouche.
      expect(Qcf4Config.surahHeaderPanelLeftR,
          lessThan(Qcf4Config.surahHeaderInnerL));
      expect(Qcf4Config.surahHeaderPanelRightL,
          greaterThan(Qcf4Config.surahHeaderInnerR));
      // All fractions are within (0, 1).
      for (final v in [
        Qcf4Config.surahHeaderInnerL,
        Qcf4Config.surahHeaderInnerR,
        Qcf4Config.surahHeaderPanelLeftL,
        Qcf4Config.surahHeaderPanelLeftR,
        Qcf4Config.surahHeaderPanelRightL,
        Qcf4Config.surahHeaderPanelRightR,
        Qcf4Config.surahHeaderInnerT,
        Qcf4Config.surahHeaderInnerB,
        Qcf4Config.surahHeaderPanelT,
        Qcf4Config.surahHeaderPanelB,
      ]) {
        expect(v, greaterThan(0));
        expect(v, lessThan(1));
      }
      // Pixel size + aspect of the artwork (2165×381, cropped tight).
      expect(Qcf4Config.surahHeaderVbW, 2165);
      expect(Qcf4Config.surahHeaderVbH, 381);
      expect(Qcf4Config.surahHeaderAspect,
          closeTo(Qcf4Config.surahHeaderVbH / Qcf4Config.surahHeaderVbW, 1e-9));
    });

    test('ornament PNG asset is bundled with the expected pixel size',
        () async {
      final bytes = (await rootBundle.load(Qcf4Config.surahHeaderAsset))
          .buffer
          .asUint8List();
      // PNG signature.
      expect(bytes.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // IHDR width/height (big-endian uint32 at offsets 16/20).
      final w = ByteData.sublistView(bytes, 16, 20).getUint32(0).toDouble();
      final h = ByteData.sublistView(bytes, 20, 24).getUint32(0).toDouble();
      expect(w, Qcf4Config.surahHeaderVbW);
      expect(h, Qcf4Config.surahHeaderVbH);
    });
  });

  group('quran-common surah band', () {
    test('ornament glyph metrics are self-consistent', () {
      expect(Qcf4Config.quranHeaderGlyph, '\uE000');
      expect(Qcf4Config.quranHeaderFontScale,
          closeTo(1024 / Qcf4Config.quranHeaderAdvance, 1e-12));
      // The glyph is wider than its em and shorter than it is wide.
      expect(Qcf4Config.quranHeaderAdvance, greaterThan(1024));
      expect(Qcf4Config.quranHeaderInkHeight, lessThan(1024));
      // The cartouche/ring centreline sits inside the text box.
      expect(Qcf4Config.quranHeaderMidFromTop, greaterThan(0));
      expect(Qcf4Config.quranHeaderMidFromTop, lessThan(1));
    });

    test('band compartments are symmetric and disjoint', () {
      // The two ring medallions mirror about the centre…
      expect(
          Qcf4Config.quranHeaderCircleLeftCx +
              Qcf4Config.quranHeaderCircleRightCx,
          closeTo(1.0, 1e-9));
      // …the middle cartouche is centred on it…
      const cartLeft = 0.5 - Qcf4Config.quranHeaderCartoucheW / 2;
      const cartRight = 0.5 + Qcf4Config.quranHeaderCartoucheW / 2;
      // …and the clear interiors never overlap.
      const ringLInnerR = Qcf4Config.quranHeaderCircleLeftCx +
          Qcf4Config.quranHeaderCircleInnerD / 2;
      const ringRInnerL = Qcf4Config.quranHeaderCircleRightCx -
          Qcf4Config.quranHeaderCircleInnerD / 2;
      expect(cartLeft, greaterThan(ringLInnerR));
      expect(cartRight, lessThan(ringRInnerL));
    });

    test('name ink-centre table covers every surah with sane values', () {
      expect(Qcf4Config.surahNameInkCenters, hasLength(115));
      for (final c in Qcf4Config.surahNameInkCenters) {
        expect(c, inInclusiveRange(250, 420));
      }
      expect(Qcf4Config.surahNameInkCenter(0), isNotNull);
      expect(Qcf4Config.surahNameInkCenter(114), isNotNull);
      expect(Qcf4Config.surahNameInkCenter(null), isNull);
      expect(Qcf4Config.surahNameInkCenter(115), isNull);
    });

    testWidgets('band paints glyph, number and place without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            color: Color(0xFFF6EFDF),
            child: Center(
              child: SizedBox(
                width: 400,
                height: 400 * Qcf4Config.surahHeaderAspect,
                child: QuranCommonSurahHeader(
                  glyph: '\uE072',
                  nameSize: 40,
                  number: 114,
                  place: 'مكية',
                  color: Color(0xFF7B5B3A),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\uE000'), findsOneWidget); // ornament band
      expect(find.text('\u0661\u0661\u0664'), findsOneWidget); // ١١٤
      expect(find.text('مكية'), findsOneWidget);
      // The band glyph is sized to span the banner box exactly.
      final band = tester.widget<Text>(find.text('\uE000'));
      expect(band.style?.fontSize,
          closeTo(400 * Qcf4Config.quranHeaderFontScale, 0.001));
      // The name must keep its natural line box (nameSize), which is taller
      // than the cartouche here: a clamped paragraph clips its paint and
      // drops the ink below the cartouche centre.
      const cartH = 400 * Qcf4Config.quranHeaderCartoucheH;
      expect(cartH, lessThan(40));
      expect(tester.getSize(find.text('\uE072')).height, closeTo(40, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Indirection so the out-of-range test reads cleanly.
class Qcf4NameGuard {
  static double? nameSize(int? sura) =>
      Qcf4Config.surahNameSizeForWidth(sura, 100);
}
