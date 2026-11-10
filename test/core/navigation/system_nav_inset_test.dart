import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_report_screen.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_screen.dart';
import 'package:tawheeed/features/reminders/data/daos/reminder_dao.dart';
import 'package:tawheeed/features/reminders/presentation/screens/reminder_editor_screen.dart';
import 'package:tawheeed/features/reminders/presentation/screens/reminders_screen.dart';

import '../../core/database/mock_daos.dart';

/// System navigation bar vs tappable content.
///
/// On 3-button phones the bar is an overlay (~48dp): any bottom-anchored
/// control without a live inset ends up behind the buttons and untappable
/// (the قاف search box, the reminders FAB, the hifz/editor bottom rows).
/// Every fix under test is ADDITIVE (live inset + the page's own padding),
/// so a phone without the bar (inset zero) renders pixel-identical — and the
/// goldens, which run at zero inset, prove it.
///
/// These tests pump the reported screens with a 48dp bottom inset and assert
/// the bottom content stays above it.

/// 3-button navigation bar height the reports came from.
const double kNavBarInset = 48;

const Size kPhone = Size(412, 800);

/// Content must end above this line: the inset zone below it belongs to the
/// system buttons.
const double kSafeLine = 800 - kNavBarInset;

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = kPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Wide phone for pages whose rows use the Material default face: the test
/// binding draws those glyphs as full-em tofu (no Persian fallback), so they
/// overflow below ~800dp while fitting on a real phone. Height stays 800, so
/// [kSafeLine] still applies.
void setWidePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The page runs under a 48dp bottom inset, like a 3-button phone. The theme
/// carries the app's font family (main.dart wires it the same way on device),
/// so cases that load Vazirmatn get real glyph metrics; without the loaded
/// font the family resolves to the binding's test font either way.
Widget insetApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(fontFamily: AppTheme.fontFamily),
    home: MediaQuery(
      data: const MediaQueryData(
        padding: EdgeInsets.only(bottom: kNavBarInset),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

/// Guards against vacuous tests: the inset must actually reach the page.
void expectInsetInEffect(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(MediaQuery.paddingOf(context).bottom, kNavBarInset);
}

/// Real Persian shaping: the test binding's font draws every glyph ~1.7x
/// wider than Vazirmatn, so narrow rows overflow in tofu that fit on a real
/// phone. Same pattern as the settings truncation guard.
Future<void> loadVazirmatn(WidgetTester tester) async {
  final loader = FontLoader('Vazirmatn')
    ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  await loader.load();
  AppTheme.fontFamily = 'Vazirmatn';
  addTearDown(() => AppTheme.fontFamily = AppTheme.defaultFontFamily);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      return true;
    },
  );

  group('InsetFab', () {
    Future<Rect> pumpFab(WidgetTester tester, double inset) async {
      setPhone(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: InsetFab(
            inset: inset,
            child: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(FloatingActionButton));
    }

    testWidgets('clears a 3-button bar', (tester) async {
      final rect = await pumpFab(tester, kNavBarInset);
      expect(rect.bottom, lessThanOrEqualTo(kSafeLine));
    });

    testWidgets('adds nothing where there is no bar', (tester) async {
      final wrapped = await pumpFab(tester, 0);

      // The same FAB without the wrapper, at zero inset.
      setPhone(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final bare = tester.getRect(find.byType(FloatingActionButton));

      expect(wrapped.bottom, bare.bottom);
      expect(wrapped.top, bare.top);
    });
  });

  group('every FAB goes through InsetFab', () {
    // All 14 FAB screens (the 7 personal_info screens were covered with
    // explicit user authorization) use the shared recipe — a bare
    // floatingActionButton sits behind the 3-button system bar.
    const fabScreens = [
      'lib/features/reminders/presentation/screens/reminders_screen.dart',
      'lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart',
      'lib/features/expenses/presentation/screens/expenses_screen.dart',
      'lib/features/goals/presentation/screens/goals_screen.dart',
      'lib/features/notes/presentation/screens/worship_notes_screen.dart',
      'lib/features/khatm/presentation/screens/khatm_screen.dart',
      'lib/features/tasks/presentation/screens/tasks_screen.dart',
      'lib/features/personal_info/presentation/screens/emergency_contacts_screen.dart',
      'lib/features/personal_info/presentation/screens/credentials_screen.dart',
      'lib/features/personal_info/presentation/screens/documents_screen.dart',
      'lib/features/personal_info/presentation/screens/assets_screen.dart',
      'lib/features/personal_info/presentation/screens/profiles_screen.dart',
      'lib/features/personal_info/presentation/screens/insurance_screen.dart',
      'lib/features/personal_info/presentation/screens/expiry_screen.dart',
    ];

    test('all fourteen FAB screens use the shared recipe', () {
      for (final path in fabScreens) {
        final source = File(path).readAsStringSync();
        expect(source, contains('InsetFab('), reason: path);
      }
    });
  });

  group('reported screens under a 3-button bar', () {
    testWidgets('reminders FAB stays above the bar', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          reminderDaoProvider.overrideWithValue(MockReminderDao()),
        ],
        child: insetApp(const RemindersScreen()),
      ));
      await tester.pumpAndSettle();

      expectInsetInEffect(tester);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(fab.bottom, lessThanOrEqualTo(kSafeLine));
    });

    testWidgets('editor last row scrolls above the bar', (tester) async {
      setPhone(tester);
      await loadVazirmatn(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          reminderDaoProvider.overrideWithValue(MockReminderDao()),
        ],
        child: insetApp(const ReminderEditorScreen()),
      ));
      await tester.pumpAndSettle();

      expectInsetInEffect(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      // The custom-sound row is the last interactive row; its label repeats
      // the first sound option, so take the last match.
      final last = tester.getRect(find.text('صدای پیش‌فرض سیستم').last);
      expect(last.bottom, lessThanOrEqualTo(kSafeLine));
    });

    testWidgets('hifz last row scrolls above the bar', (tester) async {
      setPhone(tester);
      // Same recipe as the editor/report cases: the binding's font draws every
      // glyph ~1.7x wider, and a month-crossing week label («۲۵ مهر تا ۱ آبان
      // ۱۴۰۵») overflows the selector header in tofu while fitting on a real
      // phone — this case used to fail on every month-crossing week.
      await loadVazirmatn(tester);
      final db = AppDatabase.withConnection(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      await container.read(hifzProvider.notifier).addHafiz(name: 'حافظ');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: insetApp(const HifzScreen()),
      ));
      await tester.pumpAndSettle();

      expectInsetInEffect(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final last =
          tester.getRect(find.textContaining('مراجعهای در این روز'));
      expect(last.bottom, lessThanOrEqualTo(kSafeLine));
    });

    testWidgets('report footer scrolls above the bar', (tester) async {
      setWidePhone(tester);
      await loadVazirmatn(tester);
      final now = DateTime.now();
      await tester.pumpWidget(insetApp(HifzReportScreen(
        hafiz: HafizModel(id: 'h1', name: 'حافظ', createdAt: now),
        lessons: [
          HifzLessonModel(
            id: 'l1',
            hafizId: 'h1',
            date: now,
            surahFrom: 2,
            ayahFrom: 1,
            surahTo: 2,
            ayahTo: 6,
            pages: 2,
            createdAt: now,
          ),
        ],
        reviews: [
          HifzReviewModel(
            id: 'r1',
            hafizId: 'h1',
            date: now,
            type: ReviewType.sabaq,
            surahFrom: 2,
            ayahFrom: 1,
            surahTo: 2,
            ayahTo: 6,
            pages: 2,
            quality: ReviewQuality.excellent,
            createdAt: now,
          ),
        ],
      )));
      await tester.pumpAndSettle();

      expectInsetInEffect(tester);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      final footer = tester.getRect(find.textContaining('تولید شده در'));
      expect(footer.bottom, lessThanOrEqualTo(kSafeLine));
    });
  });
}
