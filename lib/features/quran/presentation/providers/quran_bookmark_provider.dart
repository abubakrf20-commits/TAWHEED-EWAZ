import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/quran/data/daos/quran_bookmark_dao.dart';

final quranBookmarkDaoProvider = Provider<QuranBookmarkDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return QuranBookmarkDao(db);
});

final quranBookmarksProvider = StreamProvider((ref) {
  final dao = ref.watch(quranBookmarkDaoProvider);
  return dao.watchAll();
});
