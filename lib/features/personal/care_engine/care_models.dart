/// Care-engine entities — pure Dart (no Flutter, no Drift, no `dart:io`).
///
/// The engine is shared by «خودرو» and «خانه» today and by later personal
/// tools tomorrow, so it must stay platform-neutral: an iOS build later reads
/// the same rows through the same models.
library;

/// Which tool owns an asset.
enum CareAssetKind {
  car('car'),
  home('home');

  const CareAssetKind(this.key);
  final String key;

  static CareAssetKind fromKey(String value) => CareAssetKind.values.firstWhere(
        (k) => k.key == value,
        orElse: () => CareAssetKind.car,
      );
}

/// How a task's due moment is measured.
enum CareScheduleType {
  time('time'),
  distance('distance'),
  both('both');

  const CareScheduleType(this.key);
  final String key;

  static CareScheduleType fromKey(String value) =>
      CareScheduleType.values.firstWhere(
        (t) => t.key == value,
        orElse: () => CareScheduleType.time,
      );

  bool get usesTime => this == CareScheduleType.time || this == CareScheduleType.both;
  bool get usesDistance =>
      this == CareScheduleType.distance || this == CareScheduleType.both;
}

/// Status band of a care task. Thresholds are fixed by the spec:
/// good < 0.65, near 0.65–0.9, urgent 0.9–1.0, overdue > 1.0.
enum CareStatusLevel {
  good('good'),
  near('near'),
  urgent('urgent'),
  overdue('overdue');

  const CareStatusLevel(this.key);
  final String key;
}

/// Bill recurrence. `custom` means “every [Bill.customDays] days”.
enum BillRecurrence {
  monthly('monthly'),
  bimonthly('bimonthly'),
  custom('custom');

  const BillRecurrence(this.key);
  final String key;

  static BillRecurrence fromKey(String value) =>
      BillRecurrence.values.firstWhere(
        (r) => r.key == value,
        orElse: () => BillRecurrence.monthly,
      );
}

/// Subscription billing period.
enum SubscriptionPeriod {
  monthly('monthly'),
  yearly('yearly');

  const SubscriptionPeriod(this.key);
  final String key;

  static SubscriptionPeriod fromKey(String value) =>
      SubscriptionPeriod.values.firstWhere(
        (p) => p.key == value,
        orElse: () => SubscriptionPeriod.monthly,
      );
}

/// A Jalali month-day window (seasonal work, e.g. «قبل از آبان»).
class CareWindow {
  const CareWindow({
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });

  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  Map<String, dynamic> toJson() => {
        'startMonth': startMonth,
        'startDay': startDay,
        'endMonth': endMonth,
        'endDay': endDay,
      };

  static CareWindow? fromJson(Object? value) {
    if (value is! Map) return null;
    int read(String key, int fallback) {
      final v = value[key];
      return v is int ? v : (v is num ? v.toInt() : fallback);
    }

    final w = CareWindow(
      startMonth: read('startMonth', 1),
      startDay: read('startDay', 1),
      endMonth: read('endMonth', 1),
      endDay: read('endDay', 1),
    );
    if (w.startMonth < 1 || w.startMonth > 12) return null;
    if (w.endMonth < 1 || w.endMonth > 12) return null;
    return w;
  }
}

/// A car or a home.
class CareAsset {
  const CareAsset({
    required this.id,
    required this.kind,
    required this.name,
    required this.meta,
    required this.createdAt,
    this.archived = false,
  });

  final String id;
  final CareAssetKind kind;
  final String name;

  /// Kind-specific fields: car `make/model/color/plate/fuelType`, home
  /// `nickname`. JSON keeps the schema open without a migration per field.
  final Map<String, dynamic> meta;
  final DateTime createdAt;
  final bool archived;

  String metaText(String key, {String fallback = ''}) {
    final value = meta[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  /// «پژو 206 · سفید» — the header's display name.
  String get displayName {
    if (kind != CareAssetKind.car) return name;
    final make = metaText('make');
    final model = metaText('model');
    final color = metaText('color');
    final base = [make, model].where((s) => s.isNotEmpty).join(' ');
    final title = base.isEmpty ? name : base;
    return color.isEmpty ? title : '$title · $color';
  }

  String get plate => metaText('plate');

  CareAsset copyWith({
    String? name,
    Map<String, dynamic>? meta,
    bool? archived,
  }) =>
      CareAsset(
        id: id,
        kind: kind,
        name: name ?? this.name,
        meta: meta ?? this.meta,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );
}

/// One recurring piece of upkeep on an asset.
class CareTask {
  const CareTask({
    required this.id,
    required this.assetId,
    required this.title,
    required this.categoryKey,
    required this.iconKey,
    required this.scheduleType,
    required this.createdAt,
    this.templateKey = '',
    this.intervalDays,
    this.intervalKm,
    this.window,
    this.lastDoneDate,
    this.lastDoneKm,
    this.firstDueDate,
    this.firstDueKm,
    this.remindBeforeDays = 7,
    this.remindBeforeKm = 500,
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String assetId;
  final String title;

  /// Template key (`engine_oil`, `boiler_service`, …) or `''` for a custom
  /// task. Used to dedupe a season pack.
  final String templateKey;
  final String categoryKey;
  final String iconKey;
  final CareScheduleType scheduleType;
  final int? intervalDays;
  final int? intervalKm;
  final CareWindow? window;
  final DateTime? lastDoneDate;
  final int? lastDoneKm;
  final DateTime? firstDueDate;
  final int? firstDueKm;
  final int remindBeforeDays;
  final int remindBeforeKm;
  final String notes;
  final bool active;
  final DateTime createdAt;

  bool get isSeasonal => window != null;

  CareTask copyWith({
    String? title,
    String? iconKey,
    CareScheduleType? scheduleType,
    int? intervalDays,
    bool clearIntervalDays = false,
    int? intervalKm,
    bool clearIntervalKm = false,
    CareWindow? window,
    bool clearWindow = false,
    DateTime? lastDoneDate,
    int? lastDoneKm,
    DateTime? firstDueDate,
    int? firstDueKm,
    int? remindBeforeDays,
    int? remindBeforeKm,
    String? notes,
    bool? active,
  }) =>
      CareTask(
        id: id,
        assetId: assetId,
        title: title ?? this.title,
        templateKey: templateKey,
        categoryKey: categoryKey,
        iconKey: iconKey ?? this.iconKey,
        scheduleType: scheduleType ?? this.scheduleType,
        intervalDays:
            clearIntervalDays ? null : (intervalDays ?? this.intervalDays),
        intervalKm: clearIntervalKm ? null : (intervalKm ?? this.intervalKm),
        window: clearWindow ? null : (window ?? this.window),
        lastDoneDate: lastDoneDate ?? this.lastDoneDate,
        lastDoneKm: lastDoneKm ?? this.lastDoneKm,
        firstDueDate: firstDueDate ?? this.firstDueDate,
        firstDueKm: firstDueKm ?? this.firstDueKm,
        remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
        remindBeforeKm: remindBeforeKm ?? this.remindBeforeKm,
        notes: notes ?? this.notes,
        active: active ?? this.active,
        createdAt: createdAt,
      );
}

/// A completed service / expense record.
class CareRecord {
  const CareRecord({
    required this.id,
    required this.assetId,
    required this.date,
    this.taskId,
    this.title = '',
    this.odometerKm,
    this.cost,
    this.note = '',
    this.attachmentPaths = const [],
  });

  final String id;
  final String assetId;
  final String? taskId;

  /// Snapshot of the task title at completion time, so history stays readable
  /// after the task is renamed or deleted.
  final String title;
  final DateTime date;
  final int? odometerKm;
  final double? cost;
  final String note;
  final List<String> attachmentPaths;
}

/// A point-in-time odometer reading.
class OdometerReading {
  const OdometerReading({
    required this.id,
    required this.assetId,
    required this.date,
    required this.km,
  });

  final String id;
  final String assetId;
  final DateTime date;
  final int km;
}

/// One fuel fill-up.
class FuelLog {
  const FuelLog({
    required this.id,
    required this.assetId,
    required this.date,
    required this.liters,
    required this.odometerKm,
    this.pricePerLiter,
    this.totalCost,
    this.fullTank = true,
  });

  final String id;
  final String assetId;
  final DateTime date;
  final double liters;
  final double? pricePerLiter;
  final double? totalCost;
  final int odometerKm;
  final bool fullTank;

  double get cost => totalCost ?? (pricePerLiter ?? 0) * liters;
}

/// A recurring household bill.
class Bill {
  const Bill({
    required this.id,
    required this.assetId,
    required this.type,
    required this.title,
    required this.recurrence,
    required this.dueDay,
    required this.createdAt,
    this.customDays,
    this.firstDueDate,
    this.expectedAmount,
    this.active = true,
    this.attachmentPaths = const [],
  });

  final String id;
  final String assetId;

  /// `electricity | water | gas | phone | internet | building | other`.
  final String type;
  final String title;
  final BillRecurrence recurrence;

  /// Day of the Jalali month (1–31, clamped to the month length).
  final int dueDay;

  /// Only for [BillRecurrence.custom].
  final int? customDays;

  /// Anchor for custom/bimonthly periods, and the first due date.
  final DateTime? firstDueDate;
  final double? expectedAmount;
  final bool active;
  final DateTime createdAt;

  /// Receipt / invoice photo paths stored by `CareAttachmentStore`.
  final List<String> attachmentPaths;
}

/// A payment for one bill period.
class BillPayment {
  const BillPayment({
    required this.id,
    required this.billId,
    required this.periodKey,
    required this.paidDate,
    this.amount,
    this.note = '',
  });

  final String id;
  final String billId;

  /// Stable per-period key (`1404-07`, `1404-07/08`, `every-21/…)`.
  final String periodKey;
  final DateTime paidDate;
  final double? amount;
  final String note;
}

/// A warranty with a computed, editable expiry.
class Warranty {
  const Warranty({
    required this.id,
    required this.assetId,
    required this.itemName,
    required this.purchaseDate,
    required this.months,
    required this.expiryDate,
    this.store = '',
    this.serial = '',
    this.receiptPaths = const [],
    this.notes = '',
  });

  final String id;
  final String assetId;
  final String itemName;
  final String store;
  final String serial;
  final DateTime purchaseDate;
  final int months;
  final DateTime expiryDate;
  final List<String> receiptPaths;
  final String notes;
}

/// A recurring paid subscription.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.period,
    required this.nextChargeDate,
    this.category = '',
    this.active = true,
  });

  final String id;
  final String name;
  final double amount;
  final SubscriptionPeriod period;
  final DateTime nextChargeDate;
  final String category;
  final bool active;

  double get monthlyAmount =>
      period == SubscriptionPeriod.yearly ? amount / 12 : amount;
}

/// One recurring habit for a child.
class CareHabit {
  const CareHabit({
    required this.id,
    required this.kidId,
    required this.title,
    required this.iconKey,
    required this.colorHex,
    required this.targetCount,
    this.unit = '',
    this.startDate,
    this.endDate,
    this.createdAt,
    this.active = true,
  });

  final String id;
  final String kidId;
  final String title;
  final String iconKey;
  final String colorHex;
  final int targetCount;
  final String unit;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final bool active;

  CareHabit copyWith({
    String? id,
    String? kidId,
    String? title,
    String? iconKey,
    String? colorHex,
    int? targetCount,
    String? unit,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    bool? active,
  }) =>
      CareHabit(
        id: id ?? this.id,
        kidId: kidId ?? this.kidId,
        title: title ?? this.title,
        iconKey: iconKey ?? this.iconKey,
        colorHex: colorHex ?? this.colorHex,
        targetCount: targetCount ?? this.targetCount,
        unit: unit ?? this.unit,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        createdAt: createdAt ?? this.createdAt,
        active: active ?? this.active,
      );
}

/// One completion record for a habit on a given date.
class CareHabitCompletion {
  const CareHabitCompletion({
    required this.id,
    required this.habitId,
    required this.date,
    this.count = 1,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String habitId;
  final DateTime date;
  final int count;
  final String notes;
  final DateTime? createdAt;

  CareHabitCompletion copyWith({
    String? id,
    String? habitId,
    DateTime? date,
    int? count,
    String? notes,
    DateTime? createdAt,
  }) =>
      CareHabitCompletion(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        date: date ?? this.date,
        count: count ?? this.count,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// One reward that can be claimed with points.
class CareReward {
  const CareReward({
    required this.id,
    required this.kidId,
    required this.title,
    required this.iconKey,
    required this.costPoints,
    this.description = '',
    this.redeemedAt,
  });

  final String id;
  final String kidId;
  final String title;
  final String iconKey;
  final int costPoints;
  final String description;
  final DateTime? redeemedAt;
}

/// Everything the kid-habit screen needs, loaded in one pass.
class CareHabitSnapshot {
  const CareHabitSnapshot({
    this.habits = const [],
    this.completions = const [],
    this.rewards = const [],
  });

  final List<CareHabit> habits;
  final List<CareHabitCompletion> completions;
  final List<CareReward> rewards;

  List<CareHabit> habitsOf(String kidId) =>
      habits.where((h) => h.kidId == kidId && h.active).toList();

  List<CareHabitCompletion> completionsOf(String habitId) =>
      completions.where((c) => c.habitId == habitId).toList();

  List<CareReward> rewardsOf(String kidId) =>
      rewards.where((r) => r.kidId == kidId && r.redeemedAt == null).toList();

  List<CareReward> redeemedRewardsOf(String kidId) =>
      rewards.where((r) => r.kidId == kidId && r.redeemedAt != null).toList();
}

/// Everything the child dashboard needs, loaded in one pass.
class KidSnapshot {
  const KidSnapshot({
    required this.kidId,
    required this.kidName,
    required this.kidAvatar,
    required this.totalPoints,
    this.habits = const [],
  });

  final String kidId;
  final String kidName;
  final String kidAvatar;
  final int totalPoints;
  final List<CareHabit> habits;

  int get totalTargets => habits.fold(0, (s, h) => s + h.targetCount);
}

/// Computed progress for one habit on a given date range.
class CareHabitStatus {
  const CareHabitStatus({
    required this.habit,
    required this.totalDone,
    required this.streakDays,
    required this.progress,
    required this.lastDoneDate,
  });

  final CareHabit habit;
  final int totalDone;
  final int streakDays;
  final double progress;
  final DateTime? lastDoneDate;

  bool get isComplete => progress >= 1.0;
}

/// Computes streak length (consecutive days ending at [now]).
int computeStreakDays(List<DateTime> dates, DateTime now) {
  if (dates.isEmpty) return 0;
  final sorted = List<DateTime>.from(dates)..sort((a, b) => b.compareTo(a));
  int streak = 0;
  DateTime? expected;
  for (final d in sorted) {
    final day = DateTime(d.year, d.month, d.day);
    if (expected == null || day == expected) {
      streak++;
      expected = day.subtract(const Duration(days: 1));
    } else if (day.isAfter(expected)) {
      // gap: reset
      break;
    }
  }
  return streak;
}

/// Computes progress (0..1) for a habit based on completions up to [now].
double computeProgress(List<CareHabitCompletion> completions, int target) {
  if (target <= 0) return 0.0;
  final done = completions.fold<int>(0, (s, c) => s + c.count);
  return (done / target).clamp(0.0, 1.0);
}
class CareSnapshot {
  const CareSnapshot({
    this.assets = const [],
    this.tasks = const [],
    this.records = const [],
    this.readings = const [],
    this.fuelLogs = const [],
    this.bills = const [],
    this.payments = const [],
    this.warranties = const [],
    this.subscriptions = const [],
    this.habits = const [],
    this.habitCompletions = const [],
    this.rewards = const [],
  });

  final List<CareAsset> assets;
  final List<CareTask> tasks;
  final List<CareRecord> records;
  final List<OdometerReading> readings;
  final List<FuelLog> fuelLogs;
  final List<Bill> bills;
  final List<BillPayment> payments;
  final List<Warranty> warranties;
  final List<Subscription> subscriptions;
  final List<CareHabit> habits;
  final List<CareHabitCompletion> habitCompletions;
  final List<CareReward> rewards;

  List<CareAsset> assetsOf(CareAssetKind kind) =>
      assets.where((a) => a.kind == kind && !a.archived).toList();

  List<CareTask> tasksOf(String assetId) =>
      tasks.where((t) => t.assetId == assetId).toList();

  List<CareRecord> recordsOf(String assetId) =>
      records.where((r) => r.assetId == assetId).toList();

  List<OdometerReading> readingsOf(String assetId) =>
      readings.where((r) => r.assetId == assetId).toList();

  List<FuelLog> fuelOf(String assetId) =>
      fuelLogs.where((f) => f.assetId == assetId).toList();

  List<Bill> billsOf(String assetId) =>
      bills.where((b) => b.assetId == assetId).toList();

  List<BillPayment> paymentsOf(String billId) =>
      payments.where((p) => p.billId == billId).toList();

  List<Warranty> warrantiesOf(String assetId) =>
      warranties.where((w) => w.assetId == assetId).toList();

  List<CareHabit> habitsOf(String kidId) =>
      habits.where((h) => h.kidId == kidId).toList();

  List<CareHabitCompletion> completionsOf(String habitId) =>
      habitCompletions.where((c) => c.habitId == habitId).toList();

  List<CareReward> rewardsOf(String kidId) =>
      rewards.where((r) => r.kidId == kidId && r.redeemedAt == null).toList();

  /// Highest odometer ever recorded for [assetId] (readings and records).
  int? currentKm(String assetId) {
    int? best;
    for (final r in readings) {
      if (r.assetId == assetId && (best == null || r.km > best)) best = r.km;
    }
    for (final r in records) {
      final km = r.odometerKm;
      if (r.assetId == assetId && km != null && (best == null || km > best)) {
        best = km;
      }
    }
    for (final f in fuelLogs) {
      if (f.assetId == assetId &&
          (best == null || f.odometerKm > best)) {
        best = f.odometerKm;
      }
    }
    return best;
  }
}
