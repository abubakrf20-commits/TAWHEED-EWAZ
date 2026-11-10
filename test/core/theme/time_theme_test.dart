import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/shared/models/day_time.dart';

pi.PrayerInfo _p(String name, int h, int m) => pi.PrayerInfo(
      name: name,
      arabicName: name,
      time: DayTime(hour: h, minute: m),
    );

pi.PrayerTimes _schedule() => pi.PrayerTimes(
      date: DateTime(2026, 10, 5),
      fajr: _p('fajr', 4, 31),
      shorouq: _p('shorouq', 5, 49),
      duhr: _p('duhr', 11, 43),
      asr: _p('asr', 15, 4),
      maghrib: _p('maghrib', 17, 38),
      isha: _p('isha', 18, 49),
    );

void main() {
  tearDown(() {
    // Leave the gold brand palette active for any later test in this file.
    AppTheme.applyTheme(kind: ThemeKind.gold, phase: TimePhase.day);
  });

  group('themeKindFromStored normalizes legacy values', () {
    test("'live' and pinned phases map to their kinds", () {
      expect(themeKindFromStored('live'), ThemeKind.live);
      expect(themeKindFromStored('dawn'), ThemeKind.dawn);
      expect(themeKindFromStored('day'), ThemeKind.day);
      expect(themeKindFromStored('sunset'), ThemeKind.sunset);
      expect(themeKindFromStored('night'), ThemeKind.night);
    });

    test('legacy preset ids and null fall back to the default «شب»', () {
      expect(themeKindFromStored('gold'), ThemeKind.gold);
      expect(themeKindFromStored('classic'), ThemeKind.night);
      expect(themeKindFromStored('green'), ThemeKind.night);
      expect(themeKindFromStored(null), ThemeKind.night);
    });
  });

  group('AppPalettes', () {
    test('all 10 palettes are distinct', () {
      final palettes = <AppPalette>{
        AppPalettes.goldLight,
        AppPalettes.goldDark,
        AppPalettes.dawnLight,
        AppPalettes.dawnDark,
        AppPalettes.dayLight,
        AppPalettes.dayDark,
        AppPalettes.sunsetLight,
        AppPalettes.sunsetDark,
        AppPalettes.nightLight,
        AppPalettes.nightDark,
      };
      expect(palettes.length, 10);
    });

    test('of() maps kind/phase/brightness to the right palette', () {
      expect(
        AppPalettes.of(
            kind: ThemeKind.gold, phase: TimePhase.dawn, dark: false),
        same(AppPalettes.goldLight),
      );
      expect(
        AppPalettes.of(
            kind: ThemeKind.live, phase: TimePhase.dawn, dark: false),
        same(AppPalettes.dawnLight),
      );
      expect(
        AppPalettes.of(kind: ThemeKind.live, phase: TimePhase.day, dark: true),
        same(AppPalettes.dayDark),
      );
      expect(
        AppPalettes.of(
            kind: ThemeKind.live, phase: TimePhase.sunset, dark: true),
        same(AppPalettes.sunsetDark),
      );
      expect(
        AppPalettes.of(
            kind: ThemeKind.live, phase: TimePhase.night, dark: true),
        same(AppPalettes.nightDark),
      );
    });

    test('pinned phase kinds ignore the current time phase', () {
      expect(
        AppPalettes.of(
            kind: ThemeKind.dawn, phase: TimePhase.night, dark: false),
        same(AppPalettes.dawnLight),
      );
      expect(
        AppPalettes.of(
            kind: ThemeKind.sunset, phase: TimePhase.day, dark: true),
        same(AppPalettes.sunsetDark),
      );
      expect(
        AppPalettes.of(
            kind: ThemeKind.night, phase: TimePhase.dawn, dark: true),
        same(AppPalettes.nightDark),
      );
    });

    test('dark palettes keep readable text hierarchy', () {
      for (final p in [
        AppPalettes.goldDark,
        AppPalettes.dawnDark,
        AppPalettes.dayDark,
        AppPalettes.sunsetDark,
        AppPalettes.nightDark,
      ]) {
        expect(
          p.textPrimary.computeLuminance(),
          greaterThan(p.textSecondary.computeLuminance()),
        );
        expect(
          p.textSecondary.computeLuminance(),
          greaterThan(p.textMuted.computeLuminance()),
        );
      }
    });
  });

  group('AppTheme.applyTheme bridges palettes into the legacy tokens', () {
    test('live night phase drives both light and dark tokens', () {
      AppTheme.applyTheme(kind: ThemeKind.live, phase: TimePhase.night);
      expect(
        AppTheme.lightScaffoldTint,
        AppPalettes.nightLight.pageBg,
      );
      expect(AppTheme.lightTextPrimary, AppPalettes.nightLight.textPrimary);
      expect(AppTheme.darkPrimary, AppPalettes.nightDark.primary);
      expect(AppTheme.darkScaffoldTint, AppPalettes.nightDark.pageBg);
      expect(AppTheme.activeLightPalette, same(AppPalettes.nightLight));
      expect(AppTheme.activeDarkPalette, same(AppPalettes.nightDark));
    });

    test('gold theme restores the brand palette', () {
      AppTheme.applyTheme(kind: ThemeKind.live, phase: TimePhase.sunset);
      AppTheme.applyTheme(kind: ThemeKind.gold, phase: TimePhase.day);
      expect(AppTheme.lightScaffoldTint, AppPalettes.goldLight.pageBg);
      expect(AppTheme.darkPrimary, AppPalettes.goldDark.primary);
    });

    test('font identity is untouched (Calibri stays the brand font)', () {
      final before = AppTheme.fontFamily;
      AppTheme.applyTheme(kind: ThemeKind.live, phase: TimePhase.dawn);
      expect(AppTheme.fontFamily, before);
      expect(AppTheme.defaultFontFamily, 'Calibri');
    });
  });

  group('TimeThemeKit', () {
    testWidgets('lerp produces an intermediate palette without null-asserts',
        (tester) async {
      const a = TimeThemeKit(AppPalettes.goldLight);
      const b = TimeThemeKit(AppPalettes.nightLight);
      final mid = a.lerp(b, 0.5);
      expect(mid.palette.pageBg, isNot(a.palette.pageBg));
      expect(mid.palette.pageBg, isNot(b.palette.pageBg));
      // Lerping against a foreign extension keeps the receiver.
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith(), same(a));
    });

    testWidgets('ThemeData carries the extension for both brightnesses',
        (tester) async {
      AppTheme.applyTheme(kind: ThemeKind.live, phase: TimePhase.day);
      final light = AppTheme.lightTheme();
      final dark = AppTheme.darkTheme();
      expect(
        light.extension<TimeThemeKit>()?.palette,
        same(AppPalettes.dayLight),
      );
      expect(
        dark.extension<TimeThemeKit>()?.palette,
        same(AppPalettes.dayDark),
      );
    });
  });

  group('phaseForSchedule', () {
    final day = DateTime(2026, 10, 5);

    TimePhase at(int h, int m) => phaseForSchedule(
          DateTime(day.year, day.month, day.day, h, m),
          schedule: _schedule(),
        );

    test('follows the shar\'i day: night→dawn→day→sunset→night', () {
      expect(at(3, 0), TimePhase.night); // before fajr
      expect(at(5, 0), TimePhase.dawn); // after fajr, before sunrise
      expect(at(6, 30), TimePhase.day); // after sunrise
      expect(at(12, 0), TimePhase.day); // after dhuhr
      expect(at(16, 0), TimePhase.sunset); // after asr, before maghrib
      expect(at(18, 0), TimePhase.night); // after maghrib
      expect(at(23, 0), TimePhase.night);
    });
  });

  test('heuristicPhase is a sane fallback without prayer times', () {
    expect(
      heuristicPhase(DateTime(2026, 10, 5, 2)),
      TimePhase.night,
    );
    expect(
      heuristicPhase(DateTime(2026, 10, 5, 5)),
      TimePhase.dawn,
    );
    expect(
      heuristicPhase(DateTime(2026, 10, 5, 12)),
      TimePhase.day,
    );
    expect(
      heuristicPhase(DateTime(2026, 10, 5, 16, 30)),
      TimePhase.sunset,
    );
    expect(
      heuristicPhase(DateTime(2026, 10, 5, 21)),
      TimePhase.night,
    );
  });
}
