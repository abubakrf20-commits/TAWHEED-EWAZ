import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/reminders/data/daos/reminder_dao.dart';
import 'package:tawheeed/features/reminders/presentation/screens/reminders_screen.dart';
import '../../../../core/database/mock_daos.dart';

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

  void setTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  /// Production is Persian-only (RTL); the tests must match.
  Widget app(Widget child) {
    return MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  testWidgets('empty state shows the motivational virtues screen',
      (tester) async {
    setTallViewport(tester);
    final mockDao = MockReminderDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderDaoProvider.overrideWithValue(mockDao)],
        child: app(const RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('یادآورها'), findsWidgets);
    expect(find.text('هنوز یادآوری تنظیم نکرده‌اید'), findsOneWidget);
    expect(find.text('افزودن اولین یادآور'), findsOneWidget);
  });

  testWidgets('shows hero, today card and reminder cards', (tester) async {
    setTallViewport(tester);
    final mockDao = MockReminderDao();
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'داروی صبح',
      note: '',
      hour: 8,
      minute: 30,
      daysOfWeek: '[]', // every day → matches today
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await mockDao.upsertReminder(ReminderTableData(
      id: '2',
      title: 'قرار ملاقات',
      note: '',
      hour: 17,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: false,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderDaoProvider.overrideWithValue(mockDao)],
        child: app(const RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // One compact summary card (progress + today merged) + filter row + tiles.
    expect(find.text('پیشرفت یادآورها'), findsOneWidget);
    expect(find.text('داروی صبح'), findsWidgets);
    expect(find.text('قرار ملاقات'), findsOneWidget);
    expect(find.text('08:30'), findsWidgets);
    // «امروز» badge on the enabled daily reminder + stat label; «غیرفعال»
    // pill on the disabled reminder + stat label.
    expect(find.text('امروز'), findsWidgets);
    expect(find.text('غیرفعال'), findsWidgets);
  });

  testWidgets('امروز filter keeps only reminders matching today',
      (tester) async {
    setTallViewport(tester);
    final mockDao = MockReminderDao();
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'روزانه',
      note: '',
      hour: 8,
      minute: 30,
      daysOfWeek: '[]', // matches today
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await mockDao.upsertReminder(ReminderTableData(
      id: '2',
      title: 'یک‌بار آینده',
      note: '',
      hour: 17,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      specificDate: DateTime.now().add(const Duration(days: 5)),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderDaoProvider.overrideWithValue(mockDao)],
        child: app(const RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Both visible in the default list.
    expect(find.text('روزانه'), findsWidgets);
    expect(find.text('یک‌بار آینده'), findsOneWidget);

    // Tap the «امروز» filter chip (scroll the horizontal bar into view
    // first) → only the daily reminder remains (the title shows in both the
    // next-reminder card and the tile).
    final todayFilter = find.text('امروز (1)');
    await tester.ensureVisible(todayFilter);
    await tester.pumpAndSettle();
    await tester.tap(todayFilter);
    await tester.pumpAndSettle();
    expect(find.text('روزانه'), findsWidgets);
    expect(find.text('یک‌بار آینده'), findsNothing);
  });
}
