import 'package:drift/drift.dart' hide Column;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/services/expiry_reminder_scheduler.dart';

/// Keeps the «تاریخ‌های مهم» dashboard in sync with insurance policies that
/// carry an end date.
///
/// Every policy is linked to at most one expiry item whose id is derived from
/// the insurance id (`insurance_<id>`), so saving, editing or deleting a
/// policy creates/updates/removes the countdown without a schema change.
class InsuranceExpirySync {
  InsuranceExpirySync._();

  /// Category used by the linked expiry items; the expiry screens already map
  /// this to the generic warning icon.
  static const String category = 'expiry_warning';

  /// Deterministic id of the expiry item that mirrors [insuranceId].
  static String expiryItemId(String insuranceId) => 'insurance_$insuranceId';

  /// Mirrors a policy into «تاریخ‌های مهم». When [expiryDate] is empty the
  /// linked item (if any) is removed. Never throws.
  static Future<void> sync({
    required PersonalInfoRepository repo,
    required String insuranceId,
    required String title,
    required String expiryDate,
  }) async {
    final linkedId = expiryItemId(insuranceId);
    final existing = await repo.getExpiryItem(linkedId);
    final due = expiryDate.trim();
    if (due.isEmpty) {
      if (existing != null) {
        await repo.deleteExpiryItem(linkedId);
        await ExpiryReminderScheduler.cancelFor(linkedId);
      }
      return;
    }
    final now = DateTime.now();
    await repo.upsertExpiryItem(ExpiryItemTableCompanion(
      id: Value(linkedId),
      category: const Value(category),
      title: Value('انقضای بیمه: $title'),
      startDate: Value(existing?.startDate ?? ''),
      dueDate: Value(due),
      notes: Value(existing?.notes ?? ''),
      remindEnabled: Value(existing?.remindEnabled ?? false),
      remindDaysBefore: Value(existing?.remindDaysBefore ?? 0),
      lastRemindedDate: Value(existing?.lastRemindedDate ?? ''),
      isArchived: Value(existing?.isArchived ?? false),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    ));
    final saved = await repo.getExpiryItem(linkedId);
    if (saved != null) await ExpiryReminderScheduler.syncFor(saved);
  }

  /// Removes the linked expiry item, e.g. when a policy is deleted. Never
  /// throws.
  static Future<void> remove(
      PersonalInfoRepository repo, String insuranceId) async {
    final linkedId = expiryItemId(insuranceId);
    final existing = await repo.getExpiryItem(linkedId);
    if (existing == null) return;
    await repo.deleteExpiryItem(linkedId);
    await ExpiryReminderScheduler.cancelFor(linkedId);
  }
}
