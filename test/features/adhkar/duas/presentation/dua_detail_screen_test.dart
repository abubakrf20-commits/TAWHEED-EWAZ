import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/duas/data/daos/dua_dao.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/providers/duas_provider.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_detail_screen.dart';

import '../../../../core/database/mock_daos.dart';

class _FakeHesnDbService implements HesnDbService {
  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<List<HesnChapter>> getChapters() async => const [
        HesnChapter(id: 1, number: 1, title: 'اذکار الاستيقاظ', kind: 'chapter'),
      ];

  @override
  Future<List<HesnItem>> getAllItems() async => const [
        HesnItem(
          id: 1,
          chapterId: 1,
          seq: 1,
          no: 1,
          arabic: 'الحمد لله',
          translation: 'ستایش برای خداست',
        ),
      ];

  @override
  Future<List<HesnItem>> getItemsForChapter(int chapterId) async =>
      await getAllItems();

  @override
  Future<List<HesnSection>> getSections() async => const [];

  @override
  void close() {}
}

void main() {
  late MockDuaDao mockDao;

  setUp(() {
    mockDao = MockDuaDao();
  });

  const snapshot = DuaModel(
    id: 'c1s1',
    title: 'اذکار الاستيقاظ',
    arabicText: 'الحمد لله',
    translation: 'ستایش برای خداست',
    transliteration: '',
    source: '',
    category: 'اذکار الاستيقاظ',
  );

  Future<void> pumpDetail(WidgetTester tester, DuaModel dua) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          duaDaoProvider.overrideWithValue(mockDao),
          hesnContentProvider.overrideWithValue(_FakeHesnDbService()),
        ],
        child: MaterialApp(home: DuaDetailScreen(dua: dua)),
      ),
    );
    // Let the provider's content sync land before interacting.
    await tester.pumpAndSettle();
  }

  testWidgets('the heart repaints from the provider after a toggle',
      (tester) async {
    await pumpDetail(tester, snapshot);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // The pushed model is a snapshot; only the live provider row can flip it.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect((await mockDao.getDua('c1s1'))!.isFavorite, isTrue);
  });

  DuaModel longDua() => DuaModel(
        id: 'long-dua',
        title: 'دعای بلند برای آزمون',
        arabicText:
            List.filled(8, 'اللهم إنا نسألك العفو والعافية').join(' '),
        translation:
            List.filled(8, 'خدایا از تو عفو و عافیت می‌خواهیم').join(' '),
        source: '',
        category: 'خانه',
        guidance: [
          for (var i = 0; i < 6; i++)
            'رهنمود شمارهٔ $i در این دعا آمده است.',
        ],
        benefits: [
          for (var i = 0; i < 6; i++)
            'فایدهٔ شمارهٔ $i در این دعا آمده است.',
        ],
        refs: const ['منبع ویژه در پایان دعا'],
      );

  Future<void> pumpAt(WidgetTester tester, DuaModel dua,
      {String query = ''}) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          duaDaoProvider.overrideWithValue(mockDao),
          hesnContentProvider.overrideWithValue(_FakeHesnDbService()),
        ],
        child: MaterialApp(
          home: DuaDetailScreen(dua: dua, highlightQuery: query),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens scrolled to the block carrying the searched word',
      (tester) async {
    await pumpAt(tester, longDua(), query: 'ویژه');

    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(offset, greaterThan(0));
  });

  testWidgets('starts at the top when no word was searched', (tester) async {
    await pumpAt(tester, longDua());

    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(offset, 0);
  });

  testWidgets('falls back to the snapshot when the provider has no such row',
      (tester) async {
    await pumpDetail(
      tester,
      const DuaModel(
        id: 'not-in-content',
        title: 'دعای بیرون از فهرست',
        arabicText: 'سبحان الله',
        translation: 'پاک است خدا',
        transliteration: '',
        source: '',
        category: 'خانه',
        isFavorite: true,
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
