import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// The sheet/dialog/card corner contract.
///
/// Before this guard the app opened bottom sheets at **five** different top
/// radii (18 / 20 / 22 / 24 / 28): the theme said 28, the quran reader said 30
/// on its paper sheets, and a dozen call sites copied 18–24 from older code.
/// Opening «تنظیمات اذان» then «انتخاب تفسیر» showed two different corners for
/// the same interaction.
///
/// The rule is now one value from the theme; a call site may still repeat it
/// (harmless) but may not choose another. The mushaf reader's paper sheets are
/// exempt on purpose — that surface is not the app's chrome.
void main() {
  const sheetRadius = 20.0;

  double? topRadius(BottomSheetThemeData? theme) {
    final shape = theme?.shape;
    if (shape is! RoundedRectangleBorder) return null;
    final radius = shape.borderRadius;
    if (radius is! BorderRadius) return null;
    return radius.topLeft.x;
  }

  test('the theme owns one sheet radius, in both palettes', () {
    final light = AppTheme.lightTheme();
    final dark = AppTheme.darkTheme();
    expect(topRadius(light.bottomSheetTheme), sheetRadius,
        reason: 'light bottomSheetTheme radius');
    expect(topRadius(dark.bottomSheetTheme), sheetRadius,
        reason: 'dark bottomSheetTheme radius');
  });

  test('the card and dialog radii keep their place in the scale', () {
    // The sheet (20) must stay the larger surface without becoming a capsule;
    // the card is 22 and the dialog 24. Changing one of these is a design
    // decision, not a refactor — this assertion is the reminder.
    expect(const AppCard(child: SizedBox()).radius, 22);
    final dialogShape = AppTheme.lightTheme().dialogTheme.shape;
    expect(dialogShape, isA<RoundedRectangleBorder>());
    final dialogRadius =
        (dialogShape as RoundedRectangleBorder).borderRadius as BorderRadius;
    expect(dialogRadius.topLeft.x, 24);
  });

  test('no call site opens a sheet at a radius other than the theme\'s', () {
    final offenders = <String>[];
    final root = Directory('lib');
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Normalize the separator: Windows reports `\`, and both exclusions
        // below must apply on every platform.
        .where((f) => !f.path.replaceAll(r'\', '/').contains('quran/mushaf'))
        .where((f) => !f.path.replaceAll(r'\', '/').contains('/desine/'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('showModalBottomSheet')) continue;
        // The shape is passed within the call's own argument list; 20 lines is
        // enough for every call site in this repo (the longest is 12).
        final end = (i + 20).clamp(0, lines.length);
        for (var j = i; j < end; j++) {
          final match =
              RegExp(r'vertical\(top: Radius\.circular\(([0-9.]+)\)\)')
                  .firstMatch(lines[j]);
          if (match == null) continue;
          final value = double.parse(match.group(1)!);
          if (value != sheetRadius) {
            offenders.add('${file.path}:${j + 1} → $value');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'sheets must inherit the theme radius ($sheetRadius); '
            'drop the local `shape:` instead of copying a number');
  });
}
