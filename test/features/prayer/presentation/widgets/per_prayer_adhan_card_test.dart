import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/settings_components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

import 'per_prayer_card_pump.dart';

/// The «اذان و اقامه هر نماز» card (Design A), in isolation.
///
/// The core contract under test: an adhan switched OFF dims ONLY the voice
/// chip — the per-prayer adhan shift and the adhan→iqamah interval stay at
/// full strength and keep working (the a/c rule the user decided). The bulk
/// chips carry a snapshot-based undo whose snapshot is captured BEFORE the
/// write, so «واگرد» restores the pre-action state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prayers = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

  Finder block(String name) => find.byKey(ValueKey('adhan-block-$name'));
  Finder azanStepper(String prayer) => find.byWidgetPredicate(
      (w) => w is SettingsStepper && w.semanticLabel == 'جابجایی اذان $prayer');
  Finder iqamahStepper(String prayer) => find.byWidgetPredicate(
      (w) => w is SettingsStepper && w.semanticLabel == 'فاصله اقامه $prayer');

  /// The first voice chip in tree order is fajr's (the bulk menus are typed
  /// <Object>, so they never disturb the <String> lookup).
  Finder fajrChip() => find.descendant(
        of: block('فجر'),
        matching: find.byType(PopupMenuButton<String>),
      );

  SettingsSwitch azanSwitchOf(WidgetTester tester, String name) =>
      tester.widget<SettingsSwitch>(
        find.descendant(of: block(name), matching: find.byType(SettingsSwitch)),
      );

  /// Used after every stepper tap: the notifier debounces its alarm
  /// reschedule by 350 ms and flutter_test fails on an orphan timer.
  Future<void> pumpDebounce(WidgetTester tester) => tester
      .pumpAndSettle()
      .then((_) => tester.pump(const Duration(milliseconds: 500)));

  testWidgets('the card renders bulk chips, five blocks and their controls',
      (tester) async {
    await pumpCard(tester, settings: const AppSettings());

    for (final label in ['صدا برای همه', 'اقامه یکسان', 'بازنشانی']) {
      expect(find.text(label), findsOneWidget, reason: 'bulk «$label»');
    }
    for (final name in prayers) {
      expect(block(name), findsOneWidget, reason: 'block «$name»');
      expect(
        find.descendant(of: block(name), matching: azanStepper(name)),
        findsOneWidget,
        reason: 'shift «$name»',
      );
      expect(
        find.descendant(of: block(name), matching: iqamahStepper(name)),
        findsOneWidget,
        reason: 'iqamah «$name»',
      );
    }
    // Captions: the two labels print once per block ×5, in every layout mode.
    expect(find.text('جابجایی اذان (دقیقه)'), findsNWidgets(5));
    expect(find.text('تا اقامه (دقیقه)'), findsNWidgets(5));
  });

  testWidgets('unit matrix — adhan on/off × shift × iqamah', (tester) async {
    final combos = <AppSettings>[
      const AppSettings(
        azanEnabledForFajr: true,
        azanEnabledForDhuhr: true,
        azanEnabledForAsr: true,
        azanEnabledForMaghrib: true,
        azanEnabledForIsha: true,
        fajrOffset: -5,
        iqamahOffsetFajr: 0,
      ),
      const AppSettings(
        azanEnabledForFajr: true,
        azanEnabledForDhuhr: true,
        azanEnabledForAsr: true,
        azanEnabledForMaghrib: true,
        azanEnabledForIsha: true,
        // fajr unshifted (fajrOffset 0).
        iqamahOffsetFajr: 10,
      ),
      const AppSettings(
        azanEnabledForFajr: true,
        azanEnabledForDhuhr: true,
        azanEnabledForAsr: true,
        azanEnabledForMaghrib: true,
        azanEnabledForIsha: true,
        fajrOffset: 2,
        // iqamah at its default (30).
      ),
      // Every adhan OFF while fajr still carries a shifted time and its
      // default iqamah — the regression corner of the matrix.
      const AppSettings(fajrOffset: 2),
    ];

    for (final combo in combos) {
      final harness = await pumpCard(tester, settings: combo);
      final reason = '» combo shift=${combo.fajrOffset} '
          'iqamah=${combo.iqamahOffsetFajr} on=${combo.azanEnabledForFajr}';

      expect(azanSwitchOf(tester, 'فجر').value, combo.azanEnabledForFajr,
          reason: 'switch $reason');
      expect(
        tester.widget<SettingsStepper>(azanStepper('فجر')).value,
        combo.fajrOffset,
        reason: 'shift value $reason',
      );
      expect(
        tester.widget<SettingsStepper>(iqamahStepper('فجر')).value,
        combo.iqamahOffsetFajr,
        reason: 'iqamah value $reason',
      );

      // +1 on the fajr shift writes fajr only.
      await tester.tap(
        find.descendant(
            of: azanStepper('فجر'), matching: find.byIcon(Icons.add_rounded)),
      );
      await pumpDebounce(tester);

      final saved = await harness.repo.getSettings();
      final expected = combo.fajrOffset + 1;
      expect(saved.fajrOffset, expected < 70 ? expected : 70,
          reason: 'write $reason');
      expect(saved.iqamahOffsetFajr, combo.iqamahOffsetFajr,
          reason: 'iqamah untouched $reason');
      expect(saved.dhuhrOffset, combo.dhuhrOffset, reason: 'dhuhr untouched');
    }
  });

  testWidgets('steppers clamp to the −70..70 / 0..70 ranges', (tester) async {
    final cases = <(AppSettings, bool, bool, int)>[
      // (start, isShift, up, clamped expected fajr shift / iqamah)
      (const AppSettings(fajrOffset: 70), true, true, 70),
      (const AppSettings(fajrOffset: -70), true, false, -70),
      (const AppSettings(iqamahOffsetFajr: 70), false, true, 70),
      (const AppSettings(iqamahOffsetFajr: 0), false, false, 0),
    ];

    for (final (start, isShift, up, expected) in cases) {
      final harness = await pumpCard(tester, settings: start);

      final finder = isShift ? azanStepper('فجر') : iqamahStepper('فجر');
      await tester.tap(
        find.descendant(
          of: finder,
          matching: find.byIcon(up ? Icons.add_rounded : Icons.remove_rounded),
        ),
      );
      await pumpDebounce(tester);

      final saved = await harness.repo.getSettings();
      final other = isShift
          ? (saved.iqamahOffsetFajr == start.iqamahOffsetFajr)
          : (saved.fajrOffset == start.fajrOffset);
      expect(other, isTrue, reason: 'the other counter is untouched');
      if (isShift) {
        expect(saved.fajrOffset, expected, reason: 'shift clamp');
        expect(saved.iqamahOffsetFajr, start.iqamahOffsetFajr);
      } else {
        expect(saved.iqamahOffsetFajr, expected, reason: 'iqamah clamp');
        expect(saved.fajrOffset, start.fajrOffset);
      }
    }
  });

  testWidgets('regression — azan OFF leaves the times editable in place',
      (tester) async {
    // OFF with a shifted fajr: the mute must never freeze the shift or the
    // iqamah interval (the a/c rule).
    final harness = await pumpCard(
      tester,
      settings: const AppSettings(
          azanSound: 'kamel', fajrOffset: -5, iqamahOffsetFajr: 27),
    );

    // The switch reads off.
    expect(azanSwitchOf(tester, 'فجر').value, isFalse);
    // The voice chip is disabled; the stored voice survives behind it.
    expect(tester.widget<PopupMenuButton<String>>(fajrChip()).enabled, isFalse);

    // The steppers keep the accent border (NOT the muted chip colors) and
    // both counters still write.
    final shiftStepper = tester.widget<SettingsStepper>(azanStepper('فجر'));
    expect(
      shiftStepper.borderColor,
      HomeColors.fajr.withValues(alpha: 0.20),
    );

    // Only the chip dims: at OFF the name keeps the primary ink and the
    // tile keeps the prayer accent (pinned visually — the a/c rule).
    final palette = TimeThemeKit.of(tester.element(block('فجر'))).palette;
    final nameText = tester.widget<Text>(find.descendant(
      of: block('فجر'),
      matching: find.byWidgetPredicate((w) => w is Text && w.data == 'فجر'),
    ));
    expect(nameText.style!.color, palette.textPrimary);
    expect(
      tester
          .widget<DuotoneIconTile>(
            find.descendant(
                of: block('فجر'), matching: find.byType(DuotoneIconTile)),
          )
          .accent,
      HomeColors.fajr,
    );

    await tester.tap(
      find.descendant(
          of: azanStepper('فجر'), matching: find.byIcon(Icons.add_rounded)),
    );
    await pumpDebounce(tester);
    var saved = await harness.repo.getSettings();
    expect(saved.fajrOffset, -4, reason: 'the shift works at OFF');

    await tester.tap(
      find.descendant(
          of: iqamahStepper('فجر'), matching: find.byIcon(Icons.add_rounded)),
    );
    await pumpDebounce(tester);
    saved = await harness.repo.getSettings();
    expect(saved.iqamahOffsetFajr, 28, reason: 'the iqamah works at OFF');

    // The OFF prayer's popup never opens («تکبیر» is a popup-only item under
    // the kamel voice), and the chip labels stay put.
    await tester.tap(fajrChip());
    await tester.pumpAndSettle();
    expect(find.text('تکبیر'), findsNothing);
    expect(find.text('کامل'), findsNWidgets(5));
  });

  testWidgets('one ON prayer keeps its chip alive among the dimmed ones',
      (tester) async {
    await pumpCard(
      tester,
      settings: const AppSettings(azanEnabledForAsr: true, azanSound: 'kamel'),
    );

    final asrChip = find.descendant(
      of: block('عصر'),
      matching: find.byType(PopupMenuButton<String>),
    );
    // ON asr opens its popup and takes the selection…
    expect(tester.widget<PopupMenuButton<String>>(asrChip).enabled, isTrue);
    expect(tester.widget<PopupMenuButton<String>>(fajrChip()).enabled, isFalse);

    await tester.tap(asrChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تکبیر').last);
    await tester.pumpAndSettle();
    await pumpDebounce(tester);

    // …and the override lands on asr's OWN slot, nowhere else.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('azan_sound_asr'), 'takbir');
    expect(prefs.containsKey('azan_sound_fajr'), isFalse);
  });

  testWidgets('semantics: per-prayer labels, «غیرفعال» pinned to the chip',
      (tester) async {
    await pumpCard(
      tester,
      settings: const AppSettings(azanEnabledForFajr: true),
    );

    // The chip labels are asserted at the widget level: the semantics tree
    // merges the inner tooltip, so an exact match must come from the
    // Semantics widget's own properties.
    Finder chipByLabel(String label) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        );

    // fajr is ON: the unqualified label, and the node is enabled.
    expect(chipByLabel('انتخاب صدای اذان فجر'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(chipByLabel('انتخاب صدای اذان فجر'))
          .properties
          .enabled,
      isTrue,
    );

    // dhuhr is OFF (defaults): its chip's label carries «غیرفعال» and its
    // node is disabled; the unqualified label must not exist for it.
    expect(chipByLabel('انتخاب صدای اذان ظهر'), findsNothing);
    expect(chipByLabel('انتخاب صدای اذان ظهر — غیرفعال'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(chipByLabel('انتخاب صدای اذان ظهر — غیرفعال'))
          .properties
          .enabled,
      isFalse,
    );

    // The OFF prayer's counters keep their plain working-control labels —
    // they are never dimmed into a disabled announcement (the a/c rule).
    expect(
      find.byWidgetPredicate(
          (w) => w is SettingsStepper && w.semanticLabel == 'جابجایی اذان ظهر'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
          (w) => w is SettingsStepper && w.semanticLabel == 'فاصله اقامه ظهر'),
      findsOneWidget,
    );
  });

  testWidgets('control grid degrades 3-col → 2-row → stacked by width',
      (tester) async {
    Future<void> expectMode(
      double width, {
      required bool three,
      required bool stacked,
    }) async {
      await pumpCard(tester, settings: const AppSettings(), width: width);

      final chipRect =
          tester.getRect(find.byKey(const ValueKey('adhan-voice-فجر')));
      final shiftTop = tester.getTopLeft(azanStepper('فجر')).dy;
      final iqamahTop = tester.getTopLeft(iqamahStepper('فجر')).dy;

      if (three) {
        // One shared row: both counters share a dy; the chip sits next to
        // them (its cell is a caption-level higher only by the two
        // captions above the counters).
        expect(iqamahTop, shiftTop, reason: '3-col steppers share a row');
        expect(shiftTop - chipRect.top, lessThan(30),
            reason: '3-col proximity');
      } else if (stacked) {
        // Each control on its own captioned row.
        expect(iqamahTop - shiftTop, greaterThan(30),
            reason: 'stacked counters split');
        expect(shiftTop - chipRect.bottom, greaterThan(0),
            reason: 'stacked chip above');
      } else {
        // The phone norm: the chip owns the first row, the two counters
        // share the second.
        expect(iqamahTop, shiftTop, reason: '2-row steppers share a row');
        expect(shiftTop - chipRect.bottom, greaterThan(0),
            reason: '2-row chip above');
      }
    }

    // 412dp — card grid gets ~372px: stepper unit (372−12)/3.15 ≈ 114 < 124
    // → the two-row fallback (the phone norm).
    await expectMode(412, three: false, stacked: false);
    // 800dp — unit ≈ 236 → the three-column row.
    await expectMode(800, three: true, stacked: false);
    // 240dp — everything stacked.
    await expectMode(240, three: false, stacked: true);
  });

  testWidgets('toggling a prayer ON re-enables its chip in place',
      (tester) async {
    await pumpCard(
      tester,
      settings: const AppSettings(azanSound: 'kamel'),
    );

    // OFF: the popup does not open («تکبیر» = a popup-only item shape under
    // the kamel shared voice).
    await tester.tap(fajrChip());
    await tester.pumpAndSettle();
    expect(find.text('تکبیر'), findsNothing);

    // Flip fajr's adhan on — the SAME switch row turns its chip live.
    await tester.tap(find.descendant(
        of: block('فجر'), matching: find.byType(SettingsSwitch)));
    await tester.pumpAndSettle();
    await pumpDebounce(tester);

    expect(tester.widget<PopupMenuButton<String>>(fajrChip()).enabled, isTrue);
    await tester.tap(fajrChip());
    await tester.pumpAndSettle();
    expect(find.text('تکبیر'), findsOneWidget);
  });

  testWidgets('bulk «اقامه یکسان» writes all five, «صدا برای همه» all slots',
      (tester) async {
    final harness = await pumpCard(
      tester,
      settings: const AppSettings(azanSound: 'kamel'),
    );

    await tester.tap(find.text('اقامه یکسان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 دقیقه'));
    await tester.pumpAndSettle();
    await pumpDebounce(tester);

    var saved = await harness.repo.getSettings();
    expect(saved.iqamahOffsetFajr, 45);
    expect(saved.iqamahOffsetDhuhr, 45);
    expect(saved.iqamahOffsetAsr, 45);
    expect(saved.iqamahOffsetMaghrib, 45);
    expect(saved.iqamahOffsetIsha, 45);

    await tester.tap(find.text('صدا برای همه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شخصی').last);
    await tester.pumpAndSettle();
    await pumpDebounce(tester);

    final prefs = await SharedPreferences.getInstance();
    for (final slot in PrayerSlot.values) {
      expect(
        prefs.getString('azan_sound_${slot.name}'),
        'custom',
        reason: 'slot ${slot.name}',
      );
    }

    // Bulk actions never touch the toggles or the shared voice row.
    saved = await harness.repo.getSettings();
    expect(saved.azanSound, 'kamel');
    expect(saved.azanEnabledForFajr, isFalse);
  });

  testWidgets(
      'bulk «بازنشانی» + «واگرد» restores the snapshot taken BEFORE the write',
      (tester) async {
    final harness = await pumpCard(
      tester,
      settings: const AppSettings(
        azanSound: 'kamel',
        azanEnabledForFajr: true,
        fajrOffset: 3,
        iqamahOffsetFajr: 20,
      ),
      prefs: const {'azan_sound_fajr': 'takbir'},
    );

    await tester.tap(find.text('بازنشانی'));
    await tester.pumpAndSettle();
    await pumpDebounce(tester);

    // Reset: shifts to 0, iqamahs to defaults, voice overrides cleared —
    // the toggles and the shared voice stay untouched.
    var saved = await harness.repo.getSettings();
    expect(saved.fajrOffset, 0);
    expect(saved.iqamahOffsetFajr, 30);
    expect(saved.azanEnabledForFajr, isTrue);
    expect(saved.azanSound, 'kamel');
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('azan_sound_fajr'), isNull);

    // The undo bar is up.
    expect(find.text('بخش اذان و اقامه بازنشانی شد'), findsOneWidget);
    expect(find.text('واگرد'), findsOneWidget);

    // Undo: the PRE-ACTION values must come back — this fails whenever the
    // snapshot were taken after the write (it would restore 0/30/custom).
    await tester.tap(find.text('واگرد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));

    saved = await harness.repo.getSettings();
    expect(saved.fajrOffset, 3);
    expect(saved.iqamahOffsetFajr, 20);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('azan_sound_fajr'), 'takbir');
  });
}
