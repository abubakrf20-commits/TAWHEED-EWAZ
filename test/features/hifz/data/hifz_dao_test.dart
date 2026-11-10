import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProviderSubscription keepAlive() =>
      container.listen(hifzProvider, (_, __) {});

  HafizModel makeHafiz(String id, String name) => HafizModel(
        id: id,
        name: name,
        createdAt: DateTime(2025),
      );

  group('HifzDao', () {
    test('CRUD hafiz + cascade delete', () async {
      final dao = container.read(hifzDaoProvider);

      await dao.upsertHafiz(makeHafiz('h1', 'محمد'));
      await dao.upsertHafiz(makeHafiz('h2', 'فاطمه'));
      expect((await dao.getAllHafizs()).length, 2);
      expect((await dao.getHafiz('h1'))!.name, 'محمد');

      // Add a lesson + review for h1, then delete the hafiz.
      await dao.upsertLesson(
        HifzLessonModel(
          id: 'l1',
          hafizId: 'h1',
          date: DateTime(2025, 1, 2),
          surahFrom: 2,
          ayahFrom: 1,
          surahTo: 2,
          ayahTo: 6,
          pages: 2,
          createdAt: DateTime(2025, 1, 2),
        ),
      );
      await dao.upsertReview(
        HifzReviewModel(
          id: 'r1',
          hafizId: 'h1',
          date: DateTime(2025, 1, 3),
          type: ReviewType.sabaq,
          surahFrom: 2,
          ayahFrom: 1,
          surahTo: 2,
          ayahTo: 6,
          pages: 2,
          quality: ReviewQuality.excellent,
          createdAt: DateTime(2025, 1, 3),
        ),
      );
      expect((await dao.getLessons('h1')).length, 1);
      expect((await dao.getReviews('h1')).length, 1);

      await dao.deleteHafiz('h1');
      expect(await dao.getHafiz('h1'), isNull);
      expect(await dao.getLessons('h1'), isEmpty);
      expect(await dao.getReviews('h1'), isEmpty);
      expect((await dao.getAllHafizs()).length, 1);
    });

    test('lessons and reviews are ordered newest first', () async {
      final dao = container.read(hifzDaoProvider);
      await dao.upsertHafiz(makeHafiz('h1', 'محمد'));

      for (var d = 1; d <= 3; d++) {
        await dao.upsertLesson(HifzLessonModel(
          id: 'l$d',
          hafizId: 'h1',
          date: DateTime(2025, 1, d),
          surahFrom: 1,
          ayahFrom: 1,
          surahTo: 1,
          ayahTo: 7,
          pages: 1,
          createdAt: DateTime(2025, 1, d),
        ));
      }
      final lessons = await dao.getLessons('h1');
      expect(lessons.first.date, DateTime(2025, 1, 3));
      expect(lessons.last.date, DateTime(2025));
    });
  });

  group('HifzProvider', () {
    test('addHafiz + addLesson updates state and memorizedPages', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      final notifier = container.read(hifzProvider.notifier);

      await notifier.addHafiz(name: 'محمد');
      var state = container.read(hifzProvider);
      expect(state.hafizs, hasLength(1));
      final hafizId = state.hafizs.first.id;

      await notifier.addLesson(
        hafizId: hafizId,
        date: DateTime(2025, 1, 2),
        surahFrom: 2,
        ayahFrom: 1,
        surahTo: 2,
        ayahTo: 6,
        pages: 2,
      );
      await notifier.addLesson(
        hafizId: hafizId,
        date: DateTime(2025, 1, 3),
        surahFrom: 18,
        ayahFrom: 1,
        surahTo: 18,
        ayahTo: 1,
        pages: 1,
      );

      state = container.read(hifzProvider);
      expect(state.lessonsOf(hafizId), hasLength(2));
      expect(state.memorizedPagesOf(hafizId), 3);
    });

    test('addReview persists type and quality; deleteReview removes it',
        () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      final notifier = container.read(hifzProvider.notifier);

      await notifier.addHafiz(name: 'فاطمه');
      final hafizId = container.read(hifzProvider).hafizs.first.id;

      await notifier.addReview(
        hafizId: hafizId,
        date: DateTime(2025, 1, 2),
        type: ReviewType.sabaq,
        surahFrom: 2,
        ayahFrom: 1,
        surahTo: 2,
        ayahTo: 6,
        pages: 2,
        quality: ReviewQuality.weak,
      );
      await notifier.addReview(
        hafizId: hafizId,
        date: DateTime(2025, 1, 3),
        type: ReviewType.murajaah,
        surahFrom: 1,
        ayahFrom: 1,
        surahTo: 1,
        ayahTo: 7,
        pages: 1,
        quality: ReviewQuality.excellent,
        notes: 'نیم جزء',
      );

      var state = container.read(hifzProvider);
      final reviews = state.reviewsOf(hafizId);
      expect(reviews, hasLength(2));
      expect(reviews.where((r) => r.type == ReviewType.sabaq), hasLength(1));
      expect(reviews.where((r) => r.type == ReviewType.murajaah), hasLength(1));
      expect(reviews.first.quality, ReviewQuality.excellent);
      expect(reviews.first.notes, 'نیم جزء');

      await notifier.deleteReview(reviews.first.id, hafizId);
      state = container.read(hifzProvider);
      expect(state.reviewsOf(hafizId), hasLength(1));
    });

    test('multiple hafizs stay isolated', () async {
      final sub = keepAlive();
      addTearDown(sub.close);
      final notifier = container.read(hifzProvider.notifier);

      await notifier.addHafiz(name: 'محمد');
      await notifier.addHafiz(name: 'فاطمه');
      final state = container.read(hifzProvider);
      expect(state.hafizs, hasLength(2));
      final id1 = state.hafizs[0].id;
      final id2 = state.hafizs[1].id;

      await notifier.addLesson(
        hafizId: id1,
        date: DateTime(2025, 1, 2),
        surahFrom: 2,
        ayahFrom: 1,
        surahTo: 2,
        ayahTo: 6,
        pages: 2,
      );
      expect(container.read(hifzProvider).lessonsOf(id1), hasLength(1));
      expect(container.read(hifzProvider).lessonsOf(id2), isEmpty);
      expect(container.read(hifzProvider).memorizedPagesOf(id1), 2);
      expect(container.read(hifzProvider).memorizedPagesOf(id2), 0);
    });
  });
}
