import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';

/// Holds the initial hafiz read until the gate opens.
class _GatedHifzDao extends HifzDao {
  _GatedHifzDao(super.db);

  Completer<void>? gate;
  bool _held = false;

  @override
  Future<List<HafizModel>> getAllHafizs() async {
    final rows = await super.getAllHafizs();
    final g = gate;
    // Only the initial load is held: the post-add reload must read the new
    // row, exactly like the real database.
    if (g != null && !_held) {
      _held = true;
      await g.future;
    }
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _GatedHifzDao dao;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = _GatedHifzDao(db);
    container = ProviderContainer(overrides: [
      hifzDaoProvider.overrideWithValue(dao),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a hafiz added while the initial load is in flight survives it',
      () async {
    // The load assigns the whole snapshot, so an add made in that window used
    // to be erased by the older DB state the read had captured.
    final gate = Completer<void>();
    dao.gate = gate;
    container.listen(hifzProvider, (_, __) {});

    final pending =
        container.read(hifzProvider.notifier).addHafiz(name: 'محمد');

    // Let the add land. Pre-fix it runs immediately; with the guard it waits
    // for the load, so poll with a bound instead of assuming an ordering.
    for (var i = 0;
        i < 100 && container.read(hifzProvider).hafizs.isEmpty;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    // Release the load AFTER the write: its captured snapshot predates the
    // add, so only the guard keeps it from wiping the new row.
    gate.complete();
    await pending;
    dao.gate = null;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final state = container.read(hifzProvider);
    expect(state.loaded, isTrue);
    expect(state.hafizs.map((h) => h.name).toList(), ['محمد']);
    expect(state.selectedHafizId, isNotNull);
  });
}
