import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/settings/presentation/search/settings_registry.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';

/// The whole point of the section hues is that no two sections look alike —
/// a copy-paste that paints «واحد پول» the same gold as «امتیازدهی عبادات»
/// would silently turn the colour back into decoration.
void main() {
  test('every top-level section has its own hue', () {
    const hues = <String, Color>{
      'appearance': SettingsSectionHues.appearance,
      'prayer': SettingsSectionHues.prayer,
      'sounds': SettingsSectionHues.sounds,
      'scoring': SettingsSectionHues.scoring,
      'notifications': SettingsSectionHues.notifications,
      'widgets': SettingsSectionHues.widgets,
      'currency': SettingsSectionHues.currency,
      'other': SettingsSectionHues.other,
    };
    expect(hues.length, 8);
    final seen = <int, String>{};
    for (final entry in hues.entries) {
      final value = entry.value.toARGB32();
      expect(seen[value], isNull,
          reason: '«${entry.key}» reuses the hue of «${seen[value]}»');
      seen[value] = entry.key;
    }
  });

  test('a page opened from a section inherits that section hue', () {
    expect(SettingsSectionHues.font, SettingsSectionHues.appearance);
    // «سایر» children are the account/storage family, not the misc brown.
    expect(SettingsSectionHues.account, isNot(SettingsSectionHues.other));
  });

  test('every search page resolves to a hue, main included', () {
    for (final page in SettingsSearchPage.values) {
      expect(SettingsSectionHues.forPage(page), isA<Color>());
    }
    expect(SettingsSectionHues.forPage(SettingsSearchPage.prayer),
        SettingsSectionHues.prayer);
    expect(SettingsSectionHues.forPage(SettingsSearchPage.widgets),
        SettingsSectionHues.widgets);
  });

  testWidgets('dark mode lifts the hue, light mode leaves it untouched',
      (tester) async {
    // A bare Theme, not a MaterialApp: MaterialApp routes `theme` through the
    // light/dark slot selection and would answer `brightness` from the
    // platform, not from what this test set.
    Future<Color> resolve(Brightness brightness) async {
      late Color hue;
      await tester.pumpWidget(Theme(
        data: ThemeData(brightness: brightness),
        child: Builder(builder: (context) {
          hue = SettingsSectionHues.on(context, SettingsSectionHues.scoring);
          return const SizedBox();
        }),
      ));
      return hue;
    }

    final light = await resolve(Brightness.light);
    final dark = await resolve(Brightness.dark);

    expect(light, SettingsSectionHues.scoring);
    // A deep green must not stay 0xFF2E7D32 on a night background.
    expect(dark, isNot(SettingsSectionHues.scoring));
    expect(dark.computeLuminance(),
        greaterThan(SettingsSectionHues.scoring.computeLuminance()));
  });
}
