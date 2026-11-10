import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/screens/dorar_hadith_details_screen.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/screens/dorar_hadith_search_screen.dart';

const _hadith = DorarHadithEntity(
  id: '42',
  hadithText: 'إنما الأعمال بالنيات',
  narrator: 'عمر بن الخطاب',
  mohdith: 'البخاري',
  book: 'صحيح البخاري',
  degree: 'صحيح البخاري',
  hadithNumber: '1',
  canViewDetails: true,
);

const _similar = DorarHadithEntity(
  id: '7',
  hadithText: 'مشابه نمونه',
  degree: 'حسن',
);

const _alternative = DorarHadithEntity(
  id: '8',
  hadithText: 'بدیل نمونه',
  degree: 'صحيح',
);

class _FakeDorarRepository implements DorarHadithRepository {
  DorarHadithResultsPage nextPage = const DorarHadithResultsPage(items: []);
  Object? searchError;
  Completer<DorarHadithResultsPage>? pendingSearch;
  String? explanation = 'شرح نمونه';
  final Set<String> favorites = {};
  final List<DorarHadithFilter> usedFilters = [];

  @override
  Future<DorarHadithResultsPage> search({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  }) {
    usedFilters.add(filter);
    final error = searchError;
    if (error != null) return Future.error(error);
    final pending = pendingSearch;
    if (pending != null) return pending.future;
    return Future.value(nextPage);
  }

  @override
  Future<DorarHadithDetail> getHadithDetails(String id) async =>
      const DorarHadithDetail(
        hadith: _hadith,
        similar: [_similar],
        authenticAlternative: _alternative,
      );

  @override
  Future<String?> getExplanation(String hadithText) async => explanation;

  @override
  Future<void> saveFavorite(DorarHadithEntity hadith) async =>
      favorites.add(hadith.id);

  @override
  Future<void> removeFavorite(String id) async => favorites.remove(id);

  @override
  Future<Set<String>> favoriteIds() async => {...favorites};
}

Widget _wrap(Widget child, {required _FakeDorarRepository repo}) {
  return ProviderScope(
    // provider مخزن عمداً async است (مسیر کش باید پیش از ساخت کلاینت درر
    // تثبیت شود)، پس override هم باید شکل async داشته باشد و نه یک مقدار
    // آماده؛ به همین دلیل overrideWith و نه overrideWithValue.
    overrides: [
      dorarHadithRepositoryProvider.overrideWith((ref) async => repo)
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _runSearch(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.tap(find.byTooltip('جستجو'));
}

void main() {
  late _FakeDorarRepository repo;

  setUp(() {
    repo = _FakeDorarRepository();
  });

  group('DorarHadithSearchScreen حالات', () {
    testWidgets('حالت اولیه: راهنمای جستجو بدون فراخوانی شبکه', (tester) async {
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('متن حدیث را جستجو کنید'), findsOneWidget);
    });

    testWidgets('loading → data: کارت نتایج نمایش داده می‌شود', (tester) async {
      final completer = Completer<DorarHadithResultsPage>();
      repo.pendingSearch = completer;
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();

      await _runSearch(tester, 'الصلاة');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const DorarHadithResultsPage(items: [_hadith], hasNextPage: true),
      );
      repo.pendingSearch = null;
      await tester.pumpAndSettle();

      expect(find.text('إنما الأعمال بالنيات'), findsOneWidget);
      expect(find.text('صحيح البخاري'), findsOneWidget);
      expect(find.text('نمایش نتایج بیشتر'), findsOneWidget);
    });

    testWidgets('حالت خالی: نتیجه‌ای یافت نشد', (tester) async {
      repo.nextPage = const DorarHadithResultsPage(items: []);
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();

      await _runSearch(tester, 'کلمه ناموجود');
      await tester.pumpAndSettle();

      expect(find.text('نتیجه‌ای یافت نشد'), findsOneWidget);
    });

    testWidgets('حالت خطا: پیام فارسی + دکمه تلاش دوباره', (tester) async {
      repo.searchError = const DorarHadithFailure(
          'برای جستجوی احادیث باید به اینترنت متصل باشید.');
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();

      await _runSearch(tester, 'الصلاة');
      await tester.pumpAndSettle();

      expect(
        find.text('برای جستجوی احادیث باید به اینترنت متصل باشید.'),
        findsOneWidget,
      );
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });

    testWidgets('query کوتاه → خطای اعتبارسنجی بدون تماس با سرویس',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();

      await _runSearch(tester, 'اب');
      await tester.pumpAndSettle();

      expect(find.textContaining('حداقل 3 حرف'), findsOneWidget);
    });
  });

  group('کارت حدیث', () {
    Future<void> pumpResult(WidgetTester tester) async {
      repo.nextPage = const DorarHadithResultsPage(items: [_hadith]);
      await tester
          .pumpWidget(_wrap(const DorarHadithSearchScreen(), repo: repo));
      await tester.pumpAndSettle();
      await _runSearch(tester, 'النية');
      await tester.pumpAndSettle();
    }

    testWidgets('ذخیره در المفضلة با یک ضربه', (tester) async {
      await pumpResult(tester);

      await tester.tap(find.byTooltip('حفظ در المفضلة'));
      await tester.pumpAndSettle();

      expect(repo.favorites, {'42'});
      expect(find.byTooltip('حذف از المفضلة'), findsOneWidget);
    });

    testWidgets('شرح در BottomSheet نمایش داده می‌شود', (tester) async {
      await pumpResult(tester);

      await tester.tap(find.byTooltip('شرح الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('شرح الحديث'), findsOneWidget);
      expect(find.text('شرح نمونه'), findsOneWidget);
    });

    testWidgets('فیلتر درجه صحت جستجو را با فیلتر تازه تکرار می‌کند',
        (tester) async {
      await pumpResult(tester);
      final searchesBefore = repo.usedFilters.length;

      await tester.tap(find.text('ضعیف'));
      await tester.pumpAndSettle();

      expect(repo.usedFilters.length, greaterThan(searchesBefore));
      expect(repo.usedFilters.last, DorarHadithFilter.weak);
    });
  });

  testWidgets('flow کامل: جستجو → جزئیات → شرح/مشابه/بدیل', (tester) async {
    repo.nextPage = const DorarHadithResultsPage(items: [_hadith]);
    final router = GoRouter(
      initialLocation: RouteNames.dorarHadithSearch,
      routes: [
        GoRoute(
          path: RouteNames.dorarHadithSearch,
          builder: (context, state) => const DorarHadithSearchScreen(),
        ),
        GoRoute(
          path: RouteNames.dorarHadithDetails,
          builder: (context, state) => DorarHadithDetailsScreen(
            hadithId: state.pathParameters['id'] ?? '',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dorarHadithRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // تایپ query → نتایج
    await _runSearch(tester, 'النية');
    await tester.pumpAndSettle();
    expect(find.text('إنما الأعمال بالنيات'), findsOneWidget);

    // ورود به جزئیات
    await tester.tap(find.text('جزئیات'));
    await tester.pumpAndSettle();

    expect(find.text('شرح الحديث'), findsOneWidget);
    expect(find.text('شرح نمونه'), findsOneWidget);
    expect(find.text('بدیل نمونه'), findsOneWidget);
    expect(find.text('حدیث بدیل صحیح'), findsOneWidget);
    expect(find.text('مشابه نمونه'), findsOneWidget);
    expect(find.text('الأحاديث المشابهة'), findsOneWidget);
  });
}
