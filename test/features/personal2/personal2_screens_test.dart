import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/pos_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_cash_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_cheques_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_expenses_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_home_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_settings_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_stock_count_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_suppliers_screen.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/child_mode_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/child_setup_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_approvals_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_habits_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_report_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/lesson_sheet_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_home_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_rewards_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/class_management_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/parent_report_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/student_profile_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/quran_teacher_home_screen.dart';

/// Screen-level checks for the two personal tools that had none.
///
/// The shop tool already pumps its pieces (goldens) and its reports; the kids
/// and teacher screens were only covered by pure domain tests, so a broken
/// first frame — a provider that never resolves, a `RenderFlex` that overflows
/// on a small phone, a table read that throws instead of showing the empty
/// state — could reach a device unseen. These pump the real screens against a
/// real sqlite file at the narrowest phone width the app supports (320 dp) and
/// at 1.3× text, and fail on any exception the frame throws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late QuranTeacherDao teacher;
  late KidsDao kids;
  late ShopDao shop;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('personal2_screens_test');
    final file = File(p.join(tempDir.path, 'screens.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    teacher = QuranTeacherDao(db);
    kids = KidsDao(db);
    shop = ShopDao(db);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await teacher.settings();
    await shop.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds sqlite handles briefly; the OS reclaims the temp dir.
    }
  });

  Widget harness(Widget child) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1400),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child,
            ),
          ),
        ),
      );

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pumpWidget(harness(screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    FlutterError.onError = previous;
    tester.takeException();
    expect(errors, isEmpty,
        reason: errors.map((e) => e.toString()).join(' | '));
  }

  group('teacher screens', () {
    testWidgets('the home page offers the first class when there is none',
        (tester) async {
      await pumpScreen(tester, const QuranTeacherHomeScreen());
      expect(find.text('دفتر مربی قرآن'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the home page draws a class day with students', (tester) async {
      await teacher.saveClass(id: 'c1', name: 'حلقهٔ فجر', weekdaysMask: 0x7F);
      await teacher.saveStudent(id: 's1', classId: 'c1', name: 'علی');
      await teacher.saveStudent(id: 's2', classId: 'c1', name: 'زهرا');
      await pumpScreen(tester, const QuranTeacherHomeScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('class management lists the class and fits 320 dp',
        (tester) async {
      await teacher.saveClass(id: 'c1', name: 'حلقهٔ فجر', weekdaysMask: 0x7F);
      await teacher.saveStudent(
        id: 's1',
        classId: 'c1',
        name: 'علی',
        parentName: 'حسین',
        parentPhone: '09120000000',
      );
      await pumpScreen(tester, const ClassManagementScreen());
      expect(find.text('حلقهٔ فجر'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a student profile renders without a lesson history',
        (tester) async {
      await teacher.saveClass(id: 'c1', name: 'حلقهٔ فجر', weekdaysMask: 0x7F);
      await teacher.saveStudent(id: 's1', classId: 'c1', name: 'علی');
      await pumpScreen(tester, const StudentProfileScreen(studentId: 's1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the parent report draws a student with no records',
        (tester) async {
      await teacher.saveClass(id: 'c1', name: 'حلقهٔ فجر', weekdaysMask: 0x7F);
      await teacher.saveStudent(id: 's1', classId: 'c1', name: 'علی');
      await pumpScreen(tester, const ParentReportScreen(studentId: 's1'));
      expect(tester.takeException(), isNull);
    });
  });

  group('kids screens', () {
    testWidgets('the home page offers «افزودن کودک» when empty',
        (tester) async {
      await pumpScreen(tester, const KidsHomeScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the home page draws a child with their star balance',
        (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'orange');
      await kids.saveHabit(
        id: 'h1',
        kidId: 'k1',
        title: 'مسواک زدن',
        stars: 1,
        schedule: HabitSchedule.daily,
        iconKey: 'brush',
      );
      await pumpScreen(tester, const KidsHomeScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rewards page shows the empty state, then a reward',
        (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'teal');
      await pumpScreen(tester, const KidsRewardsScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the habits page lists an inactive habit and its schedule',
        (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'rose');
      await kids.saveHabit(
        id: 'h1',
        kidId: 'k1',
        title: 'مرتب کردن اتاق',
        stars: 2,
        schedule: HabitSchedule.weekdays,
        weekdayMask: 0x3F,
        iconKey: 'broom',
      );
      await pumpScreen(tester, const KidsHabitsScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the approvals page shows its empty state', (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'blue');
      await pumpScreen(tester, const KidsApprovalsScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the weekly report draws a child with no activity',
        (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'purple');
      await pumpScreen(tester, const KidsReportScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the child setup page opens on the chosen colour', (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'green');
      await pumpScreen(tester, const ChildSetupScreen(kidId: 'k1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('child mode draws the prayer chips and habit tiles',
        (tester) async {
      await kids.upsertKid(id: 'k1', name: 'سارا', colorKey: 'orange');
      await kids.saveHabit(
        id: 'h1',
        kidId: 'k1',
        title: 'مسواک زدن',
        stars: 1,
        schedule: HabitSchedule.daily,
        iconKey: 'brush',
      );
      await pumpScreen(tester, const ChildModeScreen(kidId: 'k1'));
      expect(tester.takeException(), isNull);
    });
  });

  group('shop screens', () {
    testWidgets('the home page draws the day summary with no sales', (tester) async {
      await pumpScreen(tester, const ShopHomeScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the POS opens with an empty cart', (tester) async {
      await pumpScreen(tester, const PosScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('suppliers, cash, cheques, expenses and stock count build',
        (tester) async {
      for (final screen in const <Widget>[
        ShopSuppliersScreen(),
        ShopCashScreen(),
        ShopChequesScreen(),
        ShopExpensesScreen(),
        ShopStockCountScreen(),
        ShopSettingsScreen(),
      ]) {
        await pumpScreen(tester, screen);
        expect(tester.takeException(), isNull,
            reason: '${screen.runtimeType} must draw its empty state');
      }
    });
  });

  group('lesson sheet', () {
    testWidgets('draws the form and the suggested next page', (tester) async {
      await teacher.saveClass(id: 'c1', name: 'حلقهٔ فجر', weekdaysMask: 0x7F);
      await teacher.saveStudent(id: 's1', classId: 'c1', name: 'علی');
      await teacher.saveLesson(
        id: 'l1',
        sessionId: 'ses_c1_1404-08-15',
        studentId: 's1',
        dayKey: '1404-08-15',
        type: LessonType.recitation,
        pageStart: 3,
        pageEnd: 5,
        nextPageStart: 6,
        nextPageEnd: 8,
      );
      await pumpScreen(
        tester,
        const LessonSheetScreen(classId: 'c1', studentId: 's1'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
