import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/quran/data/daos/ayah_highlight_dao.dart';

final ayahHighlightDaoProvider = Provider<AyahHighlightDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AyahHighlightDao(db);
});

/// Whole-table watch: the mushaf page builder keys its render on the set of
/// highlight colors, so any add/remove/re-color here re-renders exactly the
/// affected pages. Row count stays tiny (user-highlighted ayahs only).
final ayahHighlightsProvider =
    StreamProvider<List<AyahHighlightTableData>>((ref) {
  final dao = ref.watch(ayahHighlightDaoProvider);
  return dao.watchAll();
});
