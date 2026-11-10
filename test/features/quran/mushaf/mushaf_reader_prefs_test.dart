// Unit test: the reader's colour preferences.
//
// These used to be palette *indices*, which made the palette append-only and
// made "remove the duplicate colours" impossible without changing every
// existing reader's page. The migration off the old keys is the part most likely
// to be silently broken by a later edit — nobody notices a reader's page colour
// changing on upgrade — so it is pinned here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  bool inPalette(Color color) => mushafBackgroundIndexOf(color) >= 0;

  group('background', () {
    test('a stored colour value is read back as a colour, not an index',
        () async {
      // The 4th entry as a *value*: were this still read as an index it would
      // come back as the 5th entry, one colour down the list.
      final prefs = await prefsWith(
          {MushafReaderPrefs.backgroundKey: kMushafBackgrounds[3].color.toARGB32()});
      expect(MushafReaderPrefs.backgroundFrom(prefs).toARGB32(),
          kMushafBackgrounds[3].color.toARGB32());
    });

    test('the retired index key is migrated and written back as a value',
        () async {
      // quran_bg_day = 4 named «شامواه» in the old palette.
      final prefs = await prefsWith(
          {MushafReaderPrefs.legacyBackgroundIndexKey: 4});
      final migrated = MushafReaderPrefs.backgroundFrom(prefs);
      expect(inPalette(migrated), isTrue);

      // The write-back is fire-and-forget; let it land, then drop the legacy
      // key to prove the value is what the next launch reads.
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getInt(MushafReaderPrefs.backgroundKey),
          migrated.toARGB32());
      await prefs.remove(MushafReaderPrefs.legacyBackgroundIndexKey);
      expect(MushafReaderPrefs.backgroundFrom(prefs).toARGB32(),
          migrated.toARGB32());
    });

    test('every legacy index keeps its page on the same side of day and night',
        () async {
      for (var i = 0; i < kLegacyMushafBackgrounds.length; i++) {
        final prefs = await prefsWith(
            {MushafReaderPrefs.legacyBackgroundIndexKey: i});
        final migrated = MushafReaderPrefs.backgroundFrom(prefs, writeBack: false);
        final legacy = mushafLegacyBackgroundColor(i);
        expect(mushafNeedsLightInk(migrated), mushafNeedsLightInk(legacy),
            reason: 'legacy index $i flipped between a light and a dark page');
      }
    });

    test('with nothing stored it starts on the first paper', () async {
      final prefs = await prefsWith({});
      expect(MushafReaderPrefs.backgroundFrom(prefs).toARGB32(),
          kMushafBackgrounds.first.color.toARGB32());
    });

    test('a colour that is no longer in the palette snaps to its neighbour',
        () async {
      // Something a future build might leave behind — a retired colour, or a
      // value written by a palette that never existed.
      const orphan = Color(0xFFD8C9A8);
      expect(mushafBackgroundIndexOf(orphan), -1);

      final prefs = await prefsWith({MushafReaderPrefs.backgroundKey: orphan.toARGB32()});
      final repaired = MushafReaderPrefs.backgroundFrom(prefs);
      expect(inPalette(repaired), isTrue);
      expect(
        mushafColorDistance(repaired, orphan),
        lessThanOrEqualTo(12.0),
        reason: 'the repair must not jump the reader to an unrelated page',
      );

      await Future<void>.delayed(Duration.zero);
      expect(prefs.getInt(MushafReaderPrefs.backgroundKey), repaired.toARGB32());
    });

    test('a negative or oversized stored value cannot throw', () async {
      // SharedPreferences hands back a signed 64-bit int; anything out of ARGB
      // range must be masked rather than passed to Color().
      final prefs = await prefsWith({MushafReaderPrefs.backgroundKey: -1});
      final repaired = MushafReaderPrefs.backgroundFrom(prefs, writeBack: false);
      expect(inPalette(repaired), isTrue);
    });
  });

  group('recited-ayah colour', () {
    test('a stored colour value is read back', () async {
      final stored = kMushafRecitationColors[7].color;
      final prefs = await prefsWith(
          {MushafReaderPrefs.recitationColorKey: stored.toARGB32()});
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(),
          stored.toARGB32());
    });

    test('the retired index key still yields the colour it used to name',
        () async {
      // The old palette was 7 colours; index 1 was «آبی», which survives the
      // rewrite verbatim, so the reader's ayah does not change colour at all.
      final prefs = await prefsWith(
          {MushafReaderPrefs.legacyRecitationIndexKey: 1});
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(),
          0xFF1E5AA8);

      await Future<void>.delayed(Duration.zero);
      expect(prefs.getInt(MushafReaderPrefs.recitationColorKey), 0xFF1E5AA8);
    });

    test('a retired legacy index snaps to its neighbour, never to the default',
        () async {
      // Index 2 was «نارنجی», retired at the reader's request. A reader who
      // still has that key must land on the warm neighbour «آجری» — never on
      // the emerald default, which would silently reset their ayah colour.
      final prefs = await prefsWith(
          {MushafReaderPrefs.legacyRecitationIndexKey: 2});
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(),
          0xFF9A3B22);

      await Future<void>.delayed(Duration.zero);
      expect(prefs.getInt(MushafReaderPrefs.recitationColorKey), 0xFF9A3B22);
    });

    test('the legacy default is still the emerald', () async {
      final prefs = await prefsWith(
          {MushafReaderPrefs.legacyRecitationIndexKey: 0});
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(),
          0xFF0E7A5A);
    });

    test('an out-of-range legacy index is clamped, not thrown', () async {
      final prefs = await prefsWith(
          {MushafReaderPrefs.legacyRecitationIndexKey: 99});
      final colour = MushafReaderPrefs.recitationColorFrom(prefs, writeBack: false);
      expect(mushafRecitationIndexOf(colour), isNonNegative);
    });

    test('with nothing stored it starts on the default emerald', () async {
      final prefs = await prefsWith({});
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(),
          kMushafRecitationColors.first.color.toARGB32());
    });
  });

  group('saving', () {
    test('a saved background survives as a value', () async {
      SharedPreferences.setMockInitialValues({});
      await MushafReaderPrefs.saveBackground(const Color(0xFF875A32));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(MushafReaderPrefs.backgroundKey), 0xFF875A32);
      expect(MushafReaderPrefs.backgroundFrom(prefs).toARGB32(), 0xFF875A32);
    });

    test('a saved ayah colour survives as a value', () async {
      SharedPreferences.setMockInitialValues({});
      await MushafReaderPrefs.saveRecitationColor(const Color(0xFF7A3BB5));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(MushafReaderPrefs.recitationColorKey), 0xFF7A3BB5);
      expect(MushafReaderPrefs.recitationColorFrom(prefs).toARGB32(), 0xFF7A3BB5);
    });
  });

  group('page turn', () {
    test('the key is the one the reader writes', () {
      expect(MushafReaderPrefs.pageTurnKey, 'quran_page_turn');
    });

    test('with nothing stored a fresh install opens on the plain slide', () async {
      final prefs = await prefsWith({});
      expect(MushafReaderPrefs.loadPageTurnSync(prefs), MushafPageTurn.plain);
    });

    test('a method from a retired build falls back instead of throwing',
        () async {
      final prefs = await prefsWith({MushafReaderPrefs.pageTurnKey: 'curl'});
      expect(MushafReaderPrefs.loadPageTurnSync(prefs), MushafPageTurn.plain);
    });

    test('the retired second effect migrates to the book turn', () async {
      // «flip» was the unattractive effect this release replaced; its readers
      // asked for a turning page, so they keep one.
      final prefs = await prefsWith({MushafReaderPrefs.pageTurnKey: 'flip'});
      expect(MushafReaderPrefs.loadPageTurnSync(prefs), MushafPageTurn.bookFlip);
    });

    test('the retired roll effect migrates to the book turn', () async {
      // «scroll» (طومار) was retired for its faceted look; its readers asked
      // for a turning page, so they keep one too.
      final prefs = await prefsWith({MushafReaderPrefs.pageTurnKey: 'scroll'});
      expect(MushafReaderPrefs.loadPageTurnSync(prefs), MushafPageTurn.bookFlip);
    });

    test('a reader who chose the plain slide keeps it', () async {
      final prefs = await prefsWith({MushafReaderPrefs.pageTurnKey: 'slide'});
      expect(MushafReaderPrefs.loadPageTurnSync(prefs), MushafPageTurn.plain);
    });

    test('every method round-trips through its stored wire value', () async {
      for (final turn in MushafPageTurn.values) {
        SharedPreferences.setMockInitialValues({});
        await MushafReaderPrefs.savePageTurn(turn);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(MushafReaderPrefs.pageTurnKey), turn.wire);
        expect(MushafReaderPrefs.loadPageTurnSync(prefs), turn);
      }
    });

    test('speed, haptic and the printed-page look have their own keys', () async {
      expect(MushafReaderPrefs.pageTurnSpeedKey, 'quran_page_turn_speed');
      expect(MushafReaderPrefs.pageTurnHapticKey, 'quran_page_turn_haptic');
      expect(MushafReaderPrefs.pageChromeByParityKey,
          'quran_page_chrome_parity');

      final empty = await prefsWith({});
      expect(MushafReaderPrefs.loadPageTurnSpeedSync(empty),
          MushafTurnSpeed.normal);
      expect(MushafReaderPrefs.loadPageTurnHapticSync(empty), isTrue);
      expect(MushafReaderPrefs.loadPageChromeByParitySync(empty), isTrue);

      await MushafReaderPrefs.savePageTurnSpeed(MushafTurnSpeed.slow);
      await MushafReaderPrefs.savePageTurnHaptic(false);
      await MushafReaderPrefs.savePageChromeByParity(false);
      final prefs = await SharedPreferences.getInstance();
      expect(MushafReaderPrefs.loadPageTurnSpeedSync(prefs),
          MushafTurnSpeed.slow);
      expect(MushafReaderPrefs.loadPageTurnHapticSync(prefs), isFalse);
      expect(MushafReaderPrefs.loadPageChromeByParitySync(prefs), isFalse);
    });

    test('a speed from a retired build settles on the default', () async {
      final prefs =
          await prefsWith({MushafReaderPrefs.pageTurnSpeedKey: 'instant'});
      expect(MushafReaderPrefs.loadPageTurnSpeedSync(prefs),
          MushafTurnSpeed.normal);
    });
  });
}
