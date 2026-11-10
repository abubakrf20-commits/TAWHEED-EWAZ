import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tasks/data/daos/task_aux_dao.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:tawheeed/features/tasks/domain/repositories/task_repository.dart';
import 'package:tawheeed/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_tile.dart';

class MockTaskRepository implements TaskRepository {
  List<TaskModel> items = [];

  @override
  Future<List<TaskModel>> getAllTasks() async => List.of(items);

  @override
  Future<TaskModel?> getTask(String id) async {
    for (final t in items) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<void> saveTask(TaskModel task) async {
    items = [...items.where((t) => t.id != task.id), task];
  }

  @override
  Future<void> deleteTask(String id) async {
    items = items.where((t) => t.id != id).toList();
  }

  @override
  Future<void> clearCompleted() async {
    items = items.where((t) => !t.isCompleted).toList();
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      if (methodCall.method == 'setValue') {
        return true;
      }
      return null;
    },
  );

  Future<void> setPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  /// Small real-async delay that lets Drift's in-memory DB futures finish
  /// inside widget tests (which otherwise run on a fake-async clock).
  const ioFlush = Duration(milliseconds: 80);

  testWidgets('added task appears in the list', (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('هنوز کاری ثبت نشده'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'کار جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'مرور قرآن');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('مرور قرآن'), findsOneWidget);
    expect(find.text('هنوز کاری ثبت نشده'), findsNothing);
    expect(repo.items.length, 1);
    expect(repo.items.first.title, 'مرور قرآن');
  });

  testWidgets('tag filter keeps only tasks with the selected tag',
      (tester) async {
    // Tall viewport so every tile is built (the list is lazy otherwise).
    tester.view.physicalSize = const Size(1080, 3900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(
            id: '1',
            title: 'کار خانه',
            tags: const ['خانه'],
            createdAt: DateTime.now()),
        TaskModel(
            id: '2',
            title: 'کار اداری',
            tags: const ['اداره'],
            createdAt: DateTime.now()),
        TaskModel(id: '3', title: 'کار بی‌برچسب', createdAt: DateTime.now()),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tag row with both tags is shown.
    expect(find.text('همه برچسب‌ها'), findsOneWidget);

    // Tap the «خانه» tag chip (keyed, so it always hits the filter chip).
    await tester.tap(find.byKey(const ValueKey('tag_chip_خانه')));
    await tester.pumpAndSettle();

    // Only the tagged task remains in the list.
    expect(find.text('کار خانه'), findsOneWidget);
    expect(find.byType(TaskTile), findsOneWidget);
    expect(find.text('کار اداری'), findsNothing);
    expect(find.text('کار بی‌برچسب'), findsNothing);

    // Tap again to clear the tag filter → all tasks come back.
    await tester.tap(find.byKey(const ValueKey('tag_chip_خانه')));
    await tester.pumpAndSettle();
    expect(find.text('کار خانه'), findsOneWidget);
    expect(find.text('کار اداری'), findsOneWidget);
    expect(find.text('کار بی‌برچسب'), findsOneWidget);
  });

  testWidgets('group by tag shows per-tag headers grouping the tasks',
      (tester) async {
    // Tall viewport so every group header is built.
    tester.view.physicalSize = const Size(1080, 3900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(
            id: '1',
            title: 'کار خانه',
            tags: const ['خانه'],
            createdAt: DateTime.now()),
        TaskModel(
            id: '2',
            title: 'کار اداری',
            tags: const ['اداره'],
            createdAt: DateTime.now()),
        TaskModel(id: '3', title: 'کار بی‌برچسب', createdAt: DateTime.now()),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The group toggle sits at the end of the horizontal tag row.
    final toggle = find.byKey(const ValueKey('group_by_tag_toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // Every task is grouped under its tag, untagged ones under «بدون برچسب».
    expect(find.text('بدون برچسب'), findsOneWidget);
    expect(find.text('کار خانه'), findsOneWidget);
    expect(find.text('کار اداری'), findsOneWidget);
    expect(find.text('کار بی‌برچسب'), findsOneWidget);
  });

  testWidgets('persisted task loads back on rebuild', (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(id: '1', title: 'زیارت اهل قبور', createdAt: DateTime.now()),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('زیارت اهل قبور'), findsOneWidget);
  });

  testWidgets('overdue tasks get their own «تأخیر خورده» section',
      (tester) async {
    await setPhoneViewport(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(
            id: '1',
            title: 'کار دیرکرده',
            dueDate: today.subtract(const Duration(days: 2)),
            createdAt: now),
        TaskModel(
            id: '2',
            title: 'کار آینده',
            dueDate: today.add(const Duration(days: 1)),
            createdAt: now),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تأخیر خورده'), findsOneWidget);
    // «در انتظار» appears once as the summary stat and once as the section
    // header of the upcoming block.
    expect(find.text('در انتظار'), findsNWidgets(2));
    expect(find.text('کار دیرکرده'), findsOneWidget);
    expect(find.text('کار آینده'), findsOneWidget);
  });

  testWidgets('completing a daily task rolls it forward to tomorrow',
      (tester) async {
    await setPhoneViewport(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(
            id: '1',
            title: 'ذکر روزانه',
            isRecurring: true,
            recurringType: 'daily',
            dueDate: today,
            createdAt: now),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tile advertises the pattern.
    expect(find.text('تکرار روزانه'), findsOneWidget);

    await tester.tap(find.byType(TaskCheck));
    await tester.pumpAndSettle();

    // Still pending, but the due date advanced to tomorrow.
    final task = repo.items.single;
    expect(task.isCompleted, isFalse);
    expect(task.dueDate, today.add(const Duration(days: 1)));
    expect(task.completedAt, isNotNull); // last-completion stamp kept
    expect(find.text('تکرار روزانه'), findsOneWidget);
  });

  testWidgets('due-date reminder pill shows on a task with a reminder',
      (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(
            id: '1',
            title: 'پرداخت قسط',
            dueDate: DateTime.now().add(const Duration(days: 3)),
            remindEnabled: true,
            remindAt: '09:30',
            createdAt: DateTime.now()),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('یادآوری 09:30'), findsOneWidget);
  });

  testWidgets('dialog saves a recurring task with the chosen pattern',
      (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'کار جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'ذکر صبح');
    await tester.tap(find.text('روزانه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final task = repo.items.single;
    expect(task.title, 'ذکر صبح');
    expect(task.isRecurring, isTrue);
    expect(task.recurringType, 'daily');
  });

  testWidgets('the weekly stats card is gone from the screen', (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(id: '1', title: 'مرور روزانه', createdAt: DateTime.now()),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Removed per product decision — no weekly card, no caption anywhere.
    expect(find.text('آمار هفتگی'), findsNothing);
    expect(find.text('این هفته هنوز کاری تیک نخورده'), findsNothing);
  });

  testWidgets('deleting a task offers undo that restores it', (tester) async {
    await setPhoneViewport(tester);
    final repo = MockTaskRepository()
      ..items = [
        TaskModel(id: '1', title: 'کار آزمایشی', createdAt: DateTime.now()),
      ];
    // A real in-memory aux DB so the delete snapshot + undo restore run for
    // real instead of hanging on the platform database.
    final db = AppDatabase.withConnection(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          taskAuxDaoProvider.overrideWithValue(TaskAuxDao(db)),
        ],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('کار آزمایشی'), findsOneWidget);

    // Tile → dialog → delete button → confirm.
    await tester.tap(find.text('کار آزمایشی'));
    await tester.pumpAndSettle();
    // The delete button sits at the bottom of the (scrollable) sheet.
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    // The delete snapshot reads the (real-async) Drift DB — flush it so the
    // undo action has something to restore.
    await tester.runAsync(() => Future<void>.delayed(ioFlush));
    await tester.pumpAndSettle();

    expect(find.text('کار آزمایشی'), findsNothing);
    expect(repo.items, isEmpty);
    expect(find.text('کار حذف شد'), findsOneWidget);

    // Undo brings the task back (UI + repository).
    await tester.tap(find.text('بازگردانی'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(ioFlush));
    await tester.pumpAndSettle();
    expect(find.text('کار آزمایشی'), findsOneWidget);
    expect(repo.items, hasLength(1));
  });
}
