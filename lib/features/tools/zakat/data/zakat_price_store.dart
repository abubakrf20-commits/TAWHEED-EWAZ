import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/models/app_currency.dart';

/// Persists the user's last entered market prices for the zakat calculator
/// (gold, silver, dollar) so the nisab calculation stays accurate between
/// sessions without requiring the user to re-type today's rates every time.
///
/// Prices are stored **per currency**: 25,000,000 means nothing on its own, and
/// re-reading a toman figure as dollars would move the nisab by orders of
/// magnitude. Toman keeps the historical unsuffixed keys, so existing installs
/// read their saved prices unchanged; every other unit gets its own slot and
/// therefore never inherits toman numbers.
class ZakatPriceStore {
  ZakatPriceStore._();

  static const String _kGold = 'zakat_gold_price_per_gram';
  static const String _kSilver = 'zakat_silver_price_per_gram';
  static const String _kDollar = 'zakat_dollar_price';
  static const String _kUpdatedAt = 'zakat_prices_updated_at';

  /// Toman keeps the legacy key so prices saved before multi-currency support
  /// are still found; any other unit is namespaced by its stable code.
  static String _key(String base, String currencyCode) {
    return currencyCode == AppCurrency.toman.code
        ? base
        : '${base}_$currencyCode';
  }

  /// Returns the last saved prices for [currencyCode], or `null` if the user
  /// never saved any **in that currency**.
  static Future<SavedZakatPrices?> load({String currencyCode = 'IRT'}) async {
    final prefs = await SharedPreferences.getInstance();
    final gold = prefs.getDouble(_key(_kGold, currencyCode));
    if (gold == null) return null;
    return SavedZakatPrices(
      goldPerGram: gold,
      silverPerGram: prefs.getDouble(_key(_kSilver, currencyCode)) ?? 0,
      dollarPrice: prefs.getDouble(_key(_kDollar, currencyCode)) ?? 0,
      updatedAt: prefs.getInt(_key(_kUpdatedAt, currencyCode)) ?? 0,
      currencyCode: currencyCode,
    );
  }

  static Future<void> save({
    required double goldPerGram,
    required double silverPerGram,
    required double dollarPrice,
    String currencyCode = 'IRT',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key(_kGold, currencyCode), goldPerGram);
    await prefs.setDouble(_key(_kSilver, currencyCode), silverPerGram);
    await prefs.setDouble(_key(_kDollar, currencyCode), dollarPrice);
    await prefs.setInt(
        _key(_kUpdatedAt, currencyCode), DateTime.now().millisecondsSinceEpoch);
  }
}

class SavedZakatPrices {
  final double goldPerGram;
  final double silverPerGram;
  final double dollarPrice;
  final int updatedAt;

  /// واحدی که این قیمت‌ها با آن وارد شده‌اند — تا هرگز به واحد دیگری تفسیر
  /// نشوند.
  final String currencyCode;

  const SavedZakatPrices({
    required this.goldPerGram,
    required this.silverPerGram,
    required this.dollarPrice,
    required this.updatedAt,
    this.currencyCode = 'IRT',
  });
}
