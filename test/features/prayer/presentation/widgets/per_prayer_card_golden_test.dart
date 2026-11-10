import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

import 'per_prayer_card_pump.dart';

/// Card-only baselines for the «اذان و اقامه هر نماز» card (Design A).
///
/// Captured at the card's own bounds (the `golden-card` RepaintBoundary in
/// [pumpCard]), under day and night, at the two layout modes and at text scale
/// 1.3. The OFF states pin the muted-chip recipe: ONLY the voice chip dims —
/// the counters keep the accent at every state. No font is loaded in the test
/// binding, so glyph shaping is not covered (the repo-wide golden rule).
void main() {
  const allOn = AppSettings(
    azanEnabledForFajr: true,
    azanEnabledForDhuhr: true,
    azanEnabledForAsr: true,
    azanEnabledForMaghrib: true,
    azanEnabledForIsha: true,
  );
  const oneOff = AppSettings(
    azanEnabledForFajr: true,
    azanEnabledForDhuhr: true,
    azanEnabledForMaghrib: true,
    azanEnabledForIsha: true,
    // asr carries the one muted chip to pin the OFF recipe beside the live ones.
  );

  testWidgets('golden — all adhans on, day', (tester) async {
    await pumpCard(tester, settings: allOn);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_on.png'),
    );
  });

  testWidgets('golden — one adhan off (asr), day', (tester) async {
    await pumpCard(tester, settings: oneOff);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_one_off.png'),
    );
  });

  testWidgets('golden — all adhans off (the defaults), day', (tester) async {
    await pumpCard(tester, settings: const AppSettings());
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_all_off.png'),
    );
  });

  testWidgets('golden — 2-row mode at 320dp, day', (tester) async {
    await pumpCard(tester, settings: allOn, width: 320);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_two_row.png'),
    );
  });

  testWidgets('golden — text scale 1.3, day', (tester) async {
    await pumpCard(tester, settings: allOn, textScale: 1.3);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_scale13.png'),
    );
  });

  testWidgets('golden — all adhans on, night', (tester) async {
    await pumpCard(tester, settings: allOn, dark: true);
    await expectLater(
      find.byKey(const ValueKey('golden-card')),
      matchesGoldenFile('goldens/per_prayer_card_night.png'),
    );
  });
}
