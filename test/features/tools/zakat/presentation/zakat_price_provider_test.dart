import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_price_store.dart';
import 'package:tawheeed/features/tools/zakat/presentation/providers/zakat_price_provider.dart';

SavedZakatPrices _prices({required int ageMs}) => SavedZakatPrices(
      goldPerGram: 30000000,
      silverPerGram: 800000,
      dollarPrice: 1900000,
      updatedAt: DateTime.now().millisecondsSinceEpoch - ageMs,
    );

/// `build()` kicks off the store load asynchronously; wait for it so the test
/// never races the initial read.
Future<void> _settle(ProviderContainer container) async {
  for (var i = 0; i < 50 && container.read(zakatPriceProvider).loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('staleness policy', () {
    test('no saved prices is stale', () {
      expect(const ZakatPriceState().isStale, isTrue);
    });

    test('prices younger than the policy window are fresh', () {
      final state = ZakatPriceState(
          saved: _prices(ageMs: const Duration(hours: 2).inMilliseconds));
      expect(state.isStale, isFalse);
    });

    test('prices older than the policy window are stale', () {
      // The screen used to allow 7 days while the provider used 24h, so a
      // 5-day-old price set looked fine on screen but stale in the state.
      final state = ZakatPriceState(
          saved: _prices(ageMs: const Duration(days: 5).inMilliseconds));
      expect(state.isStale, isTrue);
      expect(ZakatPriceState.staleAfter, const Duration(hours: 24));
    });

    test('a failed refresh over stored prices marks them stale', () {
      // The core of the "stale prices reported as success" bug: the figures on
      // screen were the previous ones, yet nothing flagged them.
      final state = ZakatPriceState(
        saved: _prices(ageMs: 0),
        refreshFailed: true,
      );
      expect(state.isStale, isTrue);
    });
  });

  group('saveManual', () {
    test('rejects a negative price and keeps the previous set', () async {
      await ZakatPriceStore.save(
        goldPerGram: 30000000,
        silverPerGram: 800000,
        dollarPrice: 1900000,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _settle(container);

      await container.read(zakatPriceProvider.notifier).saveManual(
            goldPerGram: -5,
            silverPerGram: 800000,
            dollarPrice: 1900000,
          );

      final state = container.read(zakatPriceProvider);
      expect(state.error, isNotNull);
      final stored = await ZakatPriceStore.load();
      expect(stored!.goldPerGram, 30000000);
    });

    test('persists a valid set and clears the failed-refresh flag', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _settle(container);

      await container.read(zakatPriceProvider.notifier).saveManual(
            goldPerGram: 31000000,
            silverPerGram: 810000,
            dollarPrice: 1950000,
          );

      final state = container.read(zakatPriceProvider);
      expect(state.saved!.goldPerGram, 31000000);
      expect(state.error, isNull);
      expect(state.refreshFailed, isFalse);
      expect(state.isStale, isFalse);
    });

    test('a save made before the initial load lands wins over the stored set',
        () async {
      // build() starts the store read and returns `loading: true`; the save is
      // issued in that same turn. The load must complete first (the guard the
      // provider now awaits), so the figures on screen are the saved ones.
      await ZakatPriceStore.save(
        goldPerGram: 30000000,
        silverPerGram: 800000,
        dollarPrice: 1900000,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(zakatPriceProvider);
      final pending = container.read(zakatPriceProvider.notifier).saveManual(
            goldPerGram: 31000000,
            silverPerGram: 810000,
            dollarPrice: 1950000,
          );
      await pending;

      final state = container.read(zakatPriceProvider);
      expect(state.loading, isFalse);
      expect(state.saved!.goldPerGram, 31000000);
      expect(state.error, isNull);
    });
  });
}
