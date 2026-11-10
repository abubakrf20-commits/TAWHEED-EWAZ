import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_units_repository.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The bundled unit table (`assets/data/units.json`).
final unitsCatalogProvider = FutureProvider<UnitsCatalog>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/units.json');
    return UnitsCatalog.parse(raw);
  } catch (e) {
    AppLogger.warning('UnitsCatalog', 'bundle read failed: $e');
    return const UnitsCatalog(categories: []);
  }
});

final localUnitsRepositoryProvider = Provider<LocalUnitsRepository>((ref) {
  return DriftLocalUnitsRepository(ref.watch(appDatabaseProvider));
});

/// The user's own local-unit rows, merged over the shipped defaults by the
/// view (the defaults are never written to the table).
class LocalUnitsStore extends AsyncNotifier<List<LocalUnit>> {
  LocalUnitsRepository get _repo => ref.read(localUnitsRepositoryProvider);

  @override
  Future<List<LocalUnit>> build() => _repo.load();

  Future<void> save(LocalUnit unit) async {
    await _repo.save(unit);
    state = AsyncData(await _repo.load());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.load());
  }

  Future<void> resetToDefaults() async {
    await _repo.resetToDefaults();
    state = AsyncData(await _repo.load());
  }
}

final localUnitsStoreProvider =
    AsyncNotifierProvider<LocalUnitsStore, List<LocalUnit>>(
  LocalUnitsStore.new,
);
