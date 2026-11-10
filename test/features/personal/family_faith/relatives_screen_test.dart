import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/presentation/screens/relatives_screen.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_gift_ideas.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';

import 'family_faith_test_kit.dart';

final _now = DateTime(2026, 9, 12, 8);

/// A tiny catalogue for the widget tests. The real asset is covered by
/// `gift_ideas_test.dart`; here the point is the sheet's behaviour, and a
/// bundled-asset load would race the golden.
const List<GiftIdea> _testIdeas = [
  GiftIdea(
    id: 'fruit',
    title: 'میوهٔ تازهٔ فصل',
    tip: 'به اندازهٔ جمعیت خانه ببرید.',
    occasions: {GiftOccasion.visit, GiftOccasion.sickVisit},
    budgets: {GiftBudget.economy, GiftBudget.medium},
    audiences: {GiftAudience.all, GiftAudience.elder},
  ),
  GiftIdea(
    id: 'book',
    title: 'کتاب',
    tip: 'از علاقهٔ خودش بپرسید.',
    occasions: {GiftOccasion.visit, GiftOccasion.feast},
    budgets: {GiftBudget.medium, GiftBudget.special},
    audiences: {GiftAudience.all},
  ),
];

Relative _relative({
  required String id,
  required String name,
  required RelationKind relation,
  DateTime? lastContactAt,
  int intervalDays = 7,
  String giftNote = '',
}) =>
    Relative(
      id: id,
      name: name,
      relation: relation,
      createdAt: DateTime(2026, 1, 1),
      lastContactAt: lastContactAt,
      intervalDays: intervalDays,
      giftNote: giftNote,
      phone: '09120000000',
    );

RelativesSnapshot _snapshot() => RelativesSnapshot(
      relatives: [
        // Due 8 Sep, today is 12 Sep → overdue.
        _relative(
          id: 'r1',
          name: 'مادر',
          relation: RelationKind.mother,
          lastContactAt: DateTime(2026, 9, 1),
        ),
        // Due 13 Sep → near.
        _relative(
          id: 'r2',
          name: 'عمو رضا',
          relation: RelationKind.paternalUncle,
          lastContactAt: DateTime(2026, 8, 14),
          intervalDays: 30,
        ),
        // Due in a month → ok.
        _relative(
          id: 'r3',
          name: 'خواهر',
          relation: RelationKind.sister,
          lastContactAt: DateTime(2026, 9, 10),
          intervalDays: 14,
          giftNote: 'کتاب',
        ),
      ],
    );

/// A launcher that answers «no app could open this» — what a phone without a
/// dialer, or a blocked intent, returns.
class _RefusingLauncher extends RecordingLauncher {
  @override
  Future<bool> call(Uri uri) async {
    uris.add(uri);
    return false;
  }
}

class _Harness {
  _Harness(this.launcher, this.repo);

  final RecordingLauncher launcher;
  final FakeRelativesRepository repo;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  RelativesSnapshot? snapshot,
  FakeRelativesRepository? repository,
  RecordingLauncher? launcher,
  Size size = const Size(360, 1400),
  double scale = 1,
}) async {
  applyDayTheme();
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final activeLauncher = launcher ?? RecordingLauncher();
  final repo =
      repository ?? FakeRelativesRepository(snapshot ?? _snapshot());
  await tester.pumpWidget(familyTestApp(
    size: size,
    scale: scale,
    overrides: [
      relativesRepositoryProvider.overrideWithValue(repo),
      familyRemindersProvider.overrideWithValue(NoopFamilyReminders()),
      familyUriLauncherProvider.overrideWithValue(activeLauncher.call),
      giftIdeasProvider.overrideWith((ref) => _testIdeas),
    ],
    child: RelativesScreen(nowOverride: _now),
  ));
  await tester.pumpAndSettle();
  return _Harness(activeLauncher, repo);
}

void main() {
  testWidgets('shows the two summary chips and every relative', (tester) async {
    await _pump(tester);
    expect(find.text('صله رحم'), findsOneWidget);
    expect(find.text('1 تماس عقب‌افتاده'), findsOneWidget);
    // No visit or gift is logged yet, and the chip says exactly that instead of
    // inventing a reason to celebrate.
    expect(find.text('در ۳۰ روز اخیر دیداری ثبت نشده'), findsOneWidget);
    expect(find.text('مادر'), findsWidgets);
    expect(find.text('عمو رضا'), findsOneWidget);
    expect(find.text('خواهر'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status chips say how late and how soon', (tester) async {
    await _pump(tester);
    expect(find.text('4 روز دیر'), findsOneWidget);
    expect(find.text('1 روز مانده'), findsOneWidget);
    expect(find.text('به‌روز'), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp with text scale 1.3', (tester) async {
    await _pump(tester, size: const Size(320, 1500), scale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 412 dp', (tester) async {
    await _pump(tester, size: const Size(412, 1400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state offers the add action', (tester) async {
    await _pump(tester, snapshot: const RelativesSnapshot());
    expect(find.text('هنوز کسی را اضافه نکرده‌اید'), findsOneWidget);
    expect(find.text('افزودن نخستین نفر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«تماس» opens tel: and logs the contact with an undo',
      (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('تماس').first);
    await tester.pumpAndSettle();

    expect(harness.launcher.uris.single.scheme, 'tel');
    expect(harness.launcher.uris.single.path, '09120000000');
    expect(find.text('تماس ثبت شد ✓'), findsOneWidget);
    expect(find.text('بازگردانی'), findsOneWidget);
  });

  testWidgets('«پیام» opens sms:', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('پیام').first);
    await tester.pumpAndSettle();
    expect(harness.launcher.uris.single.scheme, 'sms');
    // The toast names what was actually logged, not always «تماس».
    expect(find.text('پیام ثبت شد ✓'), findsOneWidget);
  });

  testWidgets('a dialer that never opens records no contact', (tester) async {
    final repo = FakeRelativesRepository(_snapshot());
    final launcher = _RefusingLauncher();
    await _pump(tester, repository: repo, launcher: launcher);

    await tester.tap(find.text('تماس').first);
    await tester.pumpAndSettle();

    expect(launcher.uris.single.scheme, 'tel');
    expect(repo.snapshot.contacts, isEmpty,
        reason: 'a call that never happened may not tick the cycle');
    expect(find.textContaining('چیزی ثبت نشد'), findsOneWidget);
    expect(find.text('تماس ثبت شد ✓'), findsNothing);
  });

  testWidgets('deleting says what was removed', (tester) async {
    final repo = FakeRelativesRepository(_snapshot());
    await _pump(tester, repository: repo);

    await tester.tap(find.byTooltip('بیشتر').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(repo.snapshot.relatives.any((r) => r.id == 'r1'), isFalse);
    expect(find.text('«مادر» حذف شد'), findsOneWidget);
  });

  testWidgets('an empty archive is not worth a toggle', (tester) async {
    await _pump(tester);
    expect(find.textContaining('بایگانی'), findsNothing);
  });

  testWidgets('the archive toggle appears once someone is archived',
      (tester) async {
    await _pump(
      tester,
      snapshot: RelativesSnapshot(relatives: [
        ..._snapshot().relatives,
        _relative(
          id: 'r4',
          name: 'پدربزرگ',
          relation: RelationKind.grandfather,
        ).copyWith(archived: true),
      ]),
    );
    expect(find.text('بایگانی (1)', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a relative without a number gets a hint, not a launch',
      (tester) async {
    final repo = FakeRelativesRepository(RelativesSnapshot(relatives: [
      Relative(
        id: 'no-phone',
        name: 'دایی',
        relation: RelationKind.maternalUncle,
        createdAt: DateTime(2026, 1, 1),
      ),
    ]));
    await _pump(tester, snapshot: repo.snapshot);
    await tester.tap(find.text('تماس').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('شماره‌ای ثبت نشده'), findsOneWidget);
  });

  testWidgets('the gift sheet filters and saves an idea for the relative',
      (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('هدیه').first);
    await tester.pumpAndSettle();

    expect(find.text('هدیه برای مادر'), findsOneWidget);
    // Islamic / ordinary-family occasions only — no «تولد».
    expect(find.text('عیادت'), findsOneWidget);
    expect(find.text('تولد'), findsNothing);

    // «میوهٔ تازهٔ فصل» is tagged visit + medium + elder, so it is visible for
    // the mother at the default filters.
    await tester.tap(find.text('میوهٔ تازهٔ فصل').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیرهٔ ایده'));
    await tester.tap(find.text('ذخیرهٔ ایده'));
    await tester.pumpAndSettle();

    final saved = harness.repo.snapshot.relatives
        .firstWhere((relative) => relative.id == 'r1');
    expect(saved.giftNote, 'میوهٔ تازهٔ فصل');
    expect(tester.takeException(), isNull);
  });

  testWidgets('«دیدار» logs a visit without needing a phone number',
      (tester) async {
    final repo = FakeRelativesRepository(RelativesSnapshot(relatives: [
      Relative(
        id: 'no-phone',
        name: 'دایی',
        relation: RelationKind.maternalUncle,
        createdAt: DateTime(2026, 1, 1),
      ),
    ]));
    await _pump(tester, repository: repo);
    await tester.tap(find.text('دیدار'));
    await tester.pumpAndSettle();

    expect(find.text('دیدار ثبت شد ✓'), findsOneWidget);
    expect(repo.snapshot.contacts.single.kind, ContactKind.visit);
    expect(repo.snapshot.relatives.single.lastContactAt, isNotNull);
  });

  testWidgets('the history sheet shows the log and the per-kind counts',
      (tester) async {
    final repo = FakeRelativesRepository(RelativesSnapshot(
      relatives: [
        _relative(
          id: 'r1',
          name: 'مادر',
          relation: RelationKind.mother,
          lastContactAt: DateTime(2026, 9, 5),
        ),
      ],
      contacts: [
        ContactLog(
          id: 'c1',
          relativeId: 'r1',
          date: DateTime(2026, 9, 5),
          kind: ContactKind.visit,
        ),
        ContactLog(
          id: 'c2',
          relativeId: 'r1',
          date: DateTime(2026, 8, 30),
          kind: ContactKind.gift,
          note: 'عسل',
        ),
      ],
    ));
    await _pump(tester, repository: repo);

    // The card already summarises the two rows.
    expect(find.textContaining('هدیه: عسل'), findsOneWidget);

    await tester.tap(find.text('مادر').first);
    await tester.pumpAndSettle();

    expect(find.text('تاریخچهٔ مادر'), findsOneWidget);
    expect(find.text('دیدار'), findsWidgets);
    expect(find.textContaining('هدیه · عسل'), findsOneWidget);

    // Deleting the newest row repairs the card's last-contact day.
    await tester.tap(find.byTooltip('حذف این ردیف').first);
    await tester.pumpAndSettle();
    expect(repo.snapshot.contacts, hasLength(1));
    expect(repo.snapshot.relatives.single.lastContactAt, DateTime(2026, 8, 30));
  });

  testWidgets('a custom gift can be written down and picked', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('هدیه').first);
    await tester.pumpAndSettle();

    expect(find.text('هدیه‌های دلخواه من'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'افزودن'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'عسل طبیعی',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'افزودن'));
    await tester.pumpAndSettle();

    // The new chip is on the sheet, and picking it fills the gift field.
    expect(find.text('عسل طبیعی'), findsWidgets);
    await tester.tap(find.text('عسل طبیعی').first);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller?.text, 'عسل طبیعی');
  });

  testWidgets('«هدیه دادم» writes a gift row into the log', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('هدیه').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'کتاب');
    await tester.pump();
    await tester.tap(find.text('هدیه دادم'));
    await tester.pumpAndSettle();

    final contact = harness.repo.snapshot.contacts.single;
    expect(contact.kind, ContactKind.gift);
    expect(contact.note, 'کتاب');
    expect(
      harness.repo.snapshot.relatives
          .firstWhere((relative) => relative.id == 'r1')
          .giftNote,
      'کتاب',
    );
  });

  testWidgets('golden: relatives list with ok / soon / overdue (day, 360)',
      (tester) async {
    await _pump(tester);
    await expectLater(
      find.byType(RelativesScreen),
      matchesGoldenFile('goldens/relatives_day.png'),
    );
  });

  testWidgets('golden: gift sheet (day, 360)', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('هدیه').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/gift_sheet_day.png'),
    );
  });
}
