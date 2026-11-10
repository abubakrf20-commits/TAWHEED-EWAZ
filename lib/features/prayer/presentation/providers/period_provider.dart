import 'dart:convert';
import 'dart:math' show Random, sqrt;
import 'package:crypto/crypto.dart' show sha256;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'period_provider.g.dart';

enum PeriodStatus {
  period,
  nifas,
  istihadha,
  clean,
  predictedPeriod,
  predictedClean,
  irregular,
  unknown
}

/// نوع رکورد دوره: حیض، نفاس (پس از زایمان) یا استحاضه (خونریزی غیرحیض).
enum PeriodRecordType { hayz, nifas, istihadha }

const Map<PeriodRecordType, String> periodRecordTypeLabels = {
  PeriodRecordType.hayz: 'حیض',
  PeriodRecordType.nifas: 'نفاس',
  PeriodRecordType.istihadha: 'استحاضه',
};

/// نوع‌های استحاضه (قلیله/متوسطه/کثیره) → برچسب فارسی، برای تاریخچه و PDF.
const Map<String, String> periodIstihadhaTypeLabels = {
  'qalila': 'استحاضهٔ کم',
  'mutawassita': 'استحاضهٔ متوسط',
  'kathira': 'استحاضهٔ زیاد',
};

/// شدت خونریزی برای نمودار و گزارش پزشکی.
enum PeriodFlow { light, medium, heavy }

const Map<PeriodFlow, String> periodFlowLabels = {
  PeriodFlow.light: 'کم',
  PeriodFlow.medium: 'متوسط',
  PeriodFlow.heavy: 'زیاد',
};

/// حداکثر موجهای هر نوع خونریزی — رکورد فعالِ بلندتر از این، رهاشده فرض و
/// خودکار در همان سقف بسته میشود (جلوگیری از «حیض دائمی»).
/// حیض: حداکثر فقهی 15 روز — نفاس: حداکثر فقهی 60 روز (قول مشهور شافعی) —
/// استحاضه: سقف عملی برای جلوگیری از رکورد ابدی.
int maxBleedingDaysFor(PeriodRecordType type) {
  switch (type) {
    case PeriodRecordType.nifas:
      return 60;
    case PeriodRecordType.istihadha:
      return 180;
    case PeriodRecordType.hayz:
      return 15;
  }
}

/// برچسب یکسان «انتظام سیکل» — هم در کارت آمار اپ و هم در گزارش PDF از همین
/// تابع استفاده می‌شود تا آستانه‌ها هیچ‌وقت از هم فاصله نگیرند.
String periodRegularityLabel(double? r) {
  if (r == null) return '—';
  if (r >= 0.85) return 'بسیار منظم';
  if (r >= 0.6) return 'نسبتاً منظم';
  return 'نامنظم';
}

PeriodRecordType _parseRecordType(String? raw) {
  switch (raw) {
    case 'nifas':
      return PeriodRecordType.nifas;
    case 'istihadha':
      return PeriodRecordType.istihadha;
    default:
      return PeriodRecordType.hayz;
  }
}

PeriodFlow? _parseFlow(String? raw) {
  switch (raw) {
    case 'light':
      return PeriodFlow.light;
    case 'medium':
      return PeriodFlow.medium;
    case 'heavy':
      return PeriodFlow.heavy;
    default:
      return null;
  }
}

String? _flowToDb(PeriodFlow? flow) {
  switch (flow) {
    case PeriodFlow.light:
      return 'light';
    case PeriodFlow.medium:
      return 'medium';
    case PeriodFlow.heavy:
      return 'heavy';
    case null:
      return null;
  }
}

/// نرمال‌سازی به ابتدای روز محلی — همهٔ مقایسه‌های تاریخ باید فقط بر اساس
/// روز انجام شود، نه ساعت (وگرنه روز آخر دوره در بنر/آمار حذف می‌شود).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class CyclePrediction {
  final DateTime nextPeriodStart;
  final DateTime currentPeriodEnd;
  final int daysUntilNextPeriod;
  final int daysUntilCurrentEnd;
  final PeriodStatus status;
  final int currentDayInCycle;
  final int totalCycleDays;

  /// طول دورهٔ پیش‌بینی‌شده (میانگین طول دوره) — برای برچسب «روز N دوره»
  /// و پنجرهٔ «احتمال حیض» در نمای ماهانه به‌کار می‌رود.
  final int upcomingPeriodDays;

  const CyclePrediction({
    required this.nextPeriodStart,
    required this.currentPeriodEnd,
    required this.daysUntilNextPeriod,
    required this.daysUntilCurrentEnd,
    required this.status,
    required this.currentDayInCycle,
    required this.totalCycleDays,
    required this.upcomingPeriodDays,
  });

  /// Estimated ovulation day = next period − 14 days (a standard luteal-phase
  /// length). Pure arithmetic on [nextPeriodStart], so it is exact for every
  /// prediction the app builds.
  DateTime get ovulationDay =>
      nextPeriodStart.subtract(const Duration(days: 14));

  /// Start of the fertile window: the clinical standard window is 6 days —
  /// ovulation −4 … +1 (sperm survive up to ~5 days, the egg ~24 hours).
  DateTime get fertileStart => ovulationDay.subtract(const Duration(days: 4));

  /// End of the fertile window: the egg survives ~24 hours after release.
  DateTime get fertileEnd => ovulationDay.add(const Duration(days: 1));

  /// True when [date] falls inside the fertile window.
  bool isFertile(DateTime date) =>
      !date.isBefore(fertileStart) && !date.isAfter(fertileEnd);

  /// Calendar-day-precision variant used by the month view.
  bool isFertileDate(DateTime date) =>
      isFertile(DateTime(date.year, date.month, date.day));
}

/// Snapshot of measured cycle history for the stats card. [regularity] is
/// 0..1 (1 = every gap identical); null when there are fewer than two complete
/// gaps to compare.
class PeriodStatsSnapshot {
  final double averageCycle;
  final double averagePeriod;
  final int? shortestCycle;
  final int? longestCycle;
  final double? regularity;

  const PeriodStatsSnapshot({
    required this.averageCycle,
    required this.averagePeriod,
    this.shortestCycle,
    this.longestCycle,
    this.regularity,
  });
}

extension PeriodRecordX on PeriodRecordTableData {
  int get actualLength {
    if (endDate == null) return 0;
    return _dateOnly(endDate!).difference(_dateOnly(startDate)).inDays + 1;
  }

  bool get isCompleted => endDate != null;

  bool get isActive => endDate == null;

  PeriodRecordType get type => _parseRecordType(recordType);

  PeriodFlow? get flowValue => _parseFlow(flow);

  /// آیا [date] داخل این رکورد است؟ (با دقت روز، بدون نیاز به امضا؟)
  ///
  /// رکوردِ بسته: تا `endDate`. رکوردِ فعال: تا پایان طول پیش‌بینی‌شدهٔ
  /// همان رکورد، ولی هیچ‌وقت کمتر از امروز نیست (تا دوره‌ای که امروز
  /// ادامه دارد پوشش دهد) و نهایتاً سقف فقهیِ نوع خونریزی ([today]
  /// برای پوشش روزهای آیندهٔ رکورد فعال استفاده می‌شود).
  bool coversDate(DateTime date, {required DateTime today}) {
    final d = _dateOnly(date);
    final start = _dateOnly(startDate);
    if (d.isBefore(start)) return false;
    if (endDate != null) return !d.isAfter(_dateOnly(endDate!));
    // Active: use this record's stored periodLength, floored at today and
    // capped at the fiqh maximum for its type — never the global default.
    final predictedEnd = start.add(Duration(days: periodLength - 1));
    final asOf = _dateOnly(today);
    var end = predictedEnd.isAfter(asOf) ? predictedEnd : asOf;
    final maxEnd = start.add(Duration(days: maxBleedingDaysFor(type) - 1));
    if (end.isAfter(maxEnd)) end = maxEnd;
    return !d.isAfter(end);
  }
}

/// Hashes a secret (PIN / recovery answer) with a random per-value salt so the
/// stored value is never recoverable from SharedPreferences. Format:
/// `sha256$1$<base64 salt>$<hex digest>`. Legacy plaintext values are still
/// accepted (so existing users can unlock) and are re-hashed immediately on
/// the first successful verify — see [_isLegacySecret].
String _hashSecret(String value) {
  final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final digest = sha256.convert(utf8.encode('$salt$value')).toString();
  return 'sha256\$1\$${base64Encode(salt)}\$$digest';
}

/// A stored secret that predates hashing. Kept verbatim in prefs by older
/// builds; still accepted so existing users can unlock, then upgraded to a
/// salted hash on that same successful verify.
bool _isLegacySecret(String stored) => !stored.startsWith(r'sha256$');

bool _verifySecret(String input, String stored) {
  if (_isLegacySecret(stored)) {
    return input == stored;
  }
  try {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'sha256' || parts[1] != '1') {
      return false;
    }
    final salt = base64Decode(parts[2]);
    return sha256.convert(utf8.encode('$salt$input')).toString() == parts[3];
  } catch (e) {
    AppLogger.warning('PeriodProvider', 'reminder check failed: $e');
    return false;
  }
}

/// نرمال‌سازی پاسخ بازیابی قبل از هَش/مقایسه — trim + lowercase تا
/// «Paris» و «paris» یکی شمرده شوند (وگرنه بازیابی هیچ‌وقت کار نمی‌کند).
String _normalizeSecret(String value) => value.trim().toLowerCase();

class PeriodState {
  final List<PeriodRecordTableData> records;
  final int defaultPeriodLength;
  final int defaultCycleLength;
  final bool isLocked;
  final bool notificationsEnabled;

  /// حالت بارداری: تا زمانی که فعال باشد، پیش‌بینی چرخه متوقف می‌شود.
  final bool isPregnant;
  final DateTime? pregnancyDueDate;

  /// Manually tracked قضای روزه (make-up fasts): how many the user owes and how
  /// many have been made up. Kept separate from the period-derived Ramadan
  /// misses so the user can also record fasts broken for other reasons.
  final int qadaFastsOwed;
  final int qadaFastsDone;

  /// آخرین سال/تعدادی که از روزه‌های رمضان به‌صورت خودکار به قضا اضافه شده —
  /// تا زدن دوبارهٔ دکمه، روزه‌ها را تکراری اضافه نکند.
  final int qadaRamadanAddedYear;
  final int qadaRamadanAddedCount;

  const PeriodState({
    this.records = const [],
    this.defaultPeriodLength = 7,
    this.defaultCycleLength = 28,
    this.isLocked = false,
    this.notificationsEnabled = true,
    this.isPregnant = false,
    this.pregnancyDueDate,
    this.qadaFastsOwed = 0,
    this.qadaFastsDone = 0,
    this.qadaRamadanAddedYear = 0,
    this.qadaRamadanAddedCount = 0,
  });

  PeriodState copyWith({
    List<PeriodRecordTableData>? records,
    int? defaultPeriodLength,
    int? defaultCycleLength,
    bool? isLocked,
    bool? notificationsEnabled,
    bool? isPregnant,
    DateTime? pregnancyDueDate,
    int? qadaFastsOwed,
    int? qadaFastsDone,
    int? qadaRamadanAddedYear,
    int? qadaRamadanAddedCount,
  }) {
    return PeriodState(
      records: records ?? this.records,
      defaultPeriodLength: defaultPeriodLength ?? this.defaultPeriodLength,
      defaultCycleLength: defaultCycleLength ?? this.defaultCycleLength,
      isLocked: isLocked ?? this.isLocked,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnancyDueDate: pregnancyDueDate ?? this.pregnancyDueDate,
      qadaFastsOwed: qadaFastsOwed ?? this.qadaFastsOwed,
      qadaFastsDone: qadaFastsDone ?? this.qadaFastsDone,
      qadaRamadanAddedYear: qadaRamadanAddedYear ?? this.qadaRamadanAddedYear,
      qadaRamadanAddedCount:
          qadaRamadanAddedCount ?? this.qadaRamadanAddedCount,
    );
  }

  /// Make-up fasts still owed (never negative).
  int get qadaFastsRemaining =>
      (qadaFastsOwed - qadaFastsDone) > 0 ? qadaFastsOwed - qadaFastsDone : 0;
}

@riverpod
class Period extends _$Period {
  PeriodRecordDao? _dao;
  SharedPreferences? _prefs;
  String _pinCache = '';
  String _recoveryQuestion = '';
  String _recoveryAnswer = '';
  DateTime? _nextPeriodNotifDateCache;
  DateTime? _ghuslReminderDateCache;

  @override
  Future<PeriodState> build() async {
    _dao = ref.read(periodRecordDaoProvider);
    _prefs = await SharedPreferences.getInstance();
    final state = await _loadStateAsync();
    // Arm reminders on every startup (and after any rebuild) so a user who
    // never touches the notification switch still gets them. Best-effort:
    // the plugin is unavailable in tests and some platforms.
    Future.microtask(() {
      try {
        syncPeriodReminders();
      } catch (e) {
        // Ignore — in-app prediction still works without notifications.
        AppLogger.warning('PeriodProvider', 'notif schedule failed: $e');
      }
    });
    return state;
  }

  Future<PeriodState> _loadStateAsync() async {
    final dao = _dao;
    if (dao == null) return const PeriodState();
    final records = await dao.getAllRecords();
    final sorted = List<PeriodRecordTableData>.from(records)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final prefs = _prefs;
    final periodLength = prefs?.getInt('period_length') ?? 7;
    final cycleLength = prefs?.getInt('cycle_length') ?? 28;
    final locked = prefs?.getBool('period_locked') ?? false;
    final notifEnabled = prefs?.getBool('period_notif_enabled') ?? true;
    final pregnant = prefs?.getBool('period_pregnant') ?? false;
    final qadaOwed = prefs?.getInt('qada_fasts_owed') ?? 0;
    final qadaDone = prefs?.getInt('qada_fasts_done') ?? 0;
    _pinCache = prefs?.getString('period_pin') ?? '';
    _recoveryQuestion = prefs?.getString('period_recovery_question') ?? '';
    _recoveryAnswer = prefs?.getString('period_recovery_answer') ?? '';
    _nextPeriodNotifDateCache =
        _parseDateOrNull(prefs?.getString('next_period_notif'));
    _ghuslReminderDateCache =
        _parseDateOrNull(prefs?.getString('ghusl_reminder_date'));

    // Auto-close abandoned active records at their fiqh max so a forgotten
    // record can never become permanent «حیض». Persisted so the fix sticks.
    final today = _dateOnly(DateTime.now());
    var autoClosed = false;
    for (final r in sorted.where((r) => r.isActive)) {
      final maxEnd = _dateOnly(r.startDate)
          .add(Duration(days: maxBleedingDaysFor(r.type) - 1));
      if (today.isAfter(maxEnd)) {
        final updated = r.copyWith(
          endDate: Value(maxEnd),
          periodLength: maxEnd.difference(_dateOnly(r.startDate)).inDays + 1,
        );
        await dao.upsertRecord(updated);
        final idx = sorted.indexWhere((x) => x.id == r.id);
        if (idx != -1) sorted[idx] = updated;
        autoClosed = true;
      }
    }
    if (autoClosed) {
      sorted.sort((a, b) => b.startDate.compareTo(a.startDate));
    }

    return PeriodState(
      records: sorted,
      defaultPeriodLength: periodLength,
      defaultCycleLength: cycleLength,
      isLocked: locked,
      notificationsEnabled: notifEnabled,
      isPregnant: pregnant,
      pregnancyDueDate:
          _parseDateOrNull(prefs?.getString('period_pregnancy_due')),
      qadaFastsOwed: qadaOwed,
      qadaFastsDone: qadaDone,
      qadaRamadanAddedYear: prefs?.getInt('qada_ramadan_added_year') ?? 0,
      qadaRamadanAddedCount: prefs?.getInt('qada_ramadan_added_count') ?? 0,
    );
  }

  Future<void> _notify() async {
    final s = await _loadStateAsync();
    // Publish the fresh snapshot unconditionally. The old `is AsyncData`
    // guard silently dropped every update while the provider sat in an error
    // (or loading) state, so a write after a transient failure persisted but
    // never reached the UI.
    state = AsyncValue.data(s);
  }

  String get pin => _pinCache;

  DateTime? _parseDateOrNull(String? raw) =>
      raw != null ? DateTime.tryParse(raw) : null;

  Future<void> setPeriodLength(int days) async {
    await _prefs?.setInt('period_length', days);
    await _notify();
  }

  Future<void> setCycleLength(int days) async {
    await _prefs?.setInt('cycle_length', days);
    await _notify();
  }

  // ── قضای روزه (make-up fasts) ──────────────────────────────────────────────

  /// Sets how many make-up fasts the user owes in total.
  Future<void> setQadaFastsOwed(int days) async {
    await _prefs?.setInt('qada_fasts_owed', days < 0 ? 0 : days);
    await _notify();
  }

  /// Sets how many make-up fasts have been completed.
  Future<void> setQadaFastsDone(int days) async {
    await _prefs?.setInt('qada_fasts_done', days < 0 ? 0 : days);
    await _notify();
  }

  /// Records one more completed make-up fast (never past what is owed).
  Future<void> addQadaFastDone() async {
    final current = state.value ?? const PeriodState();
    final next = current.qadaFastsDone + 1;
    await setQadaFastsDone(
        next > current.qadaFastsOwed ? current.qadaFastsOwed : next);
  }

  /// Undoes one completed make-up fast.
  Future<void> removeQadaFastDone() async {
    final current = state.value ?? const PeriodState();
    await setQadaFastsDone(current.qadaFastsDone - 1);
  }

  /// Adds [days] to the owed total (e.g. after a new Ramadan).
  Future<void> addQadaFastsOwed(int days) async {
    final current = state.value ?? const PeriodState();
    await setQadaFastsOwed(current.qadaFastsOwed + days);
  }

  /// Adds only the *new* period-derived Ramadan missed days to the owed total.
  /// Idempotent: calling it twice without new records adds nothing, because the
  /// already-added count for the year is remembered. Returns how many days were
  /// actually added (0 when nothing changed).
  Future<int> addRamadanMissedToQada(int year, {int? hijriOffset}) async {
    final current = state.value ?? const PeriodState();
    final offset = hijriOffset ?? 2;
    final missed = getMissedFastingDays(year, hijriOffset: offset).length;
    final alreadyAdded = current.qadaRamadanAddedYear == year
        ? current.qadaRamadanAddedCount
        : 0;
    final delta = missed - alreadyAdded;
    if (delta <= 0) return 0;
    await setQadaFastsOwed(current.qadaFastsOwed + delta);
    await _prefs?.setInt('qada_ramadan_added_year', year);
    await _prefs?.setInt('qada_ramadan_added_count', missed);
    await _notify();
    return delta;
  }

  /// Enables/disables pregnancy mode. While pregnant, cycle prediction pauses.
  Future<void> setPregnant(bool pregnant) async {
    await _prefs?.setBool('period_pregnant', pregnant);
    if (!pregnant) {
      await _prefs?.remove('period_pregnancy_due');
    }
    await _notify();
  }

  /// Records the estimated due date (used by the pregnancy status card).
  Future<void> setPregnancyDueDate(DateTime? due) async {
    if (due == null) {
      await _prefs?.remove('period_pregnancy_due');
    } else {
      await _prefs?.setString('period_pregnancy_due', due.toIso8601String());
    }
    await _notify();
  }

  Future<void> resetQadaFasts() async {
    await _prefs?.setInt('qada_fasts_owed', 0);
    await _prefs?.setInt('qada_fasts_done', 0);
    await _prefs?.setInt('qada_ramadan_added_year', 0);
    await _prefs?.setInt('qada_ramadan_added_count', 0);
    await _notify();
  }

  /// شروع یک دورهٔ جدید. رکوردهای فعال قبلی بسته یا جابه‌جا می‌شوند.
  ///
  /// Returns `false` (and does nothing) when [date] is already covered by a
  /// completed record, or is the start day of the current active record —
  /// so a double-tap can never wipe flow/symptoms/notes. An active record
  /// that started earlier is closed at `date − 1`; one that started later
  /// has its start moved earlier (data preserved) instead of being deleted.
  Future<bool> startPeriod(
    DateTime date, {
    PeriodRecordType type = PeriodRecordType.hayz,
  }) async {
    final current = state.value ?? const PeriodState();
    final day = _dateOnly(date);
    final today = _dateOnly(DateTime.now());

    // A bleeding episode cannot start in the future: the prediction, the
    // reminder schedule and the purity rules all read the record as fact.
    if (day.isAfter(today)) return false;

    // Already covered by a finished record → refuse (no silent data loss).
    for (final r in current.records.where((r) => r.isCompleted)) {
      if (r.coversDate(day, today: today)) return false;
    }

    final active = current.records.where((r) => r.isActive).toList();
    for (final r in active) {
      final start = _dateOnly(r.startDate);
      if (day == start) return false; // double-tap on the same start day
      if (day.isBefore(start)) {
        // Move the active record's start earlier, preserving its data —
        // no separate insert (that would duplicate the bleeding episode).
        final updated = r.copyWith(startDate: day);
        await _dao?.upsertRecord(updated);
        await _notify();
        await syncPeriodReminders();
        return true;
      }
      // day > start: close at day − 1, then insert the new record below.
      final end = day.subtract(const Duration(days: 1));
      final updated = r.copyWith(
        endDate: Value(end),
        periodLength: end.difference(start).inDays + 1,
      );
      await _dao?.upsertRecord(updated);
    }

    final record = PeriodRecordTableCompanion.insert(
      startDate: day,
      periodLength: current.defaultPeriodLength,
      createdAt: DateTime.now(),
      recordType: Value(type.name),
    );
    await _dao?.insertRecord(record);
    await _notify();
    await syncPeriodReminders();
    return true;
  }

  /// شروع نفاس (خونریزی پس از زایمان) — بنابر قول مشهور شافعی بیشترین مدت
  /// آن 60 روز است؛ نماز ساقط و قضای روزهٔ واجب برعهده است.
  Future<bool> startNifas(DateTime date) =>
      startPeriod(date, type: PeriodRecordType.nifas);

  /// شروع استحاضه — خونریزی غیرحیض؛ نماز و روزه واجب و صحیحاند و برای هر
  /// نماز وضو لازم است (مطابق مذهب شافعی).
  Future<bool> startIstihadha(DateTime date) =>
      startPeriod(date, type: PeriodRecordType.istihadha);

  Future<void> endPeriod(DateTime date) async {
    final current = state.value ?? const PeriodState();
    final day = _dateOnly(date);
    if (day.isAfter(_dateOnly(DateTime.now()))) return; // no future endings
    final active = current.records.where((r) => r.isActive).toList();
    for (final r in active) {
      if (day.isBefore(_dateOnly(r.startDate))) continue; // end before start
      final updated = r.copyWith(
        endDate: Value(day),
        periodLength: day.difference(_dateOnly(r.startDate)).inDays + 1,
      );
      await _dao?.upsertRecord(updated);
    }
    await _notify();
    await syncPeriodReminders();
  }

  /// Shortens a completed record so it ends on [date] (same-day end from the
  /// day sheet). No-op when [date] is before the start or after the current end.
  Future<void> setRecordEnd(int recordId, DateTime date) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final r = current.records[idx];
    final day = _dateOnly(date);
    final start = _dateOnly(r.startDate);
    if (day.isAfter(_dateOnly(DateTime.now()))) return; // no future endings
    if (day.isBefore(start)) return;
    if (r.endDate != null && day.isAfter(_dateOnly(r.endDate!))) return;
    final updated = r.copyWith(
      endDate: Value(day),
      periodLength: day.difference(start).inDays + 1,
    );
    await _dao?.upsertRecord(updated);
    await _notify();
    await syncPeriodReminders();
  }

  /// Extends a completed record so it ends on [date] («تمدید دورهٔ قبلی»
  /// from the day sheet). Only allowed when [date] is after the current end.
  Future<void> extendRecordEnd(int recordId, DateTime date) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final r = current.records[idx];
    final day = _dateOnly(date);
    final start = _dateOnly(r.startDate);
    if (day.isAfter(_dateOnly(DateTime.now()))) return; // no future extensions
    if (day.isBefore(start)) return;
    if (r.endDate != null && !day.isAfter(_dateOnly(r.endDate!))) return;
    final updated = r.copyWith(
      endDate: Value(day),
      periodLength: day.difference(start).inDays + 1,
    );
    await _dao?.upsertRecord(updated);
    await _notify();
    await syncPeriodReminders();
  }

  Future<void> deleteRecord(int id) async {
    await _dao?.deleteRecord(id);
    await _notify();
    await syncPeriodReminders();
  }

  Future<void> updateRecordType(int recordId, PeriodRecordType type) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final updated = current.records[idx].copyWith(
      recordType: Value(type.name),
      istihadhaType: const Value(null),
    );
    await _dao?.upsertRecord(updated);
    await _notify();
  }

  Future<void> updateFlow(int recordId, PeriodFlow? flow) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final updated = current.records[idx].copyWith(flow: Value(_flowToDb(flow)));
    await _dao?.upsertRecord(updated);
    await _notify();
  }

  Future<void> updateSymptoms(int recordId, String symptoms) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final updated = current.records[idx].copyWith(symptoms: Value(symptoms));
    await _dao?.upsertRecord(updated);
    await _notify();
  }

  Future<void> updateNotes(int recordId, String notes) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.records.indexWhere((r) => r.id == recordId);
    if (idx == -1) return;
    final updated = current.records[idx].copyWith(notes: Value(notes));
    await _dao?.upsertRecord(updated);
    await _notify();
  }

  PeriodRecordTableData? get latestRecord {
    final current = state.value;
    if (current == null || current.records.isEmpty) return null;
    return current.records.first;
  }

  /// Snapshot فعلی حالت (رکوردها، بارداری، قضا). برای مصرف‌کننده‌های خارجی که
  /// نمی‌توانند به `state` محافظت‌شده دسترسی پیدا کنند.
  PeriodState? get currentSnapshot => state.value;

  CyclePrediction? predict() {
    final current = state.value;
    if (current == null || current.records.isEmpty) return null;
    // در بارداری، پیش‌بینی چرخه معنا ندارد.
    if (current.isPregnant) return null;

    // فقط رکوردهای حیض در پیش‌بینی چرخه شرکت می‌کنند؛ نفاس و استحاضه
    // چرخهٔ قاعدگی نیستند.
    final hayz = current.records
        .where((r) => r.type == PeriodRecordType.hayz)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    if (hayz.isEmpty) return null;

    final now = DateTime.now();
    final today = _dateOnly(now);
    final latest = hayz.first;
    final stats = current.copyWith(records: hayz);
    final avgPeriod = _calculateAveragePeriod(stats).round();
    // The user's configured cycle length is authoritative; history only refines
    // it when the intervals are plausible AND close to the setting (see
    // [_effectiveCycleDays]).
    final avgCycle = _effectiveCycleDays(stats, avgPeriod);
    final irregular = _isIrregular(stats);
    final startDay = _dateOnly(latest.startDate);

    if (latest.isActive) {
      final estimatedEnd = startDay.add(Duration(days: avgPeriod - 1));
      final daysUntilEnd = estimatedEnd.difference(today).inDays;
      final nextPeriodStart = startDay.add(Duration(days: avgCycle));
      final daysUntilNext = nextPeriodStart.difference(today).inDays;

      return CyclePrediction(
        nextPeriodStart: nextPeriodStart,
        currentPeriodEnd: estimatedEnd,
        daysUntilNextPeriod: daysUntilNext > 0 ? daysUntilNext : 0,
        daysUntilCurrentEnd: daysUntilEnd >= 0 ? daysUntilEnd : 0,
        status: PeriodStatus.period,
        currentDayInCycle: today.difference(startDay).inDays + 1,
        totalCycleDays: avgCycle,
        upcomingPeriodDays: avgPeriod,
      );
    }

    // Closed record: always wrap cycles from the latest start so a record
    // older than one full cycle can never leave nextPeriodStart in the past
    // (that used to clamp daysUntil to 0 and fake a permanent «احتمال حیض»).
    if (latest.endDate != null) {
      final daysInto = today.difference(startDay).inDays;
      final cycles = avgCycle > 0 ? daysInto ~/ avgCycle : 0;
      final cycleDay =
          avgCycle > 0 ? daysInto % avgCycle : 0; // 0-based day in cycle
      final logicalStart = startDay.add(Duration(days: cycles * avgCycle));
      final wrappedNext = logicalStart.add(Duration(days: avgCycle));
      final daysUntilWrapped = wrappedNext.difference(today).inDays;

      // Landed inside a predicted bleeding window of a wrapped cycle.
      if (cycles >= 1 && cycleDay < avgPeriod) {
        final windowStart = logicalStart;
        final windowEnd = windowStart.add(Duration(days: avgPeriod - 1));
        return CyclePrediction(
          nextPeriodStart: wrappedNext,
          currentPeriodEnd: windowEnd,
          daysUntilNextPeriod: daysUntilWrapped,
          daysUntilCurrentEnd: windowEnd.difference(today).inDays,
          status: PeriodStatus.predictedPeriod,
          currentDayInCycle: cycleDay + 1,
          totalCycleDays: avgCycle,
          upcomingPeriodDays: avgPeriod,
        );
      }

      return CyclePrediction(
        nextPeriodStart: wrappedNext,
        currentPeriodEnd: latest.endDate!,
        daysUntilNextPeriod: daysUntilWrapped > 0 ? daysUntilWrapped : 0,
        daysUntilCurrentEnd: 0,
        status: daysUntilWrapped <= 3
            ? PeriodStatus.predictedPeriod
            : (irregular ? PeriodStatus.irregular : PeriodStatus.clean),
        currentDayInCycle: cycleDay + 1,
        totalCycleDays: avgCycle,
        upcomingPeriodDays: avgPeriod,
      );
    }

    return null;
  }

  /// Is [date] inside a predicted (not recorded) bleeding window?
  ///
  /// Uses the same wrap arithmetic as [predict] so the month calendar and
  /// the day-status text can never disagree.
  bool isPredictedPeriodDate(DateTime date) {
    final prediction = predict();
    if (prediction == null) return false;
    if (prediction.status != PeriodStatus.predictedPeriod) return false;
    final current = state.value;
    if (current == null) return false;
    final hayz = current.records
        .where((r) => r.type == PeriodRecordType.hayz)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    if (hayz.isEmpty) return false;

    final d = _dateOnly(date);
    final today = _dateOnly(DateTime.now());
    final startDay = _dateOnly(hayz.first.startDate);
    final avgPeriod =
        _calculateAveragePeriod(current.copyWith(records: hayz)).round();
    final avgCycle =
        _effectiveCycleDays(current.copyWith(records: hayz), avgPeriod);
    final daysInto = d.difference(startDay).inDays;
    if (daysInto < 0) return false;
    final cycles = avgCycle > 0 ? daysInto ~/ avgCycle : 0;
    final cycleDay = avgCycle > 0 ? daysInto % avgCycle : 0;
    // Inside a wrapped predicted window, or within the 3-day «احتمال» lead.
    if (cycles >= 1 && cycleDay < avgPeriod) return true;
    final untilNext = avgCycle > 0 ? avgCycle - cycleDay : 99;
    return untilNext <= 3 && d.difference(today).inDays >= -1;
  }

  /// چرخهٔ نامنظم وقتی دو فاصلهٔ ثبت‌شده یا بیشتر داریم و انتظام زیر 0٫6 است.
  bool _isIrregular(PeriodState state) {
    final r = cycleStatsFor(state)?.regularity;
    return r != null && r < 0.6;
  }

  /// آیا چرخهٔ کاربر (بر اساس تاریخچهٔ ثبت‌شده) نامنظم است؟
  bool get hasIrregularCycle {
    final current = state.value;
    if (current == null) return false;
    final hayz =
        current.records.where((r) => r.type == PeriodRecordType.hayz).toList();
    return _isIrregular(current.copyWith(records: hayz));
  }

  /// Effective cycle length in days, used by every prediction.
  ///
  /// The configured [PeriodState.defaultCycleLength] is the baseline. Recorded
  /// history only overrides it when it is trustworthy:
  ///  * at least two valid intervals (16..59 days),
  ///  * their MEDIAN (robust against a single outlier entry) sits in the
  ///    physiological 21..45 window, and
  ///  * it is within ±7 days of the configured value.
  /// The result is additionally floored at `periodLength + 7` so a period can
  /// never be predicted before the bleeding has plausibly finished.
  int _effectiveCycleDays(PeriodState state, int periodLength) {
    final configured = state.defaultCycleLength;
    var cycle = configured;

    if (state.records.length >= 3) {
      final sorted = List<PeriodRecordTableData>.from(state.records)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      // Most recent valid intervals only — old history must not dominate.
      final intervals = <int>[];
      for (var i = 0; i + 1 < sorted.length && intervals.length < 3; i++) {
        final diff =
            sorted[i].startDate.difference(sorted[i + 1].startDate).inDays;
        if (diff >= 16 && diff <= 59) intervals.add(diff);
      }
      if (intervals.length >= 2) {
        intervals.sort();
        final median = intervals[intervals.length ~/ 2];
        if (median >= 21 && median <= 45 && (median - configured).abs() <= 7) {
          cycle = median;
        }
      }
    }

    final floor = periodLength + 7;
    if (cycle < floor) cycle = floor;
    return cycle.clamp(16, 60);
  }

  double _calculateAveragePeriod(PeriodState state) {
    final completed = state.records
        .where((r) => r.isCompleted && r.actualLength > 0)
        .toList();
    if (completed.isEmpty) return state.defaultPeriodLength.toDouble();

    int total = 0;
    for (final r in completed) {
      total += r.actualLength;
    }
    return total / completed.length;
  }

  /// Aggregates over completed gaps: average / shortest / longest cycle and
  /// regularity (1 − stdDev/mean, clamped to 0..1; null with < 2 gaps).
  /// Powers the stats card. Kept separate from [_effectiveCycleDays] because
  /// the stats card reports measured history, while predictions use the
  /// configured-cycle baseline.
  /// Raw mean of valid recorded gaps (16..59) — what the stats card shows:
  /// the user's measured reality, not the setting-bounded effective cycle
  /// used for prediction.
  double _calculateAverageCycle(PeriodState state) {
    if (state.records.length < 2) return state.defaultCycleLength.toDouble();

    final sorted = List<PeriodRecordTableData>.from(state.records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    int totalDays = 0;
    int count = 0;
    for (int i = 1; i < sorted.length; i++) {
      final diff =
          sorted[i].startDate.difference(sorted[i - 1].startDate).inDays;
      if (diff > 15 && diff < 60) {
        totalDays += diff;
        count++;
      }
    }

    return count > 0 ? totalDays / count : state.defaultCycleLength.toDouble();
  }

  PeriodStatsSnapshot? cycleStats() {
    final current = state.value;
    if (current == null || current.records.isEmpty) return null;
    // فقط حیض در آمار سیکل شمرده می‌شود.
    final hayz =
        current.records.where((r) => r.type == PeriodRecordType.hayz).toList();
    if (hayz.isEmpty) return null;
    return cycleStatsFor(current.copyWith(records: hayz));
  }

  PeriodStatsSnapshot? cycleStatsFor(PeriodState current) {
    if (current.records.isEmpty) return null;

    final sorted = List<PeriodRecordTableData>.from(current.records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final gaps = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final diff =
          sorted[i].startDate.difference(sorted[i - 1].startDate).inDays;
      if (diff > 15 && diff < 60) gaps.add(diff);
    }

    final avgCycle = _calculateAverageCycle(current);
    final avgPeriod = _calculateAveragePeriod(current);

    if (gaps.isEmpty) {
      return PeriodStatsSnapshot(
          averageCycle: avgCycle, averagePeriod: avgPeriod.toDouble());
    }

    int shortest = gaps.first;
    int longest = gaps.first;
    for (final g in gaps) {
      if (g < shortest) shortest = g;
      if (g > longest) longest = g;
    }

    double? regularity;
    if (gaps.length >= 2) {
      final mean = gaps.reduce((a, b) => a + b) / gaps.length;
      final variance =
          gaps.fold<double>(0, (acc, g) => acc + (g - mean) * (g - mean)) /
              gaps.length;
      final stdDev = variance <= 0 ? 0.0 : sqrt(variance);
      regularity = mean <= 0 ? 1.0 : (1 - stdDev / mean).clamp(0.0, 1.0);
    }

    return PeriodStatsSnapshot(
      averageCycle: avgCycle,
      averagePeriod: avgPeriod,
      shortestCycle: shortest,
      longestCycle: longest,
      regularity: regularity,
    );
  }

  Map<int, PeriodStatus> getMonthData(int jalaliYear, int jalaliMonth) {
    final current = state.value;
    if (current == null) return {};

    final result = <int, PeriodStatus>{};
    final daysInMonth = Jalali(jalaliYear, jalaliMonth).monthLength;

    final hayz = current.records
        .where((r) => r.type == PeriodRecordType.hayz)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final hayzState = current.copyWith(records: hayz);
    final avgPeriod = _calculateAveragePeriod(hayzState).round();
    final avgCycle = _effectiveCycleDays(hayzState, avgPeriod);
    final prediction = predict();
    final today = _dateOnly(DateTime.now());

    int priority(PeriodStatus s) {
      switch (s) {
        case PeriodStatus.period:
          return 3;
        case PeriodStatus.nifas:
          return 2;
        case PeriodStatus.istihadha:
          return 1;
        default:
          return 0;
      }
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = Jalali(jalaliYear, jalaliMonth, day).toDateTime();
      final d = _dateOnly(date);

      PeriodStatus? recorded;
      for (final r in current.records) {
        if (!r.coversDate(d, today: today)) continue;
        final s = r.type == PeriodRecordType.nifas
            ? PeriodStatus.nifas
            : r.type == PeriodRecordType.istihadha
                ? PeriodStatus.istihadha
                : PeriodStatus.period;
        if (recorded == null || priority(s) > priority(recorded)) {
          recorded = s;
        }
      }

      if (recorded != null) {
        result[day] = recorded;
        continue;
      }

      if (hayz.isNotEmpty) {
        final lastStart = _dateOnly(hayz.first.startDate);
        final daysSinceLast = d.difference(lastStart).inDays;

        // Same wrap rule as predict(): only wrapped cycles (cycles >= 1)
        // can be predicted — a just-ended record's own window is recorded.
        if (daysSinceLast >= 0 && avgCycle > 0) {
          final cycles = daysSinceLast ~/ avgCycle;
          final cycleDay = daysSinceLast % avgCycle;
          if (cycles >= 1 && cycleDay < avgPeriod.toInt()) {
            result[day] = PeriodStatus.predictedPeriod;
            continue;
          }
        }
      }

      // Fertile window (only for future/ongoing cycles — the prediction is
      // anchored to the latest record, so a fertile hit in a month long past
      // is stale data, not guidance).
      if (prediction != null &&
          prediction.isFertileDate(d) &&
          !d.isBefore(today.subtract(const Duration(days: 1)))) {
        result[day] = PeriodStatus.predictedClean;
      }
    }

    return result;
  }

  /// Recent valid cycle gaps (start-to-start, 16..59 days) for the trend
  /// chart and PDF — newest first. Empty when history is too short.
  List<int> recentCycleGaps({int limit = 8}) {
    final current = state.value;
    if (current == null) return [];
    final hayz = current.records
        .where((r) => r.type == PeriodRecordType.hayz)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final gaps = <int>[];
    for (var i = 0; i + 1 < hayz.length && gaps.length < limit; i++) {
      final diff = hayz[i].startDate.difference(hayz[i + 1].startDate).inDays;
      if (diff > 15 && diff < 60) gaps.add(diff);
    }
    return gaps;
  }

  List<Map<String, dynamic>> getHistorySummary() {
    final current = state.value;
    if (current == null) return [];

    final sorted = List<PeriodRecordTableData>.from(current.records)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return sorted.take(12).map((r) {
      int? cycleDays;
      final idx = sorted.indexOf(r);
      if (idx < sorted.length - 1) {
        cycleDays = r.startDate.difference(sorted[idx + 1].startDate).inDays;
      }

      return {
        'startDate': r.startDate,
        'endDate': r.endDate,
        'periodDays': r.actualLength,
        'cycleDays': cycleDays,
        'isActive': r.isActive,
        'symptoms': r.symptoms ?? '',
        'notes': r.notes ?? '',
        'id': r.id,
        'type': r.type.name,
        'typeLabel': periodRecordTypeLabels[r.type] ?? 'حیض',
        'istihadhaType': r.istihadhaType,
        'istihadhaTypeLabel': r.istihadhaType == null
            ? null
            : periodIstihadhaTypeLabels[r.istihadhaType!] ?? r.istihadhaType,
        'flow': r.flow,
        'flowLabel': r.flowValue == null ? null : periodFlowLabels[r.flowValue],
      };
    }).toList();
  }

  Map<String, dynamic> getTodayStatus() {
    final current = state.value;
    final today = DateTime.now();

    // Record check MUST run before the pregnancy banner — a pregnancy with
    // a recorded bleed still has hayz/nifas rulings for that day.
    final todayRecord = findRecordForDate(today);
    if (todayRecord != null) {
      switch (todayRecord.type) {
        case PeriodRecordType.nifas:
          return {
            'status': 'nifas',
            'canPray': false,
            'canFast': false,
            'needsGhusl': false,
            'message':
                'در ایام نفاس هستید. نماز ساقط است و قضا ندارد؛ روزه ساقط است ولی قضای روزهٔ واجب (رمضان) بر شما واجب است — روزهٔ مستحبی قضا ندارد. بیشترین مدت نفاس 60 روز است.',
          };
        case PeriodRecordType.istihadha:
          return {
            'status': 'istihadha',
            'canPray': true,
            'canFast': true,
            'needsGhusl': false,
            'message':
                'استحاضه (خونریزی غیرحیض): برای هر نماز وضو بگیرید و ناحیه را پاک نگه دارید؛ نماز و روزه بر شما واجب است و صحیح است.',
          };
        case PeriodRecordType.hayz:
          return {
            'status': 'haid',
            'canPray': false,
            'canFast': false,
            'needsGhusl': false,
            'message':
                'در ایام حیض هستید. نماز بر شما ساقط است و قضا ندارد؛ روزه ساقط است ولی قضای روزهٔ واجب (رمضان) بر شما واجب است — روزهٔ مستحبی قضا ندارد.',
          };
      }
    }

    if (current != null && current.isPregnant) {
      return {
        'status': 'pregnant',
        'canPray': true,
        'canFast': true,
        'needsGhusl': false,
        'message':
            'حالت بارداری فعال است؛ پیش‌بینی چرخه متوقف شده است. اگر خونریزی دارید آن را ثبت کنید تا احکام آن نمایش داده شود.',
      };
    }

    if (needsGhuslToday) {
      return {
        'status': 'ghusl',
        'canPray': true,
        'canFast': true,
        'needsGhusl': true,
        'message':
            'دورهٔ شما تمام شده است؛ پیش از نماز و روزه، غسل حیض/نفاس بر شما واجب است.',
      };
    }

    final prediction = predict();
    if (prediction == null) {
      return {
        'status': 'unknown',
        'canPray': true,
        'canFast': true,
        'needsGhusl': false,
        'message': 'اطلاعات کافی ثبت نشده است.',
      };
    }

    switch (prediction.status) {
      case PeriodStatus.period:
        return {
          'status': 'haid',
          'canPray': false,
          'canFast': false,
          'needsGhusl': false,
          'message':
              'در ایام حیض هستید. نماز بر شما ساقط است و قضا ندارد؛ روزه ساقط است ولی قضای روزهٔ واجب (رمضان) بر شما واجب است — روزهٔ مستحبی قضا ندارد.',
        };
      case PeriodStatus.predictedPeriod:
        return {
          'status': 'predicted',
          'canPray': true,
          'canFast': true,
          'needsGhusl': false,
          'message':
              'در روزهای احتمال شروع دوره هستید. تا ثبت قطعی شروع دوره، نماز و روزه بر شما واجب است.',
        };
      case PeriodStatus.irregular:
        return {
          'status': 'irregular',
          'canPray': true,
          'canFast': true,
          'needsGhusl': false,
          'message':
              'چرخهٔ شما نامنظم است؛ پیش‌بینی‌ها تقریبی‌اند و تا ثبت شروع دوره، نماز و روزه واجب است. در صورت تداوم با پزشک مشورت کنید.',
        };
      case PeriodStatus.clean:
      case PeriodStatus.predictedClean:
        return {
          'status': 'tahir',
          'canPray': true,
          'canFast': true,
          'needsGhusl': false,
          'message': 'در حال طهر (پاکی) هستید. نماز و روزه بر شما واجب است.',
        };
      default:
        return {
          'status': 'unknown',
          'canPray': true,
          'canFast': true,
          'needsGhusl': false,
          'message': 'وضعیت نامشخص.',
        };
    }
  }

  Future<void> clearAll() async {
    final records = await _dao?.getAllRecords() ?? [];
    for (final r in records) {
      await _dao?.deleteRecord(r.id);
    }
    await _notify();
    try {
      await NotificationService().cancelPeriodReminders();
    } catch (_) {
      // Notification plugin unavailable (e.g. tests) — best effort.
    }
  }

  /// آخرین رکورد حیض یا نفاس که به پایان رسیده است.
  PeriodRecordTableData? get latestCompletedBleeding {
    final current = state.value;
    if (current == null) return null;
    final list = current.records
        .where((r) =>
            r.isCompleted &&
            (r.type == PeriodRecordType.hayz ||
                r.type == PeriodRecordType.nifas))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return list.isEmpty ? null : list.first;
  }

  /// امروز روز غسل است؟ (روز بعد از پایان آخرین حیض/نفاس ثبت‌شده —
  /// فقط وقتی هیچ رکورد فعالی باقی نمانده باشد)
  bool get needsGhuslToday {
    final current = state.value;
    if (current != null && current.records.any((r) => r.isActive)) {
      return false;
    }
    final rec = latestCompletedBleeding;
    if (rec?.endDate == null) return false;
    final ghuslDay = _dateOnly(rec!.endDate!).add(const Duration(days: 1));
    return _dateOnly(DateTime.now()) == ghuslDay;
  }

  bool isDateInHayz(DateTime date) =>
      findRecordForDate(date)?.type == PeriodRecordType.hayz;

  bool isDateInNifas(DateTime date) =>
      findRecordForDate(date)?.type == PeriodRecordType.nifas;

  bool isDateInIstihadha(DateTime date) =>
      findRecordForDate(date)?.type == PeriodRecordType.istihadha;

  /// حیض یا نفاس — روزهایی که نماز ساقط و قضای روزه واجب است.
  /// (استحاضه شامل نمی‌شود چون نماز و روزه در آن واجب است.)
  bool isDateInPeriod(DateTime date) {
    final t = findRecordForDate(date)?.type;
    return t == PeriodRecordType.hayz || t == PeriodRecordType.nifas;
  }

  PeriodRecordTableData? findRecordForDate(DateTime date) {
    final current = state.value;
    if (current == null) return null;

    for (final r in current.records) {
      if (r.coversDate(date, today: _dateOnly(DateTime.now()))) return r;
    }
    return null;
  }

  Future<void> setLocked(bool locked) async {
    await _prefs?.setBool('period_locked', locked);
    await _notify();
  }

  Future<void> setPin(String pin) async {
    _pinCache = _hashSecret(pin);
    await _prefs?.setString('period_pin', _pinCache);
  }

  bool verifyPin(String input) {
    final stored = pin;
    if (!_verifySecret(input, stored)) return false;
    if (_isLegacySecret(stored)) _upgradePin(input);
    return true;
  }

  String get recoveryQuestion => _recoveryQuestion;

  bool get hasRecovery =>
      _recoveryQuestion.isNotEmpty && _recoveryAnswer.isNotEmpty;

  Future<void> setRecovery(String question, String answer) async {
    _recoveryQuestion = question;
    // Normalize BEFORE hashing so verify's trim+lowercase always matches.
    _recoveryAnswer = _hashSecret(_normalizeSecret(answer));
    await _prefs?.setString('period_recovery_question', question);
    await _prefs?.setString('period_recovery_answer', _recoveryAnswer);
  }

  bool verifyRecoveryAnswer(String answer) {
    final normalized = _normalizeSecret(answer);
    final stored = _recoveryAnswer;
    if (!_verifySecret(normalized, stored)) return false;
    if (_isLegacySecret(stored)) _upgradeRecoveryAnswer(normalized);
    return true;
  }

  /// Upgrade-on-verify (L3): the legacy plaintext PIN was proven correct, so
  /// replace it in memory and in prefs with a salted hash right now instead of
  /// waiting for the next `setPin`. Fire-and-forget — the unlock already
  /// succeeded, so a prefs write failure must never block it.
  void _upgradePin(String verifiedPin) {
    final hashed = _hashSecret(verifiedPin);
    _pinCache = hashed;
    _prefs?.setString('period_pin', hashed).ignore();
  }

  /// Same upgrade path for the recovery answer (already normalized).
  void _upgradeRecoveryAnswer(String verifiedAnswer) {
    final hashed = _hashSecret(verifiedAnswer);
    _recoveryAnswer = hashed;
    _prefs?.setString('period_recovery_answer', hashed).ignore();
  }

  Future<void> resetPin(String newPin) async {
    await setPin(newPin);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool('period_notif_enabled', enabled);
    await _notify();
    if (enabled) {
      await syncPeriodReminders();
    } else {
      try {
        await NotificationService().cancelPeriodReminders();
      } catch (_) {
        // Best effort (plugin unavailable in tests).
      }
      _nextPeriodNotifDateCache = null;
      _ghuslReminderDateCache = null;
      await _prefs?.remove('next_period_notif');
      await _prefs?.remove('ghusl_reminder_date');
    }
  }

  /// Arms the real device notifications: an upcoming-period reminder two days
  /// before the predicted start, and a ghusl reminder the morning after the
  /// predicted end. Also persists the two fire dates so diagnostics/UI can
  /// show what is armed. Safe to call repeatedly — every re-schedule replaces
  /// the previous one (same ids). Failures (no notification permission,
  /// plugin missing in tests) are logged and swallowed; the in-app prediction
  /// still works without notifications.
  Future<void> syncPeriodReminders() async {
    final current = state.value;
    if (current == null || !current.notificationsEnabled) return;

    final prediction = predict();
    if (prediction == null) return;

    final upcomingAt =
        prediction.nextPeriodStart.subtract(const Duration(days: 2));
    // Skip the ghusl reminder while a bleeding record is still active —
    // there is no ghusl yet, and the reminder would be wrong/noisy.
    final hasActiveBleeding = current.records.any((r) => r.isActive);
    // 9:00 local on the day the period is predicted to end → ghusl day.
    final ghuslDay = prediction.currentPeriodEnd.add(const Duration(days: 1));
    final ghuslAt = DateTime(ghuslDay.year, ghuslDay.month, ghuslDay.day, 9);

    _nextPeriodNotifDateCache = prediction.nextPeriodStart;
    _ghuslReminderDateCache = ghuslDay;
    await _prefs?.setString(
        'next_period_notif', prediction.nextPeriodStart.toIso8601String());
    await _prefs?.setString('ghusl_reminder_date', ghuslDay.toIso8601String());

    // Reminder on the predicted start day itself.
    final startDay = DateTime(prediction.nextPeriodStart.year,
        prediction.nextPeriodStart.month, prediction.nextPeriodStart.day, 9);
    // Optional fertile-window reminder (off by default).
    final fertileEnabled = _prefs?.getBool('period_fertile_reminder') ?? false;
    final fertileAt = DateTime(prediction.fertileStart.year,
        prediction.fertileStart.month, prediction.fertileStart.day, 9);

    try {
      await NotificationService().schedulePeriodReminders(
        upcomingAt:
            DateTime(upcomingAt.year, upcomingAt.month, upcomingAt.day, 9),
        upcomingBody: 'پیش‌بینی می‌شود دوره بعدی تا دو روز دیگر شروع شود.',
        ghuslAt: hasActiveBleeding ? null : ghuslAt,
        ghuslBody: 'امروز روز غسل است؛ پس از پاکی، غسل حیض بر شما واجب است.',
        startAt: startDay,
        startBody:
            'امروز روز پیش‌بینی‌شدهٔ شروع دوره است. در صورت شروع، آن را ثبت کنید.',
        fertileAt: fertileEnabled ? fertileAt : null,
        fertileBody: fertileEnabled
            ? 'پنجرهٔ باروری شما آغاز می‌شود (حدود 6 روز).'
            : null,
      );
    } catch (e) {
      AppLogger.warning(
          'PeriodProvider', 'Period reminder scheduling failed: $e');
    }
  }

  /// فعال/غیرفعال کردن یادآوری پنجرهٔ باروری (پیش‌فرض خاموش).
  Future<void> setFertileReminder(bool enabled) async {
    await _prefs?.setBool('period_fertile_reminder', enabled);
    await _notify();
    await syncPeriodReminders();
  }

  bool get fertileReminderEnabled =>
      _prefs?.getBool('period_fertile_reminder') ?? false;

  DateTime? get nextPeriodNotifDate => _nextPeriodNotifDateCache;

  DateTime? get ghuslReminderDate => _ghuslReminderDateCache;

  /// Days of the (Gregorian) [ramadanYear] whose Hijri month is Ramadan (9)
  /// and that fall inside a recorded period. Ramadan is a Hijri month, not the
  /// Gregorian September.
  List<DateTime> getMissedFastingDays(int ramadanYear, {int? hijriOffset}) {
    final offset = hijriOffset ?? 2;
    final missed = <DateTime>[];
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(ramadanYear, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(ramadanYear, month, day);
        final hijri = HijriUtils.hijriFromGreg(
          date.year,
          date.month,
          date.day,
          offset: offset,
        );
        if (hijri.month == 9 && isDateInPeriod(date)) {
          missed.add(date);
        }
      }
    }
    return missed;
  }

  int countMissedDaysInYear(int year) {
    int count = 0;
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        if (isDateInPeriod(DateTime(year, month, day))) {
          count++;
        }
      }
    }
    return count;
  }

  Map<String, dynamic> getRamadanSummary(int ramadanYear, {int? hijriOffset}) {
    final offset = hijriOffset ?? 2;
    final missed = getMissedFastingDays(ramadanYear, hijriOffset: offset);
    final total = countMissedDaysInYear(ramadanYear);
    return {
      'missedDays': missed.length,
      'totalMissedInYear': total,
      'dates': missed,
      'needsQada': missed.isNotEmpty,
    };
  }
}
