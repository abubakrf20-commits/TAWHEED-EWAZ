import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';

class _FlakyDao extends DangiDao {
  _FlakyDao(super.db);

  bool fail = true;

  @override
  Future<List<DangiGroupModel>> getAllGroups() async {
    if (fail) throw StateError('dangi offline');
    return super.getAllGroups();
  }
}

void main() {
  late AppDatabase db;
  late _FlakyDao dao;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = _FlakyDao(db);
    container = ProviderContainer(overrides: [
      dangiDaoProvider.overrideWithValue(dao),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a failed first load is a retryable error, not an endless spinner',
      () async {
    final errorSeen = Completer<void>();
    final sub = container.listen<DangiState>(dangiProvider, (_, next) {
      if (next.loadError != null && !errorSeen.isCompleted) {
        errorSeen.complete();
      }
    });
    addTearDown(sub.close);

    container.read(dangiProvider.notifier);
    await errorSeen.future;

    final failed = container.read(dangiProvider);
    expect(failed.loaded, isFalse);
    expect(failed.loadError, isA<StateError>());
    expect(failed.groups, isEmpty);
  });

  test('reload after a failure clears the error and shows the groups',
      () async {
    final errorSeen = Completer<void>();
    final sub = container.listen<DangiState>(dangiProvider, (_, next) {
      if (next.loadError != null && !errorSeen.isCompleted) {
        errorSeen.complete();
      }
    });
    addTearDown(sub.close);

    final notifier = container.read(dangiProvider.notifier);
    await errorSeen.future;
    expect(container.read(dangiProvider).loadError, isNotNull);

    // A group written while the load was broken must appear once the read works
    // — the retry is a real re-read, not a replay of the failed snapshot.
    final now = DateTime.now();
    await DangiDao(db).createGroupWithMembers(
      DangiGroupModel(
        id: 'g1',
        name: 'سفر',
        colorHex: '#00ACC1',
        createdAt: now,
      ),
      [
        DangiMemberModel(
          id: 'm1',
          groupId: 'g1',
          name: 'علی',
          createdAt: now,
        ),
        DangiMemberModel(
          id: 'm2',
          groupId: 'g1',
          name: 'حسین',
          createdAt: now,
        ),
      ],
    );

    dao.fail = false;
    await notifier.reload();

    final loaded = container.read(dangiProvider);
    expect(loaded.loaded, isTrue);
    expect(loaded.loadError, isNull);
    expect(loaded.groups, hasLength(1));
    expect(loaded.groups.first.name, 'سفر');
    expect(loaded.membersOf('g1'), hasLength(2));
  });
}
