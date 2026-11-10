import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/dorar_hadith/domain/entities/dorar_hadith_entity.dart';
import 'package:tawheeed/features/dorar_hadith/domain/repositories/dorar_hadith_repository.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/providers/dorar_hadith_provider.dart';

const _staleItem = DorarHadithEntity(id: '1', hadithText: 'نتيجة قديمة');
const _freshItem = DorarHadithEntity(id: '2', hadithText: 'نتيجة جديدة');

class _CountingRepository implements DorarHadithRepository {
  final List<String> queries = [];
  DorarHadithResultsPage nextPage =
      const DorarHadithResultsPage(items: [_staleItem]);
  Completer<DorarHadithResultsPage>? pending;

  @override
  Future<DorarHadithResultsPage> search({
    required String query,
    int page = 1,
    DorarHadithFilter filter = DorarHadithFilter.all,
  }) {
    queries.add(query);
    final blocked = pending;
    if (blocked != null) return blocked.future;
    return Future.value(nextPage);
  }

  @override
  Future<DorarHadithDetail> getHadithDetails(String id) =>
      throw UnimplementedError();

  @override
  Future<String?> getExplanation(String hadithText) =>
      throw UnimplementedError();

  @override
  Future<void> saveFavorite(DorarHadithEntity hadith) =>
      throw UnimplementedError();

  @override
  Future<void> removeFavorite(String id) => throw UnimplementedError();

  @override
  Future<Set<String>> favoriteIds() => throw UnimplementedError();
}

void main() {
  late _CountingRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _CountingRepository();
    container = ProviderContainer(overrides: [
      dorarHadithRepositoryProvider.overrideWith((ref) async => repo),
    ]);
  });

  tearDown(() => container.dispose());

  /// listen پیش از read تا نوتیفایر autoDispose بین فراخوانی‌ها دور نشود.
  DorarHadithSearch notifier() {
    container.listen(dorarHadithSearchProvider, (_, __) {});
    return container.read(dorarHadithSearchProvider.notifier);
  }

  test('دیبانس: تایپ پیاپی فقط آخرین عبارت را بعد از تأخیر می‌فرستد', () async {
    notifier()
      ..search('الصلا')
      ..search('الصلاة على')
      ..search('الصلاة على النبي');
    expect(repo.queries, isEmpty);

    await Future<void>.delayed(
      DorarHadithSearch.debounceDelay + const Duration(milliseconds: 150),
    );
    expect(repo.queries, ['الصلاة على النبي']);
  });

  test('پرس‌وجوی خالی یا فقط‌فاصله هیچ جستجویی نمی‌فرستد', () async {
    notifier()
      ..search('')
      ..search('   ')
      ..searchNow('');
    await Future<void>.delayed(
      DorarHadithSearch.debounceDelay + const Duration(milliseconds: 150),
    );
    expect(repo.queries, isEmpty);
    expect(container.read(dorarHadithSearchProvider).value, isEmpty);
  });

  test('پاسخ دیررس جستجوی قبلی نتیجه جدید را خراب نمی‌کند و خطا نشان نمی‌دهد',
      () async {
    final stale = Completer<DorarHadithResultsPage>();
    repo.pending = stale;
    notifier().searchNow('قديمة');
    await Future<void>.delayed(Duration.zero);

    repo
      ..pending = null
      ..nextPage = const DorarHadithResultsPage(items: [_freshItem]);
    notifier().searchNow('جديدة');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dorarHadithSearchProvider).value, [_freshItem]);

    // پاسخ نسل قدیمی دیرتر از موعد و این بار با خطا برمی‌گردد.
    stale.completeError(const DorarHadithFailure('قديمة'));
    await Future<void>.delayed(Duration.zero);
    final state = container.read(dorarHadithSearchProvider);
    expect(state.hasError, isFalse);
    expect(state.value, [_freshItem]);
  });
}
