import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/reminders/data/daos/reminder_dao.dart';
import 'package:tawheeed/features/reminders/presentation/providers/reminder_provider.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  group('prayerFireMinutes', () {
    test('adds the offset to the prayer time', () {
      expect(prayerFireMinutes(hour: 12, minute: 30, offsetMinutes: -15), 735);
      expect(prayerFireMinutes(hour: 12, minute: 30, offsetMinutes: 30), 780);
      expect(prayerFireMinutes(hour: 12, minute: 30, offsetMinutes: 0), 750);
    });

    test('an hour-crossing negative offset stays exact (old 1-hour bug)', () {
      // fajr 05:10 − 15 min = 04:55. The previous
      // `hour + (minute + offset) ~/ 60` arithmetic truncated toward zero and
      // produced 05:50 — a full hour late.
      expect(prayerFireMinutes(hour: 5, minute: 10, offsetMinutes: -15), 295);
    });

    test('stays negative before midnight so the anchor reaches yesterday', () {
      expect(prayerFireMinutes(hour: 0, minute: 10, offsetMinutes: -15), -5);
    });
    test('anchoring on local midnight rolls hour and day boundaries', () {
      final midnight = tz.TZDateTime(tz.UTC, 2026, 9, 25);

      // fajr 05:10 − 15 → 04:55 the SAME day. This is the case the old
      // hour/minute arithmetic got wrong (it produced 05:50).
      final beforeDawn = midnight.add(Duration(
          minutes: prayerFireMinutes(hour: 5, minute: 10, offsetMinutes: -15)));
      expect(beforeDawn.day, 25);
      expect('${beforeDawn.hour}:${beforeDawn.minute}', '4:55');

      // A result before midnight reaches into yesterday exactly.
      final yesterday = midnight.add(Duration(
          minutes: prayerFireMinutes(hour: 0, minute: 10, offsetMinutes: -15)));
      expect(yesterday.day, 24);
      expect('${yesterday.hour}:${yesterday.minute}', '23:55');

      // Beyond 24h rolls forward.
      final pastMidnight = midnight.add(Duration(
          minutes: prayerFireMinutes(hour: 0, minute: 5, offsetMinutes: 1440)));
      expect(pastMidnight.day, 26);
      expect(pastMidnight.hour, 0);
    });
  });

  late ProviderContainer container;
  late MockReminderDao mockDao;

  setUp(() {
    mockDao = MockReminderDao();
    container = ProviderContainer(overrides: [
      reminderDaoProvider.overrideWithValue(mockDao),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns empty list when DAO has no reminders', () async {
    final reminders = await container.read(reminderProvider.future);
    expect(reminders, isEmpty);
  });

  test('build returns reminders sorted by time', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'Late',
      note: '',
      hour: 14,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await mockDao.upsertReminder(ReminderTableData(
      id: '2',
      title: 'Early',
      note: '',
      hour: 8,
      minute: 30,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    final reminders = await container.read(reminderProvider.future);
    expect(reminders.length, equals(2));
    expect(reminders[0].title, equals('Early'));
    expect(reminders[1].title, equals('Late'));
  });

  test('reminders getter returns current list', () async {
    await container.read(reminderProvider.future);
    final provider = container.read(reminderProvider.notifier);
    expect(provider.reminders, isEmpty);
  });

  test('enabledReminders returns only enabled ones', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'Enabled',
      note: '',
      hour: 10,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await mockDao.upsertReminder(ReminderTableData(
      id: '2',
      title: 'Disabled',
      note: '',
      hour: 11,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: false,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await container.read(reminderProvider.future);
    final provider = container.read(reminderProvider.notifier);
    expect(provider.enabledReminders.length, equals(1));
    expect(provider.enabledReminders[0].title, equals('Enabled'));
  });

  test('addReminder creates a new reminder in DAO', () async {
    await container.read(reminderProvider.future);
    final notifier = container.read(reminderProvider.notifier);
    await notifier.addReminder(
      title: 'Test Reminder',
      note: 'Test note',
      hour: 9,
      minute: 0,
      daysOfWeek: [1, 2, 3],
    );
    final reminders = await container.read(reminderProvider.future);
    expect(reminders.length, equals(1));
    expect(reminders[0].title, equals('Test Reminder'));
    expect(reminders[0].note, equals('Test note'));
    expect(reminders[0].hour, equals(9));
    expect(reminders[0].daysOfWeek, equals([1, 2, 3]));
  });

  test('updateReminder modifies an existing reminder', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'Original',
      note: '',
      hour: 10,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await container.read(reminderProvider.future);
    final notifier = container.read(reminderProvider.notifier);
    final original = container.read(reminderProvider).requireValue.first;
    await notifier
        .updateReminder(original.copyWith(title: 'Updated', hour: 12));
    final reminders = await container.read(reminderProvider.future);
    expect(reminders[0].title, equals('Updated'));
    expect(reminders[0].hour, equals(12));
  });

  test('deleteReminder removes a reminder from DAO', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'Delete Me',
      note: '',
      hour: 10,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await container.read(reminderProvider.future);
    final notifier = container.read(reminderProvider.notifier);
    await notifier.deleteReminder('1');
    final reminders = await container.read(reminderProvider.future);
    expect(reminders, isEmpty);
  });

  test('toggleEnabled flips isEnabled', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'Toggle Test',
      note: '',
      hour: 10,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await container.read(reminderProvider.future);
    final notifier = container.read(reminderProvider.notifier);
    await notifier.toggleEnabled('1');
    var stored = await mockDao.getReminder('1');
    expect(stored!.isEnabled, isFalse);
    await notifier.toggleEnabled('1');
    stored = await mockDao.getReminder('1');
    expect(stored!.isEnabled, isTrue);
  });

  test('clearAll removes all reminders', () async {
    await mockDao.upsertReminder(ReminderTableData(
      id: '1',
      title: 'A',
      note: '',
      hour: 10,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await mockDao.upsertReminder(ReminderTableData(
      id: '2',
      title: 'B',
      note: '',
      hour: 11,
      minute: 0,
      daysOfWeek: '[]',
      isEnabled: true,
      createdAt: DateTime.now(),
      advanceMinutes: 0,
      useSound: false,
      soundName: 'default',
      prayerOffsetMinutes: 0,
    ));
    await container.read(reminderProvider.future);
    final notifier = container.read(reminderProvider.notifier);
    await notifier.clearAll();
    final reminders = await container.read(reminderProvider.future);
    expect(reminders, isEmpty);
  });
}
