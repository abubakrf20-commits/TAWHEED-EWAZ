import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_plan_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns default ReadingPlanState', () async {
    final state = await container.read(readingPlanProvider.future);
    expect(state.enabled, isFalse);
    expect(state.dailyTarget, equals(20));
    expect(state.pagesReadToday, equals(0));
    expect(state.reminderTime, equals(const TimeOfDay(hour: 8, minute: 0)));
    expect(state.books, isEmpty);
    expect(state.activeBookId, isNull);
  });

  test('progress returns 0 when no pages read', () async {
    final state = await container.read(readingPlanProvider.future);
    expect(state.progress, equals(0.0));
  });

  test('activeBook returns null when no active book set', () async {
    await container.read(readingPlanProvider.future);
    expect(
        container
            .read(readingPlanProvider.notifier)
            .state
            .requireValue
            .activeBook,
        isNull);
  });

  test('setEnabled toggles plan enabled', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.setEnabled(true);
    var state = container.read(readingPlanProvider).requireValue;
    expect(state.enabled, isTrue);
    await notifier.setEnabled(false);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.enabled, isFalse);
  });

  test('setDailyTarget updates daily target', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.setDailyTarget(50);
    final state = container.read(readingPlanProvider).requireValue;
    expect(state.dailyTarget, equals(50));
  });

  test('setReminderTime updates reminder time', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.setReminderTime(const TimeOfDay(hour: 21, minute: 30));
    final state = container.read(readingPlanProvider).requireValue;
    expect(state.reminderTime.hour, equals(21));
    expect(state.reminderTime.minute, equals(30));
  });

  test('addBook adds a book to the plan', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Test Book',
        dailyTarget: 10, totalPages: 200, partInfo: 'Part 1');
    final state = container.read(readingPlanProvider).requireValue;
    expect(state.books.length, equals(1));
    expect(state.books[0].name, equals('Test Book'));
    expect(state.books[0].dailyTarget, equals(10));
    expect(state.books[0].totalPages, equals(200));
    expect(state.books[0].partInfo, equals('Part 1'));
  });

  test('removeBook removes a book from the plan', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Book A');
    var state = container.read(readingPlanProvider).requireValue;
    final idA = state.books[0].id;
    await notifier.addBook('Book B');
    state = container.read(readingPlanProvider).requireValue;
    expect(state.books.length, equals(2));
    final idB = state.books[1].id;
    expect(idA, isNot(equals(idB)));
    await notifier.removeBook(idA);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.books.length, equals(1));
    expect(state.books[0].id, equals(idB));
  });

  test('setActiveBook sets the active book', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Book');
    var state = container.read(readingPlanProvider).requireValue;
    final id = state.books[0].id;
    await notifier.setActiveBook(id);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.activeBookId, equals(id));
    expect(state.activeBook, isNotNull);
  });

  test('updateBook modifies book fields', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Original');
    var state = container.read(readingPlanProvider).requireValue;
    final id = state.books[0].id;
    await notifier.updateBook(id,
        name: 'Updated', dailyTarget: 30, totalPages: 500);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.books[0].name, equals('Updated'));
    expect(state.books[0].dailyTarget, equals(30));
    expect(state.books[0].totalPages, equals(500));
  });

  test('logPages updates pages read today and book progress', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Book', totalPages: 200);
    var state = container.read(readingPlanProvider).requireValue;
    final id = state.books[0].id;
    await notifier.logPages(id, 10);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.pagesReadToday, equals(10));
    expect(state.books[0].currentPage, equals(10));
  });

  test('resetToday resets pages read to 0', () async {
    await container.read(readingPlanProvider.future);
    final notifier = container.read(readingPlanProvider.notifier);
    await notifier.addBook('Book', totalPages: 200);
    var state = container.read(readingPlanProvider).requireValue;
    final id = state.books[0].id;
    await notifier.logPages(id, 15);
    state = container.read(readingPlanProvider).requireValue;
    expect(state.pagesReadToday, equals(15));
    await notifier.resetToday();
    state = container.read(readingPlanProvider).requireValue;
    expect(state.pagesReadToday, equals(0));
  });
}
