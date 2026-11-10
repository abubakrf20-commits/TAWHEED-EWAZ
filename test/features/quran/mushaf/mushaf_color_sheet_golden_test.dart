// Golden test: the mushaf colour-picker sheet, as the reader lays it out.
//
// The palette's *maths* is pinned by `mushaf_palette_test.dart` and the
// pickers' *behaviour* by `quran_mushaf_widget_test.dart`. What neither can
// catch is the sheet quietly laying itself out wrong: a group caption drifting
// onto its swatches, the selection ring landing on the wrong swatch of the
// «کاغذ تیره» group (the local-index bug was exactly that), the live preview
// shrinking to nothing. So the two picker contents are rendered with the real
// `MushafPalette`s and pinned as pixels — once with the selection in the light
// group, once in the dark group, once for the recited-ayah grid.
//
// Text is rendered with the bundled Amiri face, loaded explicitly and pinned
// through `AppTheme.fontFamily`, so the goldens never depend on whatever font
// the host machine happens to resolve for the app's brand family.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show FontLoader;

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// Sheet width and height. Taller than the tallest phone fold the picker is
/// designed for on purpose: the *fit* contract is pinned by the widget tests
/// (swipe-dismiss, settings-sheet fold), while this golden pins the *layout*
/// — the grid, the captions and the selection ring — which is taller than one
/// fold and must not be cropped to fit.
const Size _device = Size(360, 640);

/// The outer padding `showMushafSheet` gives the content body.
const EdgeInsets _sheetPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);

MushafBackground _paper(String name) =>
    kMushafBackgrounds.firstWhere((b) => b.name == name);

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Renders [child] as the top of the sheet surface and returns nothing; the
/// golden is captured off the `sheet` repaint boundary.
Future<void> pumpSheet(
  WidgetTester tester, {
  required MushafPalette palette,
  required Widget child,
}) async {
  tester.view.physicalSize = _device;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: Container(
              width: _device.width,
              height: _device.height,
              color: palette.surface,
              padding: _sheetPadding,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Whether the swatch labelled [name] is drawn as the selected one.
///
/// The selection ring is painted by the swatch's own `Container`: a 3px border
/// in the palette accent, versus 1px surface-text hairline otherwise. Reading
/// that decoration means the golden cannot quietly pin a wrong selection — if
/// the pixels and this check ever disagree, this expect fails first.
bool _isSelected(WidgetTester tester, String name) {
  final tooltips = find
      .byWidgetPredicate((w) => w is Tooltip && w.message == name)
      .evaluate();
  expect(tooltips, isNotEmpty,
      reason: 'no swatch labelled «$name» is in the sheet');

  final bordered = tester
      .widgetList<Container>(
    find.descendant(
      of: find.byWidgetPredicate((w) => w is Tooltip && w.message == name),
      matching: find.byType(Container),
    ),
  )
      .where((c) {
    final decoration = c.decoration;
    return decoration is BoxDecoration && decoration.border != null;
  }).toList();
  expect(bordered, isNotEmpty,
      reason: 'the «$name» swatch lost its edge entirely');

  final border = (bordered.first.decoration! as BoxDecoration).border!;
  return border.top.width > 2;
}

/// Pins the drawn selection state of one swatch (see [_isSelected]).
void _expectSelected(
  WidgetTester tester,
  String name,
  bool selected,
) {
  expect(_isSelected(tester, name), selected,
      reason: 'the «$name» swatch must be drawn as '
          '${selected ? 'selected' : 'not selected'}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('Amiri', 'assets/fonts/Amiri-Regular.ttf');
    // Every TextStyle in the sheet resolves the *app* family; pinning it to
    // the face we just loaded keeps the goldens font-deterministic.
    AppTheme.fontFamily = 'Amiri';
    addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);
  });

  testWidgets('golden: paper picker with the selection in the light group',
      (tester) async {
    final kerm = _paper('کرم');
    await pumpSheet(
      tester,
      palette: MushafPalette.light,
      child: MushafBackgroundPickerContent(
        palette: MushafPalette.light,
        selectedIndex: mushafNearestBackgroundIndexOf(kerm.color),
        recitationColor: kMushafRecitationColors.first.color,
        onPick: (_) {},
      ),
    );

    _expectSelected(tester, 'کرم', true);
    _expectSelected(tester, 'شب مطلق', false);
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/mushaf_color_sheet_bg_light.png'),
    );
  });

  testWidgets('golden: paper picker with the selection in the dark group',
      (tester) async {
    // The night palette drives the sheet chrome AND the dark paper drives the
    // preview — this frame pins both together, with the ring on the group the
    // local-index bug used to break.
    final night = kMushafBackgrounds.last;
    expect(night.isNight, isTrue);
    await pumpSheet(
      tester,
      palette: MushafPalette.night,
      child: MushafBackgroundPickerContent(
        palette: MushafPalette.night,
        selectedIndex: mushafNearestBackgroundIndexOf(night.color),
        recitationColor: kMushafRecitationColors.first.color,
        onPick: (_) {},
      ),
    );

    _expectSelected(tester, 'شب مطلق', true);
    _expectSelected(tester, 'کرم', false);
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/mushaf_color_sheet_bg_dark.png'),
    );
  });

  testWidgets('golden: recited-ayah picker over the default cream paper',
      (tester) async {
    await pumpSheet(
      tester,
      palette: MushafPalette.light,
      child: MushafRecitationPickerContent(
        palette: MushafPalette.light,
        selectedIndex: 1,
        pageBackground: _paper('کرم').color,
        onPick: (_) {},
      ),
    );

    _expectSelected(tester, 'فیروزه‌ای', true);
    _expectSelected(tester, 'سبز زمردی', false);
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/mushaf_color_sheet_recitation.png'),
    );
  });
}
