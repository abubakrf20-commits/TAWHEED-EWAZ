import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/personal/family_faith/family_faith_schedulers.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_scheduler.dart';
import 'package:tawheeed/features/personal/services/care_reminder_scheduler.dart';
import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_reminders.dart';

/// The personal tools share ONE notification service, so their id blocks have
/// to be disjoint. They were not: «دفتر مالی» used 14000+ (the kids block),
/// «صله رحم» 15000+ (the teacher block), and «قضایار»/«قلک» 16000+ (the shop
/// block), so scheduling one tool's nudge silently replaced another tool's —
/// the victim only came back on its own next sync, which for a weekly savings
/// nudge is a week. Every number in the map below is read from the scheduler
/// that owns it, so changing a base without moving the block fails here.
void main() {
  /// Every personal-tools block, inclusive on both ends.
  final blocks = <String, ({int start, int end})>{
    // care: 13000 + day-of-year, plus 13000+998 for the grouped/overdue one.
    'خودرو/خانه': (
      start: CareReminderScheduler.idBase,
      end: CareReminderScheduler.idBase + 998,
    ),
    // kids: 14000 + slot(space 1000), summary 14999.
    'دفتر کودک': (
      start: SoftNotifier.kidsBase,
      end: SoftNotifier.kidsSummaryId,
    ),
    // teacher: 15000 + slot(space 1000), summary 15999.
    'دفتر مربی': (
      start: SoftNotifier.teacherBase,
      end: SoftNotifier.teacherSummaryId,
    ),
    // shop: 16000 + slot(space 1000), summary 16999.
    'حساب مغازه': (start: ShopReminders.base, end: ShopReminders.summaryId),
    // finance: 17000 + day-of-year.
    'دفتر مالی': (
      start: FinanceReminderScheduler.idBase,
      end: FinanceReminderScheduler.idBase + 366,
    ),
    // relatives: 17400 + day-of-year.
    'صله رحم': (
      start: FamilyReminderScheduler.idBase,
      end: FamilyReminderScheduler.idBase + 366,
    ),
    // savings: 17900 + stableSlot(goalId, 99).
    'قلک': (
      start: SavingsReminderScheduler.idBase,
      end: SavingsReminderScheduler.idBase +
          SavingsReminderScheduler.slotSpace -
          1,
    ),
  };

  /// The id windows the rest of the app already owns (`NotificationIds`).
  const appRanges = <String, (int, int)>{
    'adhan/azkar': (100, 199),
    'day-after-tomorrow': (210, 229),
    'post-prayer azkar': (300, 309),
    'daily content': (400, 432),
    'pre-adhan': (500, 524),
    'period': (600, 619),
    'custom reminders': (1000, 1999),
    'daily content per day': (7000, 8666),
    'pomodoro': (7843, 7843),
    'tasks': (10000, 10999),
    'goals': (12000, 12949),
  };

  test('no two personal tools share a notification id', () {
    final names = blocks.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = blocks[names[i]]!;
        final b = blocks[names[j]]!;
        final disjoint = a.end < b.start || b.end < a.start;
        expect(disjoint, isTrue,
            reason: '${names[i]} ${a.start}-${a.end} overlaps '
                '${names[j]} ${b.start}-${b.end}');
      }
    }
  });

  test('the personal blocks start above every block the app already owns', () {
    for (final entry in blocks.entries) {
      for (final app in appRanges.entries) {
        final (start, end) = app.value;
        final overlaps = entry.value.start <= end && start <= entry.value.end;
        expect(overlaps, isFalse,
            reason: '${entry.key} hits ${app.key} ($start-$end)');
      }
    }
  });

  test('every day-of-year id stays inside its own block', () {
    // Leap years reach 366; a base + day-of-year must never leave the block.
    for (var dayOfYear = 1; dayOfYear <= 366; dayOfYear++) {
      final careId = CareReminderScheduler.idBase + dayOfYear;
      expect(careId, inInclusiveRange(
          blocks['خودرو/خانه']!.start, blocks['خودرو/خانه']!.end));
      final financeId = FinanceReminderScheduler.idBase + dayOfYear;
      expect(financeId,
          inInclusiveRange(blocks['دفتر مالی']!.start, blocks['دفتر مالی']!.end));
      final relativeId = FamilyReminderScheduler.idBase + dayOfYear;
      expect(relativeId,
          inInclusiveRange(blocks['صله رحم']!.start, blocks['صله رحم']!.end));
    }
  });

  test('the savings slot space really resolves inside the block', () {
    for (var slot = 0; slot < SavingsReminderScheduler.slotSpace; slot++) {
      final id = SavingsReminderScheduler.idBase + slot;
      expect(id, inInclusiveRange(blocks['قلک']!.start, blocks['قلک']!.end));
    }
  });
}
