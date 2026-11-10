import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_price_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing has been saved yet', () async {
    expect(await ZakatPriceStore.load(), isNull);
  });

  test('save persists gold, silver and dollar prices with a timestamp',
      () async {
    await ZakatPriceStore.save(
      goldPerGram: 30000000,
      silverPerGram: 800000,
      dollarPrice: 1900000,
    );

    final saved = await ZakatPriceStore.load();
    expect(saved, isNotNull);
    expect(saved!.goldPerGram, 30000000);
    expect(saved.silverPerGram, 800000);
    expect(saved.dollarPrice, 1900000);
    expect(saved.updatedAt, greaterThan(0));
  });

  test('a later save overwrites the previous values', () async {
    await ZakatPriceStore.save(
      goldPerGram: 25000000,
      silverPerGram: 3500000,
      dollarPrice: 1000000,
    );
    await ZakatPriceStore.save(
      goldPerGram: 40000000,
      silverPerGram: 1200000,
      dollarPrice: 2100000,
    );

    final saved = await ZakatPriceStore.load();
    expect(saved!.goldPerGram, 40000000);
    expect(saved.silverPerGram, 1200000);
    expect(saved.dollarPrice, 2100000);
  });

  test('prices are stored per currency and never leak across units', () async {
    await ZakatPriceStore.save(
      goldPerGram: 25000000,
      silverPerGram: 3500000,
      dollarPrice: 1900000,
    );

    // دلار: هیچ قیمتی ذخیره نشده — عدد تومانی نباید به دلار تفسیر شود.
    expect(await ZakatPriceStore.load(currencyCode: 'USD'), isNull);

    await ZakatPriceStore.save(
      goldPerGram: 62,
      silverPerGram: 0.9,
      dollarPrice: 0,
      currencyCode: 'USD',
    );

    final usd = await ZakatPriceStore.load(currencyCode: 'USD');
    expect(usd!.goldPerGram, 62);
    expect(usd.currencyCode, 'USD');

    // و تومان دست‌نخورده می‌ماند.
    final toman = await ZakatPriceStore.load();
    expect(toman!.goldPerGram, 25000000);
    expect(toman.currencyCode, 'IRT');
  });

  test('legacy toman keys (saved before multi-currency) still load', () async {
    SharedPreferences.setMockInitialValues({
      'zakat_gold_price_per_gram': 26000000.0,
      'zakat_silver_price_per_gram': 3600000.0,
      'zakat_dollar_price': 1950000.0,
      'zakat_prices_updated_at': 1700000000000,
    });

    final saved = await ZakatPriceStore.load();
    expect(saved!.goldPerGram, 26000000);
    expect(saved.silverPerGram, 3600000);
    expect(saved.dollarPrice, 1950000);
    expect(saved.updatedAt, 1700000000000);
  });
}
