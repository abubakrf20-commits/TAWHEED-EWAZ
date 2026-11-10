import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/services/notification_ids.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One computed reminder request.
class ShopReminder {
  const ShopReminder({
    required this.key,
    required this.title,
    required this.body,
    required this.when,
  });

  final String key;
  final String title;
  final String body;
  final DateTime when;
}

/// The shop tool's reminder scheduling — stage-3's deferred hook, now wired.
///
/// Pure computation ([compute]) is unit-tested; [rearm] is the single entry
/// point the UI calls (shop settings save, More sheet open) and it is LAZY:
/// nothing here runs at app start. Default OFF via the settings row, per the
/// brief.
///
/// ID range: shop owns **16000 + stableSlot(key, 999)** → 16000..16998, the
/// summary sits at 16999. Clear of kids (14000) and teacher (15000); the
/// slot space is one short of the range so no reminder can land on the
/// summary id (the same collision rule SoftNotifier pins).
class ShopReminders {
  ShopReminders._();

  static const int base = 16000;
  static const int space = 1000;
  static const int summaryId = 16999;
  static const String tool = 'shop';

  static int idFor(String key) =>
      base + NotificationIds.stableSlot(key, space - 1);

  /// Computes the reminder set from the shop's live data.
  ///
  /// Cheques: 7 / 3 / 0 days before the due date (both directions).
  /// Recurring expenses: on the rule's Jalali day, once per period.
  static List<ShopReminder> compute({
    required bool remindersEnabled,
    required List<ShopCheque> cheques,
    required List<
            ({
              String id,
              int dayOfMonth,
              int amount,
              bool active,
              String lastRemindedKey
            })>
        recurringRules,
    required DateTime now,
  }) {
    if (!remindersEnabled) return const [];
    // The reminders carry amounts, so they follow the one currency setting and
    // the app's thousands separators (they used to print «1250000 تومان»).
    final unit = CurrencyStore.shared.current.unit;
    final out = <ShopReminder>[];

    // Cheques: 7/3/0 days before due, both directions.
    for (final c in cheques) {
      if (!c.inFlight) continue;
      for (final lead in const [7, 3, 0]) {
        final fire = DateTime(
          c.dueDate.year,
          c.dueDate.month,
          c.dueDate.day,
        ).subtract(Duration(days: lead));
        if (!fire.isAfter(now)) continue;
        out.add(ShopReminder(
          key: 'cheque_${c.id}_$lead',
          title: c.direction == ChequeDirection.received
              ? 'چک دریافتی نزدیک سررسید'
              : 'چک صادره نزدیک سررسید',
          body: 'چک ${c.number.isEmpty ? 'بدون شماره' : c.number} مبلغ '
              '${NumberFormat.grouped(c.amount)} $unit — '
              '${lead == 0 ? 'امروز' : '$lead روز دیگر'}',
          when: fire,
        ));
      }
    }

    // Recurring expenses: due today (month-end-safe), once per period.
    for (final rule in recurringRules) {
      if (!rule.active) continue;
      if (!shouldRemindRecurring(
        dayOfMonth: rule.dayOfMonth,
        now: now,
        lastRemindedKey: rule.lastRemindedKey,
      )) {
        continue;
      }
      final occurrence =
          nextRecurringOccurrence(dayOfMonth: rule.dayOfMonth, now: now);
      out.add(ShopReminder(
        key: 'recurring_${rule.id}_${recurringPeriodKey(occurrence)}',
        title: 'هزینهٔ تکراری',
        body: 'زمان ثبت هزینهٔ ماهانه '
            '(${NumberFormat.grouped(rule.amount)} $unit) رسیده است؛ '
            'از بخش هزینه‌ها با یک لمس ثبت کنید.',
        when: DateTime(occurrence.year, occurrence.month, occurrence.day, 9),
      ));
    }

    return out;
  }

  /// Schedules the computed reminders through SoftNotifier (quiet hours and
  /// the daily cap apply inside). Cancel-all first so a re-arm never leaves
  /// a stale alarm behind. Returns how many were scheduled.
  /// Takes the DAOs directly — callers have `ref.read` already, and this
  /// stays usable from a widget, a Notifier, or a test without riverpod
  /// plumbing.
  static Future<int> rearm({
    required ShopDao shopDao,
    required Shop3Dao shop3Dao,
  }) async {
    try {
      final settings = await shopDao.settings();
      final notifier = SoftNotifier();

      await notifier.cancelAll();
      if (!settings.remindersEnabled) return 0;

      final cheques = await shop3Dao.cheques(onlyInFlight: true);
      final ruleRows = await shop3Dao.db
          .customSelect(
            'SELECT id, day_of_month, amount, active, last_reminded_key FROM '
            'p2_shop_recurring_expense WHERE active = 1',
          )
          .get();
      final rules = [
        for (final r in ruleRows)
          (
            id: r.read<String>('id'),
            dayOfMonth: r.read<int>('day_of_month'),
            amount: r.read<int>('amount'),
            active: r.read<int>('active') == 1,
            lastRemindedKey: r.read<String>('last_reminded_key'),
          ),
      ];

      final reminders = compute(
        remindersEnabled: settings.remindersEnabled,
        cheques: cheques,
        recurringRules: rules,
        now: DateTime.now(),
      );

      var scheduled = 0;
      for (final reminder in reminders) {
        final ok = await notifier.schedule(
          tool: tool,
          key: reminder.key,
          title: reminder.title,
          body: reminder.body,
          when: reminder.when,
          quietStartMinutes: settings.quietStartMinutes,
          quietEndMinutes: settings.quietEndMinutes,
        );
        if (ok) scheduled++;
      }
      return scheduled;
    } catch (e) {
      AppLogger.warning('ShopReminders', 'rearm failed: $e');
      return 0;
    }
  }
}
