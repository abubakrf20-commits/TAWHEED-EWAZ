import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/adhkar/duas/data/daos/dua_dao.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/providers/duas_provider.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import '../../../../../core/database/mock_daos.dart';

class _FakeHesnDbService implements HesnDbService {
  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<List<HesnChapter>> getChapters() async => const [
        HesnChapter(
            id: 1, number: 1, title: 'اذکار الاستيقاظ', kind: 'chapter'),
      ];

  @override
  Future<List<HesnItem>> getAllItems() async => const [
        HesnItem(
          id: 1,
          chapterId: 1,
          seq: 1,
          no: 1,
          lead: 'قال رسول الله ص:',
          arabic: 'الحمد لله',
          translation: 'ستایش برای خداست',
          words: 'الحمد: ستایش',
          guidance: 'رهنمود اول',
          benefits: 'فایده اول\nفایده دوم',
          refs: 'بخاری ۱/۱۱۳',
        ),
        HesnItem(
          id: 2,
          chapterId: 1,
          seq: 2,
          no: 2,
          arabic: 'سبحان الله',
          translation: 'پاک است خدا',
        ),
      ];

  @override
  Future<List<HesnItem>> getItemsForChapter(int chapterId) async =>
      await getAllItems();

  // Not an interface member anymore — kept for direct test calls.
  Future<List<HesnItem>> search(String query, {int limit = 100}) async => [];

  @override
  Future<List<HesnSection>> getSections() async => const [
        HesnSection(id: 1, title: 'مقدمه', body: 'متن مقدمه'),
      ];

  @override
  void close() {}
}

/// Holds `getAllItems` until the gate opens, keeping the content sync in
/// flight while the test toggles a favorite.
class _GatedHesnDbService extends _FakeHesnDbService {
  _GatedHesnDbService(this.gate);

  final Completer<void> gate;

  @override
  Future<List<HesnItem>> getAllItems() async {
    final items = await super.getAllItems();
    await gate.future;
    return items;
  }
}

void main() {
  late ProviderContainer container;
  late MockDuaDao mockDao;

  setUp(() {
    mockDao = MockDuaDao();
    container = ProviderContainer(overrides: [
      duaDaoProvider.overrideWithValue(mockDao),
      hesnContentProvider.overrideWithValue(_FakeHesnDbService()),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns initial DuasState with isLoading true', () {
    final state = container.read(duasProvider);
    expect(state.isLoading, isTrue);
    expect(state.duas, isEmpty);
    expect(state.error, isEmpty);
  });

  test('favorites returns empty when no duas in state', () {
    const state = DuasState(isLoading: false);
    expect(state.favorites, isEmpty);
  });

  test('favorites returns only favorited duas', () {
    final duas = [
      const DuaModel(
          id: '1',
          title: 'Fav',
          arabicText: 'text',
          transliteration: '',
          translation: '',
          source: '',
          category: 'general',
          isFavorite: true),
      const DuaModel(
          id: '2',
          title: 'Not',
          arabicText: 'text',
          transliteration: '',
          translation: '',
          source: '',
          category: 'general'),
    ];
    final state = DuasState(duas: duas, isLoading: false);
    expect(state.favorites.length, equals(1));
    expect(state.favorites[0].id, equals('1'));
  });

  test('byCategory returns duas in given category', () {
    final duas = [
      const DuaModel(
          id: '1',
          title: 'Morning',
          arabicText: 'text',
          transliteration: '',
          translation: '',
          source: '',
          category: 'morning'),
      const DuaModel(
          id: '2',
          title: 'Evening',
          arabicText: 'text',
          transliteration: '',
          translation: '',
          source: '',
          category: 'evening'),
    ];
    final state = DuasState(duas: duas, isLoading: false);
    expect(state.byCategory('morning').length, equals(1));
    expect(state.byCategory('evening').length, equals(1));
    expect(state.byCategory('unknown'), isEmpty);
  });

  test('toggleFavorite toggles isFavorite via DAO', () async {
    container.listen(duasProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    final notifier = container.read(duasProvider.notifier);
    await notifier.toggleFavorite('c1s1');
    var stored = await mockDao.getDua('c1s1');
    expect(stored!.isFavorite, isTrue);
    await notifier.toggleFavorite('c1s1');
    stored = await mockDao.getDua('c1s1');
    expect(stored!.isFavorite, isFalse);
  });

  test('a favorite toggled while the content sync is in flight is applied',
      () async {
    // The sync rewrites every row when it lands, and the toggle used to read
    // the row it assumed the sync had already created. Held here at
    // `getAllItems`, so the toggle arrives first and must wait for the sync.
    final gate = Completer<void>();
    final gatedContainer = ProviderContainer(overrides: [
      duaDaoProvider.overrideWithValue(mockDao),
      hesnContentProvider.overrideWithValue(_GatedHesnDbService(gate)),
    ]);
    addTearDown(gatedContainer.dispose);
    gatedContainer.listen(duasProvider, (_, __) {});
    final pending =
        gatedContainer.read(duasProvider.notifier).toggleFavorite('c1s1');
    gate.complete();
    await pending;
    final stored = await mockDao.getDua('c1s1');
    expect(stored, isNotNull);
    expect(stored!.isFavorite, isTrue);
    expect(gatedContainer.read(duasProvider).isLoading, isFalse);
  });

  test('init loads content and joins rich commentary fields', () async {
    container.listen(duasProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    final state = container.read(duasProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isEmpty);
    expect(state.duas.length, equals(2));
    expect(state.duas[0].id, equals('c1s1'));
    expect(state.duas[0].lead, equals('قال رسول الله ص:'));
    expect(state.duas[0].words, equals(['الحمد: ستایش']));
    expect(state.duas[0].benefits.length, equals(2));
    expect(state.duas[0].refs, equals(['بخاری ۱/۱۱۳']));
    expect(state.duas[0].hasCommentary, isTrue);
    expect(state.duas[1].hasCommentary, isFalse);
    expect(state.categories, equals(['اذکار الاستيقاظ']));
  });

  test('sync preserves favorites and drops stale rows', () async {
    await mockDao.upsertDua(const DuaTableData(
      id: 'c1s1',
      title: 'اذکار الاستيقاظ',
      arabicText: 'old',
      translation: 'old',
      reference: '',
      category: 'اذکار الاستيقاظ',
      isFavorite: true,
    ));
    await mockDao.upsertDua(const DuaTableData(
      id: 'stale-id',
      title: 'removed from content',
      arabicText: 'x',
      translation: 'x',
      reference: '',
      category: 'g',
      isFavorite: true,
    ));
    container.listen(duasProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    final stored = await mockDao.getDua('c1s1');
    expect(stored!.isFavorite, isTrue);
    expect(stored.arabicText, equals('الحمد لله'));
    expect(await mockDao.getDua('stale-id'), isNull);
  });

  test('copyWith creates a modified DuasState', () {
    const state = DuasState(isLoading: false);
    expect(state.isLoading, isFalse);
    final modified = state.copyWith(isLoading: true);
    expect(modified.isLoading, isTrue);
    expect(modified.duas, isEmpty);
    expect(modified.error, isEmpty);
  });
}
