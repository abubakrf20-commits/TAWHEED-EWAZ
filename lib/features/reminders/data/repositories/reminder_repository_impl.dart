import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/reminders/data/daos/reminder_dao.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/features/reminders/domain/repositories/reminder_repository.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepositoryImpl(ref.read(reminderDaoProvider));
});

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderDao _dao;
  ReminderRepositoryImpl(this._dao);

  ReminderModel _toModel(ReminderTableData row) {
    return ReminderModel(
      id: row.id,
      title: row.title,
      note: row.note,
      hour: row.hour,
      minute: row.minute,
      daysOfWeek: row.daysOfWeek.isEmpty
          ? []
          : (jsonDecode(row.daysOfWeek) as List<dynamic>)
              .map((e) => e as int)
              .toList(),
      isEnabled: row.isEnabled,
      createdAt: row.createdAt,
      advanceMinutes: row.advanceMinutes,
      useSound: row.useSound,
      updatedAt: row.updatedAt,
      soundName: row.soundName,
      specificDate: row.specificDate,
      prayerRef: row.prayerRef,
      prayerOffsetMinutes: row.prayerOffsetMinutes,
    );
  }

  ReminderTableCompanion _toCompanion(ReminderModel m) {
    return ReminderTableCompanion(
      id: Value(m.id),
      title: Value(m.title),
      note: Value(m.note),
      hour: Value(m.hour),
      minute: Value(m.minute),
      daysOfWeek: Value(jsonEncode(m.daysOfWeek)),
      isEnabled: Value(m.isEnabled),
      createdAt: Value(m.createdAt),
      advanceMinutes: Value(m.advanceMinutes),
      useSound: Value(m.useSound),
      updatedAt:
          m.updatedAt != null ? Value(m.updatedAt) : const Value.absent(),
      soundName: Value(m.soundName),
      specificDate:
          m.specificDate != null ? Value(m.specificDate) : const Value(null),
      prayerRef: m.prayerRef != null ? Value(m.prayerRef) : const Value(null),
      prayerOffsetMinutes: Value(m.prayerOffsetMinutes),
    );
  }

  @override
  Future<List<ReminderModel>> getAllReminders() async {
    final all = await _dao.getAllReminders();
    return all.map(_toModel).toList();
  }

  @override
  Future<ReminderModel?> getReminder(String id) async {
    final row = await _dao.getReminder(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> upsertReminder(ReminderModel reminder) =>
      _dao.upsertReminder(_toCompanion(reminder));

  @override
  Future<void> deleteReminder(String id) => _dao.deleteReminder(id);

  @override
  Future<void> clearAll() => _dao.clearAll();
}
