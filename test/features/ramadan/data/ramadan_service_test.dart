import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/ramadan/data/ramadan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('date logic (self-consistent for any day)', () {
    test('isRamadan agrees with ramadanDay and ramadanDaysRemaining', () {
      final inRamadan = RamadanService.isRamadan();
      final day = RamadanService.ramadanDay();
      final remaining = RamadanService.ramadanDaysRemaining();
      expect(inRamadan, day > 0);
      expect(inRamadan, remaining > 0);
      expect(day, inInclusiveRange(inRamadan ? 1 : 0, inRamadan ? 30 : 0));
      expect(
          remaining, inInclusiveRange(inRamadan ? 1 : 0, inRamadan ? 30 : 0));
    });

    test('daysUntilRamadan is zero exactly during Ramadan', () {
      final until = RamadanService.daysUntilRamadan();
      expect(until, greaterThanOrEqualTo(0));
      expect(until == 0, RamadanService.isRamadan());
    });

    test('a one-day hijri offset keeps all helpers consistent', () {
      final inRamadan = RamadanService.isRamadan(hijriOffset: 1);
      expect(RamadanService.ramadanDay(hijriOffset: 1) > 0, inRamadan);
      expect(RamadanService.daysUntilRamadan(hijriOffset: 1) == 0, inRamadan);
    });
  });

  group('fasting tracker', () {
    test('toggling a fasting day persists it and counts only fasted days',
        () async {
      expect(await RamadanService.loadFastingDays(), isEmpty);
      await RamadanService.toggleFastingDay(5, true);
      await RamadanService.toggleFastingDay(10, true);
      await RamadanService.toggleFastingDay(10, false);
      final map = await RamadanService.loadFastingDays();
      expect(map[5], isTrue);
      expect(map[10], isFalse);
      expect(await RamadanService.fastedDaysCount(), 1);
    });

    test('corrupt entries are skipped, legacy Gregorian key is adopted',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final gy = DateTime.now().year;
      await prefs
          .setStringList('ramadan_fasting_$gy', ['7:1', 'oops', 'nine:1']);
      final map = await RamadanService.loadFastingDays();
      expect(map[7], isTrue);
      expect(map.length, 1);
      // Adopted into the Hijri-year key; legacy key removed.
      expect(prefs.getStringList('ramadan_fasting_$gy'), isNull);
    });
  });

  group('quran tracker', () {
    test('juz list toggles and completion rounds reset it', () async {
      await RamadanService.toggleQuranJuz(1, true);
      await RamadanService.toggleQuranJuz(3, true);
      await RamadanService.toggleQuranJuz(3, false);
      expect(await RamadanService.loadQuranJuzCompleted(), {1});

      expect(await RamadanService.loadQuranCompletions(), 0);
      expect(await RamadanService.completeQuranRound(), 1);
      expect(await RamadanService.loadQuranCompletions(), 1);
      expect(await RamadanService.loadQuranJuzCompleted(), isEmpty);
    });
  });

  group('taraweeh tracker', () {
    test('prayed days are counted', () async {
      await RamadanService.toggleTaraweehDay(1, true);
      await RamadanService.toggleTaraweehDay(2, false);
      expect(await RamadanService.taraweehDaysCount(), 1);
      expect((await RamadanService.loadTaraweehDays())[1], isTrue);
    });
  });

  group('night prayers tracker', () {
    test('prayed nights are counted', () async {
      await RamadanService.toggleNightPrayer(21, true);
      await RamadanService.toggleNightPrayer(23, true);
      await RamadanService.toggleNightPrayer(21, false);
      expect(await RamadanService.nightPrayersCount(), 1);
      expect((await RamadanService.loadNightPrayers())[23], isTrue);
    });
  });

  group('last ten days checklist', () {
    test('items start false and toggle persists (key matches the loader)',
        () async {
      final before = await RamadanService.loadLastTenDaysChecklist();
      expect(before.values.every((v) => !v), isTrue);
      await RamadanService.toggleLastTenDaysItem('last10_itikaf', true);
      final after = await RamadanService.loadLastTenDaysChecklist();
      expect(after['last10_itikaf'], isTrue);
      expect(after['last10_laylat'], isFalse);
    });
  });

  group('RamadanAzkar data integrity', () {
    test('every dua has Arabic and Persian text', () {
      for (final dua in RamadanAzkar.iftarDuas) {
        expect(dua.arabic.trim(), isNotEmpty);
        expect(dua.persian.trim(), isNotEmpty);
      }
      expect(RamadanAzkar.iftarDuas, isNotEmpty);
    });

    test('virtue and program entries all have title and text', () {
      for (final entry in [
        ...RamadanAzkar.ramadanVirtues,
        ...RamadanAzkar.lastTenDaysProgram,
        ...RamadanAzkar.specialWorships,
      ]) {
        expect(entry['title']?.trim(), isNotEmpty, reason: 'missing title');
        expect(entry['text']?.trim(), isNotEmpty, reason: 'missing text');
      }
      expect(RamadanAzkar.laylatAlQadrVirtues, isNotEmpty);
      expect(RamadanAzkar.quranVersesForRamadan, isNotEmpty);
    });
  });
}
