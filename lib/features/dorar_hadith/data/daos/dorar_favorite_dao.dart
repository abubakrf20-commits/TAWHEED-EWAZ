import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';

final dorarFavoriteDaoProvider = Provider<DorarFavoriteDao>((ref) {
  return DorarFavoriteDao(ref.read(appDatabaseProvider));
});

class DorarFavoriteDao {
  final AppDatabase db;

  DorarFavoriteDao(this.db);

  Future<List<FavoriteDorarHadithTableData>> getFavorites() =>
      (db.select(db.favoriteDorarHadithTable)
            ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]))
          .get();

  Future<void> upsertFavorite(DorarHadithEntity hadith) =>
      db.into(db.favoriteDorarHadithTable).insert(
            FavoriteDorarHadithTableCompanion.insert(
              id: hadith.id,
              hadithText: hadith.hadithText,
              narrator: Value(hadith.narrator),
              mohdith: Value(hadith.mohdith),
              book: Value(hadith.book),
              hadithNumber: Value(hadith.hadithNumber),
              degree: Value(hadith.degree),
            ),
            mode: InsertMode.insertOrIgnore,
          );

  Future<void> deleteFavorite(String id) =>
      (db.delete(db.favoriteDorarHadithTable)..where((t) => t.id.equals(id)))
          .go();
}
