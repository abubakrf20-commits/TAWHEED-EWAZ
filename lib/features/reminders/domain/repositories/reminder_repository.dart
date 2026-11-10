import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';

abstract class ReminderRepository {
  Future<List<ReminderModel>> getAllReminders();
  Future<ReminderModel?> getReminder(String id);
  Future<void> upsertReminder(ReminderModel reminder);
  Future<void> deleteReminder(String id);
  Future<void> clearAll();
}
