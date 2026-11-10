import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import '../../../../../core/database/mock_daos.dart';

/// Applies renames the way the real DAO does (one `dhikrText` column) and
/// records every call, so the test can tell a write from a silent skip.
class _RenamingTasbihDao extends MockTasbihDao {
  final List<String> renamedTo = [];

  @override
  Future<void> rename(String id, String text) async {
    renamedTo.add(text);
    final row = await getTasbih(id);
    if (row == null) return;
    await upsertTasbih(row.copyWith(dhikrText: text));
  }
}

/// Refuses the write, so the notifier's rollback path is what runs.
class _RenameFailingTasbihDao extends MockTasbihDao {
  @override
  Future<void> rename(String id, String text) async {
    throw StateError('rename failed');
  }
}

Future<void> _seedOne(MockTasbihDao dao) => dao.upsertTasbih(TasbihTableData(
      id: 'a',
      dhikrText: 'سبحان الله',
      count: 7,
      target: 33,
      totalLifetimeCount: 900,
      createdAt: DateTime(2026),
      isDefault: false,
      isEnabled: true,
    ));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  ProviderContainer build(MockTasbihDao dao) => ProviderContainer(overrides: [
        tasbihDaoProvider.overrideWithValue(dao),
        dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
      ]);

  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  tearDown(() => container.dispose());

  test('rename moves BOTH text fields and reaches the DAO', () async {
    final dao = _RenamingTasbihDao();
    await _seedOne(dao);
    container = build(dao);
    final before = (await container.read(tasbihProvider.future)).single;

    await container.read(tasbihProvider.notifier).rename('a', '  سبحان الله وبحمده  ');

    final after = container.read(tasbihProvider).value!.single;
    // `_toDomain` derives both from the single dhikrText column, and the dial
    // prints `targetDhikr` while the widget push reads it too — a rename that
    // moved one of them would show two different names.
    expect(after.name, 'سبحان الله وبحمده');
    expect(after.targetDhikr, 'سبحان الله وبحمده');
    expect(dao.renamedTo, ['سبحان الله وبحمده']);
    // Nothing else may move: a typo fix must not cost a single count.
    expect(after.currentCount, before.currentCount);
    expect(after.totalLifetimeCount, before.totalLifetimeCount);
    expect(after.targetCount, before.targetCount);
  });

  test('a failed rename rolls both fields back', () async {
    final dao = _RenameFailingTasbihDao();
    await _seedOne(dao);
    container = build(dao);
    await container.read(tasbihProvider.future);

    await container.read(tasbihProvider.notifier).rename('a', 'نصاب جدید');

    final after = container.read(tasbihProvider).value!.single;
    expect(after.name, 'سبحان الله');
    expect(after.targetDhikr, 'سبحان الله');
  });

  test('an empty or unchanged name never reaches the DAO', () async {
    final dao = _RenamingTasbihDao();
    await _seedOne(dao);
    container = build(dao);
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);

    await notifier.rename('a', '   ');
    await notifier.rename('a', 'سبحان الله');
    await notifier.rename('missing', 'چیز دیگر');

    expect(dao.renamedTo, isEmpty);
    expect(container.read(tasbihProvider).value!.single.targetDhikr,
        'سبحان الله');
  });

  test('the app wins the widget merge right after a rename', () async {
    final dao = _RenamingTasbihDao();
    await _seedOne(dao);
    container = build(dao);
    await container.read(tasbihProvider.future);

    await container.read(tasbihProvider.notifier).rename('a', 'نصاب');
    // `_markAppChanged` is fire-and-forget; the prefs write is scheduled.
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    // The native per-dhikr map is keyed by TEXT, so the old text lingers there
    // until the next snapshot. Stamping the app as newest is what stops that
    // stale key from being imported back as a duplicate dhikr.
    expect(prefs.getInt('tasbih_widget_last_changed_at'), isNotNull);
  });
}
