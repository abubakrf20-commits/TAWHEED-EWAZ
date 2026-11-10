import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/books/data/daos/book_dao.dart';
import 'package:tawheeed/features/books/data/daos/book_bookmark_dao.dart';
import 'package:tawheeed/features/reminders/data/daos/reminder_dao.dart';
import 'package:tawheeed/features/khatm/data/daos/khatm_dao.dart';
import 'package:tawheeed/features/adhkar/duas/data/daos/dua_dao.dart';
import 'package:tawheeed/features/adhkar/domain/repositories/azkar_repository.dart'
    as repo;
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_repository.dart';

final mockSettingsDaoProvider =
    Provider<SettingsDao>((ref) => MockSettingsDao());
final mockAzkarStatusDaoProvider =
    Provider<AzkarStatusDao>((ref) => MockAzkarStatusDao());
final mockTasbihDaoProvider = Provider<TasbihDao>((ref) => MockTasbihDao());
final mockPeriodRecordDaoProvider =
    Provider<PeriodRecordDao>((ref) => MockPeriodRecordDao());
final mockPrayerTrackerDaoProvider =
    Provider<PrayerTrackerDao>((ref) => MockPrayerTrackerDao());
final mockNoteDaoProvider = Provider<NoteDao>((ref) => MockNoteDao());
final mockBookDaoProvider = Provider<BookDao>((ref) => MockBookDao());
final mockBookBookmarkDaoProvider =
    Provider<BookBookmarkDao>((ref) => MockBookBookmarkDao());
final mockReminderDaoProvider =
    Provider<ReminderDao>((ref) => MockReminderDao());
final mockKhatmDaoProvider = Provider<KhatmDao>((ref) => MockKhatmDao());
final mockDuaDaoProvider = Provider<DuaDao>((ref) => MockDuaDao());
final mockDailyStatusDaoProvider =
    Provider<DailyStatusDao>((ref) => MockDailyStatusDao());

class MockSettingsDao implements SettingsDao {
  AppSettingsTableData? _stored;
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<AppSettingsTableData?> getSettings(String id) async => _stored;

  @override
  Future<void> upsertSettings(AppSettingsTableData settings) async {
    _stored = settings;
  }
}

class MockAzkarStatusDao implements AzkarStatusDao {
  final _store = <String, ZikrStatusRecordTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  String _key(String id, String date) => '$id|$date';

  @override
  Future<ZikrStatusRecordTableData?> getStatus(String id, String date) async {
    return _store[_key(id, date)];
  }

  @override
  Future<void> setStatus(ZikrStatusRecordTableData status) async {
    _store[_key(status.id, status.date)] = status;
  }

  @override
  Future<void> setStatusesBatch(
      List<ZikrStatusRecordTableData> statuses) async {
    for (final s in statuses) {
      _store[_key(s.id, s.date)] = s;
    }
  }

  @override
  Future<List<ZikrStatusRecordTableData>> getStatusesForDate(
      String date) async {
    return _store.values.where((s) => s.date == date).toList();
  }

  @override
  Future<List<ZikrStatusRecordTableData>> getAll() async {
    return _store.values.toList();
  }

  @override
  Future<List<ZikrStatusRecordTableData>> getStatusesForDateRange(
      String startDate, String endDate) async {
    return _store.values
        .where((s) =>
            s.date.compareTo(startDate) >= 0 && s.date.compareTo(endDate) <= 0)
        .toList();
  }

  @override
  Future<void> deleteStatus(String id, String date) async {
    _store.remove(_key(id, date));
  }

  @override
  Future<int> deleteDateRange(String startDate, String endDate) async {
    final before = _store.length;
    _store.removeWhere((_, s) =>
        s.date.compareTo(startDate) >= 0 && s.date.compareTo(endDate) <= 0);
    return before - _store.length;
  }

  @override
  Future<void> restoreRows(List<ZikrStatusRecordTableData> rows) async {
    for (final r in rows) {
      _store[_key(r.id, r.date)] = r;
    }
  }

  @override
  Future<int> countByStatus(int statusIndex) async {
    return _store.values.where((s) => s.statusIndex == statusIndex).length;
  }
}

class MockTasbihDao implements TasbihDao {
  final _store = <String, TasbihTableData>{};
  final _dhikrStore = <String, List<TasbihDhikrTableData>>{};
  final _settingsStore = <String, String>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<TasbihTableData>> getAllTasbihs() async => _store.values.toList();

  @override
  Future<TasbihTableData?> getTasbih(String id) async => _store[id];

  @override
  Future<void> upsertTasbih(TasbihTableData tasbih) async {
    _store[tasbih.id] = tasbih;
  }

  @override
  Future<void> deleteTasbih(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  @override
  Future<void> incrementLifetimeAndCount(String id) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(
        count: existing.count + 1,
        totalLifetimeCount: existing.totalLifetimeCount + 1,
      );
    }
  }

  @override
  Future<void> addLifetimeAndCount(String id, int amount) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(
        count: existing.count + amount,
        totalLifetimeCount: existing.totalLifetimeCount + amount,
      );
    }
  }

  @override
  Future<void> resetCount(String id) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(count: 0);
    }
  }

  @override
  Future<void> resetAllCounts() async {
    for (final entry in _store.entries.toList()) {
      _store[entry.key] = entry.value.copyWith(count: 0);
    }
  }

  @override
  Future<List<TasbihModel>> getAllDomain() async {
    return _store.values.map(_toDomain).toList();
  }

  @override
  Future<void> saveDomain(TasbihModel model) async {
    _store[model.id] = _toData(model);
  }

  @override
  Future<void> updateTarget(String id, int target) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(target: target);
    }
  }

  @override
  Future<void> rename(String id, String text) async {}

  @override
  Future<void> seedDefaults() async {
    final now = DateTime.now();
    // Mirrors the production seeds: every default dhikr counts to 100.
    final defaults = [
      ('سبحان الله', 100),
      ('الحمد لله', 100),
      ('الله اکبر', 100),
      ('لا اله الا الله', 100),
      ('استغفر الله', 100),
      ('السلام علیک یا رسول الله', 100),
      ('استغفر الله العظیم واتوب الیه', 100),
      ('لا حول ولا قوة إلا بالله العلی العظیم', 100),
    ];
    for (int i = 0; i < defaults.length; i++) {
      final (dhikr, count) = (defaults[i].$1, defaults[i].$2);
      _store['default_$i'] = TasbihTableData(
        id: 'default_$i',
        dhikrText: dhikr,
        count: 0,
        target: count,
        totalLifetimeCount: 0,
        createdAt: now.subtract(Duration(seconds: defaults.length - i)),
        isDefault: true,
        isEnabled: true,
      );
    }
  }

  TasbihModel _toDomain(TasbihTableData row) {
    return TasbihModel(
      id: row.id,
      name: row.dhikrText,
      targetDhikr: row.dhikrText,
      targetCount: row.target,
      currentCount: row.count,
      totalLifetimeCount: row.totalLifetimeCount,
      createdAt: row.createdAt,
      isDefault: row.isDefault,
      isEnabled: row.isEnabled,
    );
  }

  TasbihTableData _toData(TasbihModel m) {
    return TasbihTableData(
      id: m.id,
      dhikrText: m.name,
      count: m.currentCount,
      target: m.targetCount,
      totalLifetimeCount: m.totalLifetimeCount,
      createdAt: m.createdAt,
      isDefault: m.isDefault,
      isEnabled: m.isEnabled,
    );
  }

  Future<List<TasbihDhikrTableData>> getDhikrList(String tasbihId) async {
    return _dhikrStore[tasbihId] ?? [];
  }

  Future<void> setDhikrList(String tasbihId, List<String> dhikrs) async {
    _dhikrStore[tasbihId] = dhikrs
        .map((d) => TasbihDhikrTableData(
              id: '${tasbihId}_$d',
              tasbihId: tasbihId,
              dhikrText: d,
            ))
        .toList();
  }

  @override
  Future<String?> getSetting(String key) async => _settingsStore[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settingsStore[key] = value;
  }
}

class MockPeriodRecordDao implements PeriodRecordDao {
  final _store = <int, PeriodRecordTableData>{};
  int _nextId = 1;
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<PeriodRecordTableData>> getAllRecords() async =>
      _store.values.toList();

  @override
  Future<void> upsertRecord(PeriodRecordTableData record) async {
    _store[record.id] = record;
  }

  @override
  Future<void> insertRecord(PeriodRecordTableCompanion record) async {
    final id = _nextId++;
    final newRecord = PeriodRecordTableData(
      id: id,
      startDate: record.startDate.value,
      periodLength: record.periodLength.value,
      createdAt: record.createdAt.value,
      endDate: record.endDate.value,
      recordType: record.recordType.value,
      istihadhaType: record.istihadhaType.value,
      flow: record.flow.value,
      notes: record.notes.value,
    );
    _store[id] = newRecord;
  }

  @override
  Future<void> deleteRecord(int id) async {
    _store.remove(id);
  }
}

class MockPrayerTrackerDao implements PrayerTrackerDao {
  final _store = <String, PrayerTrackerTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  String _key(String date, String prayerKey) => '$date|$prayerKey';

  @override
  Future<List<PrayerTrackerTableData>> getAllForDate(String date) async {
    return _store.values.where((r) => r.date == date).toList();
  }

  @override
  Future<PrayerTrackerTableData?> getForDateAndKey(
      String date, String prayerKey) async {
    return _store[_key(date, prayerKey)];
  }

  @override
  Future<void> upsert(PrayerTrackerTableData record) async {
    _store[_key(record.date, record.prayerKey)] = record;
  }

  @override
  Future<List<PrayerTrackerTableData>> getAllInDateRange(
      String startDate, String endDate) async {
    return _store.values
        .where((r) =>
            r.date.compareTo(startDate) >= 0 && r.date.compareTo(endDate) <= 0)
        .toList();
  }

  @override
  Future<Map<String, int>> getAllAsMap() async {
    return {
      for (final r in _store.values) 'pt_${r.date}_${r.prayerKey}': r.value ?? 0
    };
  }

  @override
  Future<void> deleteForDate(String date) async {
    _store.removeWhere((_, r) => r.date == date);
  }

  @override
  Future<int> deleteDateRange(String startDate, String endDate) async {
    final before = _store.length;
    _store.removeWhere((_, r) =>
        r.date.compareTo(startDate) >= 0 && r.date.compareTo(endDate) <= 0);
    return before - _store.length;
  }

  @override
  Future<void> restoreRows(List<PrayerTrackerTableData> rows) async {
    for (final r in rows) {
      _store[_key(r.date, r.prayerKey)] = r;
    }
  }

  @override
  Future<void> deleteForDateAndKey(String date, String prayerKey) async {
    _store.remove(_key(date, prayerKey));
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class MockNoteDao implements NoteDao {
  final _store = <String, NoteTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<NoteTableData>> getAllNotes() async => _store.values.toList();

  @override
  Future<NoteTableData?> getNote(String id) async => _store[id];

  @override
  Future<void> upsertNote(NoteTableData note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

class MockDailyStatusDao implements DailyStatusDao {
  @override
  AppDatabase get db => throw UnimplementedError();

  final _store = <String, DailyStatusTableData>{};

  @override
  Future<DailyStatusTableData?> get(
      String category, String date, String key) async {
    return _store['$category|$date|$key'];
  }

  @override
  Future<int?> getValue(String category, String date, String key) async {
    return _store['$category|$date|$key']?.value;
  }

  @override
  Future<void> set(String category, String date, String key, int value) async {
    _store['$category|$date|$key'] = DailyStatusTableData(
        category: category, date: date, key: key, value: value);
  }

  @override
  Future<void> increment(
      String category, String date, String key, int amount) async {
    final existing = await getValue(category, date, key);
    await set(category, date, key, (existing ?? 0) + amount);
  }

  @override
  Future<void> setBool(
      String category, String date, String key, bool value) async {
    await set(category, date, key, value ? 1 : 0);
  }

  @override
  Future<bool> getBool(String category, String date, String key) async {
    return (await getValue(category, date, key)) == 1;
  }

  @override
  Future<List<DailyStatusTableData>> getAllForCategory(String category) async {
    return _store.values.where((r) => r.category == category).toList();
  }

  @override
  Future<List<DailyStatusTableData>> getAllForDate(
      String category, String date) async {
    return _store.values
        .where((r) => r.category == category && r.date == date)
        .toList();
  }

  @override
  Future<List<DailyStatusTableData>> getAllInDateRange(
      String category, String startDate, String endDate) async {
    return _store.values
        .where((r) =>
            r.category == category &&
            r.date.compareTo(startDate) >= 0 &&
            r.date.compareTo(endDate) <= 0)
        .toList();
  }

  @override
  Future<Map<String, int>> getAllAsMap(String category) async {
    final records = await getAllForCategory(category);
    final map = <String, int>{};
    for (final r in records) {
      map[r.date] = r.value;
    }
    return map;
  }

  @override
  Future<Map<String, int>> getTasbihDailyForDate(String date) async {
    const prefix = 'tasbih_daily_';
    final map = <String, int>{};
    for (final r in _store.values) {
      if (r.date == date &&
          r.category.startsWith(prefix) &&
          r.category != 'tasbih_daily') {
        map[r.category.substring(prefix.length)] = r.value;
      }
    }
    return map;
  }

  @override
  Future<Map<String, Map<String, int>>> getAllGroupedByDate(
      String category) async {
    final records = await getAllForCategory(category);
    final map = <String, Map<String, int>>{};
    for (final r in records) {
      map.putIfAbsent(r.date, () => {})[r.key] = r.value;
    }
    return map;
  }

  @override
  Future<int> sumForDateRange(
      String category, String startDate, String endDate) async {
    final records = await getAllInDateRange(category, startDate, endDate);
    return records.fold<int>(0, (sum, r) => sum + r.value);
  }

  @override
  Future<void> deleteForCategory(String category) async {
    _store.removeWhere((k, r) => r.category == category);
  }

  @override
  Future<int> deleteCategories(List<String> categories) async {
    final before = _store.length;
    _store.removeWhere((k, r) => categories.contains(r.category));
    return before - _store.length;
  }

  @override
  Future<void> deleteForDate(String category, String date) async {
    _store.removeWhere((k, r) => r.category == category && r.date == date);
  }

  @override
  Future<int> deleteCategoriesInDateRange(
      List<String> categories, String startDate, String endDate) async {
    final before = _store.length;
    _store.removeWhere((k, r) =>
        categories.contains(r.category) &&
        r.date.compareTo(startDate) >= 0 &&
        r.date.compareTo(endDate) <= 0);
    return before - _store.length;
  }

  @override
  Future<int> deleteCategoryPrefixInDateRange(
      String prefix, String startDate, String endDate) async {
    final before = _store.length;
    _store.removeWhere((k, r) =>
        r.category.startsWith(prefix) &&
        r.date.compareTo(startDate) >= 0 &&
        r.date.compareTo(endDate) <= 0);
    return before - _store.length;
  }

  @override
  Future<List<DailyStatusTableData>> getRowsForRangeBackup(
      List<String> categories, String prefix, String startDate,
      String endDate) async {
    return _store.values
        .where((r) =>
            (categories.contains(r.category) ||
                r.category.startsWith(prefix)) &&
            r.date.compareTo(startDate) >= 0 &&
            r.date.compareTo(endDate) <= 0)
        .toList();
  }

  @override
  Future<void> restoreRows(List<DailyStatusTableData> rows) async {
    for (final r in rows) {
      _store['${r.category}|${r.date}|${r.key}'] = r;
    }
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class MockSettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();

  /// Number of updateSettings() calls — the slider-drag coalescing tests
  /// count the writes, not just the final value.
  int updateCount = 0;

  void setMockSettings(AppSettings settings) {
    _settings = settings;
  }

  AppSettings getMockSettings() => _settings;

  @override
  Future<AppSettings> getSettings() async => _settings;

  @override
  Future<void> updateSettings(AppSettings settings) async {
    updateCount++;
    _settings = settings;
  }

  @override
  Future<void> resetSettings() async {
    _settings = const AppSettings();
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {}

  @override
  Future<bool> isOnboardingCompleted() async => false;

  @override
  Future<void> setPremiumStatus(bool isPremium) async {}

  @override
  Future<bool> isPremium() async => false;

  @override
  Stream<AppSettings> watchSettings() async* {
    yield _settings;
  }
}

class MockBookDao implements BookDao {
  final _store = <String, BookTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<BookTableData>> getAllBooks() async => _store.values.toList();

  @override
  Future<BookTableData?> getBook(String id) async => _store[id];

  @override
  Future<void> upsertBook(BookTableData book) async {
    _store[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

class MockBookBookmarkDao implements BookBookmarkDao {
  final _bookIds = <String>[];

  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<BookBookmarkTableData>> getBookmarks(String bookId) async => [];

  @override
  Future<BookBookmarkTableData?> getBookmark(int id) async => null;

  @override
  Future<bool> isPageBookmarked(String bookId, int page) async => false;

  @override
  Future<int> addBookmark(String bookId, int page,
      {String? note, String highlightColor = ''}) async {
    _bookIds.add(bookId);
    return _bookIds.length;
  }

  @override
  Future<void> removeBookmark(int id) async {}

  @override
  Future<void> removeBookmarkByPage(String bookId, int page) async {}

  @override
  Future<void> updateBookmarkNote(int id, String? note) async {}

  @override
  Future<void> updateBookmarkSortOrder(int id, int sortOrder) async {}

  @override
  Future<void> updateBookmarkPage(int id, int page) async {}

  @override
  Future<int> getBookmarkCount(String bookId) async => 0;

  @override
  Future<Set<String>> getAllBookmarkedBookIds() async => _bookIds.toSet();

  @override
  Future<void> removeBookmarksForBook(String bookId) async {
    _bookIds.remove(bookId);
  }
}

class MockReminderDao implements ReminderDao {
  final _store = <String, ReminderTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<ReminderTableData>> getAllReminders() async =>
      _store.values.toList();

  @override
  Future<ReminderTableData?> getReminder(String id) async => _store[id];

  @override
  Future<void> upsertReminder(Insertable<ReminderTableData> reminder) async {
    if (reminder is ReminderTableData) {
      _store[reminder.id] = reminder;
    } else if (reminder is ReminderTableCompanion) {
      _store[reminder.id.value] = ReminderTableData(
        id: reminder.id.value,
        title: reminder.title.value,
        note: reminder.note.value,
        hour: reminder.hour.value,
        minute: reminder.minute.value,
        daysOfWeek: reminder.daysOfWeek.value,
        isEnabled: reminder.isEnabled.value,
        createdAt: reminder.createdAt.value,
        advanceMinutes: reminder.advanceMinutes.value,
        useSound: reminder.useSound.value,
        updatedAt: reminder.updatedAt.value,
        soundName: reminder.soundName.value,
        specificDate: reminder.specificDate.value,
        prayerRef: reminder.prayerRef.value,
        prayerOffsetMinutes: reminder.prayerOffsetMinutes.value,
      );
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

class MockKhatmDao implements KhatmDao {
  final _store = <String, KhatmTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<KhatmTableData>> getAllKhatms() async => _store.values.toList();

  @override
  Future<KhatmTableData?> getKhatm(String id) async => _store[id];

  @override
  Future<void> upsertKhatm(KhatmTableData khatm) async {
    _store[khatm.id] = khatm;
  }

  @override
  Future<void> deleteKhatm(String id) async {
    _store.remove(id);
  }

  Future<void> clearAll() async {
    _store.clear();
  }
}

class MockDuaDao implements DuaDao {
  final _store = <String, DuaTableData>{};
  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<List<DuaTableData>> getAllDuas() async => _store.values.toList();

  @override
  Future<DuaTableData?> getDua(String id) async => _store[id];

  @override
  Future<void> upsertDua(DuaTableData dua) async {
    _store[dua.id] = dua;
  }

  @override
  Future<void> upsertBatch(List<DuaTableData> duads) async {
    for (final d in duads) {
      _store[d.id] = d;
    }
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  @override
  Future<void> deleteDua(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> setFavorite(String id, bool favorite) async {
    final existing = await getDua(id);
    if (existing != null) {
      _store[id] = existing.copyWith(isFavorite: favorite);
    }
  }
}

class MockAzkarRepository implements repo.AzkarRepository {
  List<ZikrItem> _items = [];
  final Map<String, repo.ZikrStatus> _statuses = {};

  void setItems(List<ZikrItem> items) {
    _items = items;
  }

  Future<void> setMockStatus(String id, repo.ZikrStatus status) async {
    _statuses[id] = status;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<ZikrItem>> loadAllAzkar() async => _items;

  @override
  List<ZikrItem> getByPeriod(PrayerPeriod period) {
    return _items.where((z) => z.period == period).toList();
  }

  @override
  repo.ZikrStatus getStatus(String id) {
    return _statuses[id] ?? repo.ZikrStatus.pending;
  }

  @override
  Future<void> setStatus(String id, repo.ZikrStatus status) async {
    _statuses[id] = status;
  }

  @override
  Future<void> setStatusBatch(List<String> ids, repo.ZikrStatus status) async {
    for (final id in ids) {
      _statuses[id] = status;
    }
  }

  @override
  Map<String, int> periodStats(PrayerPeriod period) {
    final periodItems = _items.where((z) => z.period == period).toList();
    int done = 0;
    for (final z in periodItems) {
      if (_statuses[z.id] == repo.ZikrStatus.done) done++;
    }
    return {'total': periodItems.length, 'done': done, 'skipped': 0};
  }

  @override
  Map<String, int> get todayStats {
    int total = 0, done = 0;
    for (final period in PrayerPeriod.values) {
      final s = periodStats(period);
      total += s['total']!;
      done += s['done']!;
    }
    return {'total': total, 'done': done, 'skipped': 0};
  }

  @override
  Future<void> resetDay() async {}
}
