import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live market prices fetched from TGJU (tgju.org), converted to toman.
class ZakatLivePrices {
  /// 24-karat gold price per gram (toman).
  final double goldPerGram;

  /// Pure silver (999) price per gram (toman).
  final double silverPerGram;

  /// US Dollar price (toman).
  final double dollarPrice;

  final DateTime fetchedAt;

  const ZakatLivePrices({
    required this.goldPerGram,
    required this.silverPerGram,
    required this.dollarPrice,
    required this.fetchedAt,
  });
}

/// Fetches gold/silver/dollar prices from TGJU's public JSON endpoint.
///
/// The endpoint returns prices in rial; they are divided by 10 to match the
/// toman unit used across the zakat calculator.
class ZakatLivePriceService {
  ZakatLivePriceService._();

  static const String _url = 'https://call.tgju.org/ajax.json';

  static Future<ZakatLivePrices> fetch(
      {Duration timeout = const Duration(seconds: 12)}) async {
    final resp = await http.get(Uri.parse(_url)).timeout(timeout);
    if (resp.statusCode != 200) {
      throw http.ClientException('HTTP ${resp.statusCode}');
    }
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final current = body['current'];
    if (current is! Map<String, dynamic>) {
      throw const FormatException('unexpected payload');
    }

    double toman(String key) {
      final entry = current[key];
      final p = entry is Map<String, dynamic> ? entry['p'] : null;
      final raw = double.tryParse('$p'.replaceAll(',', ''));
      if (raw == null || raw <= 0) {
        throw FormatException('missing price for $key');
      }
      return raw / 10;
    }

    return ZakatLivePrices(
      goldPerGram: toman('geram24'),
      silverPerGram: toman('silver_999'),
      dollarPrice: toman('price_dollar_rl'),
      fetchedAt: DateTime.now(),
    );
  }
}
