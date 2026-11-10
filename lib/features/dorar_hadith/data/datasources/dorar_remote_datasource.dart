import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, LazyDatabase;
import 'package:drift/native.dart';
import 'package:dorar_hadith/dorar_hadith.dart';
import 'package:meta/meta.dart';
// CacheDatabase از barrel عمومی پکیج export نشده، ولی تنها راهاندازی
// connection سفارشی برای cache.db است. بدون این، پکیج cache.db را در
// Directory.current می‌سازد که روی Android قابل نوشتن نیست.
// ignore: implementation_imports
import 'package:dorar_hadith/src/database/cache_database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'browser_user_agent_client.dart';

import '../../domain/entities/dorar_hadith_entity.dart';
import '../models/dorar_hadith_model.dart';

/// نگه‌دارندهٔ promise تنظیم کش تا چند فراخوان همزمان (startup و provider)
/// دقیقاً یک بار کار را انجام دهند. پرچم سادهٔ `bool` برای این کافی نبود چون
/// بین «شروع کار» و «اتمام کار» بازه‌ای وجود دارد که فراخوان دوم می‌توانست
/// factory را دوباره بنویسد یا از نیمه‌کاره رد شود.
Future<void>? _cacheSetup;

/// cache.db پاسخ‌های درر را به پوشهٔ پشتیبان برنامه می‌برد (مانند
/// ensureInitialized برای rawi.db) تا مسیر پیش‌فرضِ غیرقابل‌ write روی
/// Android باز نشود. کش و TTL پیش‌فرض پکیج (7 روز / 100 ورودی) دست‌نخورده
/// می‌ماند.
///
/// نکتهٔ ترتیب: `CacheDatabase()` همان لحظهٔ ساخته‌شدن، factory را capture
/// می‌کند. بنابراین این تابع باید پیش از ساخته‌شدن هر `DorarClient`
/// کامل شود؛ provider کلاینت هم دقیقاً همین ترتیب را رعایت می‌کند.
Future<void> configureDorarCache() {
  return _cacheSetup ??= _configureDorarCache();
}

Future<void> _configureDorarCache() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'dorar_cache.db'));
  CacheDatabase.configureConnection(
    () => DatabaseConnection(
      LazyDatabase(() async => NativeDatabase(file)),
    ),
  );
}

/// قرارداد دسترسی به سرویس درر — قابل fake کردن در تست‌ها.
abstract class DorarHadithRemoteDataSource {
  Future<DorarSearchPageModel> search({
    required String query,
    required int page,
    required DorarHadithFilter filter,
  });

  Future<DorarHadithModel> getById(String hadithId);

  Future<List<DorarHadithModel>> getSimilarHadiths(String hadithId);

  Future<DorarHadithModel?> getAuthenticAlternative(String hadithId);

  Future<String?> getExplanation(String hadithText);
}

class DorarRemoteDataSource implements DorarHadithRemoteDataSource {
  final DorarClient _client;

  /// لایهٔ HTTP خام با UA مرورگر — برای خواندن HTML صفحهٔ نتایج سایت.
  /// خودِ پکیج `searchHadithDetailed` نتایج را با سلکتورهای قدیمی
  /// (`.hadith-info`/`#home`) پارس میکند، ولی dorar.net در ۲۰۲۶ مارکاپ صفحهٔ
  /// جستجو را به ردیف‌های `.border-bottom` با شناسهٔ هَش (مثل `j0j8uiR3`)
  /// عوض کرد؛ آن پارسر حالا صفر نتیجه برمی‌گرداند. پس URL را همان پکیج
  /// می‌سازیم (فیلتر درجه/صفحه درست بماند) و فقط پارس را خودمان روی ساختار
  /// جدید انجام می‌دهیم تا شناسهٔ حدیث برای صفحهٔ جزئیات حفظ شود.
  final DorarHttpClient _http =
      DorarHttpClient(client: BrowserUserAgentClient());

  DorarRemoteDataSource(this._client);

  /// تعداد نتایج هر صفحه در جستجوی سایت (~۳۰). رسیدن به این عدد یعنی
  /// صفحهٔ بعدی هم احتمالاً هست.
  static const int _sitePageSize = 30;

  @override
  Future<DorarSearchPageModel> search({
    required String query,
    required int page,
    required DorarHadithFilter filter,
  }) async {
    final params = HadithSearchParams(
      value: query,
      page: page,
      degrees: _degreesFor(filter),
    );

    // جستجوی جزئیاتی (صفحهٔ سایت) hadithId برمی‌گرداند؛ همان شناسه‌ای که
    // صفحهٔ جزئیات، مشابهات و بدیلِ صحیح به آن نیاز دارند.
    try {
      final qp = QuerySerializer.serializeHadithParams(params);
      final rawUrl =
          DorarEndpoints.hadithSearchSite(qp, specialist: params.specialist);
      // www → ۳۰۱ به دامنهٔ بدون www؛ مستقیم روی مقصد نهایی برو.
      final url =
          rawUrl.replaceFirst('https://www.dorar.net', 'https://dorar.net');
      final html = await _http.getHtml(url);
      final items = parseSiteResults(html);
      if (items.isNotEmpty) {
        return DorarSearchPageModel(
          items: items,
          hasNextPage: items.length >= _sitePageSize,
          totalResults: items.length,
        );
      }
      // ساختار دوباره عوض شده؟ به API سبکِ پکیج (بدون شناسه) برگرد تا کاربر
      // حداقل متن احادیث را ببیند، نه صفحهٔ خالی.
      return _searchViaApiFallback(params);
    } on DorarException catch (e) {
      // «هیچ حدیثی در پاسخ نیست» حالت عادیِ نبودِ نتیجه است، نه خطا.
      if (e.message.toLowerCase().contains('no hadith')) {
        return const DorarSearchPageModel.empty();
      }
      rethrow;
    }
  }

  /// صفحهٔ نتایج سایت را روی ردیف‌های `.border-bottom` پارس می‌کند. هر حدیث
  /// در HTML دو بار می‌آید (نسخهٔ ساده و نسخهٔ دارای دکمهٔ کپی)؛ با
  /// `putIfAbsent` روی شناسه dedup می‌کنیم و فقط ردیف کامل (متن + ref) را
  /// نگه می‌داریم — ترتیب نتایج حفظ می‌شود.
  @visibleForTesting
  static List<DorarHadithModel> parseSiteResults(String html) {
    final rows = html.split('<div class="border-bottom');
    final byId = <String, DorarHadithModel>{};
    final idRe = RegExp(r'/h/([A-Za-z0-9]{6,})');
    final textRe =
        RegExp(r'<h5 class="h5-responsive[^"]*"[^>]*>(.*?)</h5>', dotAll: true);
    final refRe =
        RegExp('data-clipboard-text="<ref>(.*?)</ref>"', dotAll: true);
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final id = idRe.firstMatch(row)?.group(1);
      final textMatch = textRe.firstMatch(row);
      final refMatch = refRe.firstMatch(row);
      if (id == null || textMatch == null || refMatch == null) continue;
      final text = _cleanText(textMatch.group(1) ?? '');
      if (text.isEmpty) continue;
      final ref = _decodeEntities(refMatch.group(1) ?? '');
      final segments = ref.split('<br>');
      byId.putIfAbsent(
        id,
        () => DorarHadithModel(
          hadithText: text,
          narrator: _refField(segments, 'الراوي') ?? '',
          mohdith: _refField(segments, 'المحدث') ?? '',
          book: _refField(segments, 'المصدر') ?? '',
          numberOrPage: _refField(segments, 'الصفحة أو الرقم') ?? '',
          degree: _refField(segments, 'خلاصة حكم المحدث') ?? '',
          hadithId: id,
        ),
      );
    }
    return byId.values.toList();
  }

  /// مقدار یک برچسب در بلوک `<ref>`؛ تا کاراکتر `|` یا پایان بخش می‌خواند.
  static String? _refField(List<String> segments, String label) {
    for (final seg in segments) {
      final i = seg.indexOf('$label:');
      if (i < 0) continue;
      var value = seg.substring(i + label.length + 1);
      final bar = value.indexOf('|');
      if (bar >= 0) value = value.substring(0, bar);
      final cleaned = _cleanText(value);
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  /// تگ‌های HTML را حذف، موجودیت‌ها را decode و فاصله‌ها را یکی می‌کند؛
  /// پیشوند شمارهٔ حدیث («1 - ») هم کنار گذاشته می‌شود.
  static String _cleanText(String input) => _decodeEntities(input)
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'^\s*[0-9٠-٩]+\s*[-–]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _decodeEntities(String input) {
    var s = input;
    const named = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&#039;': "'",
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };
    named.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    s = s.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return s;
  }

  /// فالبک API سبکِ پکیج (dorar_api.json): نتایج با متن/راوی/… ولی بدون
  /// شناسهٔ حدیث؛ صفحهٔ جزئیات اینجا غیرفعال می‌ماند اما جستجو کار می‌کند.
  Future<DorarSearchPageModel> _searchViaApiFallback(
    HadithSearchParams params,
  ) async {
    try {
      final response = await _client.searchHadith(params);
      return DorarSearchPageModel(
        items: response.data.map(DorarHadithModel.fromApi).toList(),
        hasNextPage: response.metadata.hasNextPage ?? false,
        totalResults: response.metadata.total ?? 0,
      );
    } on DorarException catch (e) {
      if (e.message.toLowerCase().contains('no hadith')) {
        return const DorarSearchPageModel.empty();
      }
      rethrow;
    }
  }

  @override
  Future<DorarHadithModel> getById(String hadithId) async =>
      DorarHadithModel.fromApi(await _client.getHadithById(hadithId));

  @override
  Future<List<DorarHadithModel>> getSimilarHadiths(String hadithId) async {
    final similar = await _client.getSimilarHadith(hadithId);
    return similar.map(DorarHadithModel.fromApi).toList();
  }

  @override
  Future<DorarHadithModel?> getAuthenticAlternative(String hadithId) async {
    final alternate = await _client.getAlternateHadith(hadithId);
    return alternate == null ? null : DorarHadithModel.fromApi(alternate);
  }

  @override
  Future<String?> getExplanation(String hadithText) async {
    try {
      final sharh = await _client.getSharhByText(hadithText);
      final text = sharh.sharhText?.trim();
      return (text == null || text.isEmpty) ? null : text;
    } on DorarNotFoundException {
      return null;
    }
  }

  static List<HadithDegree>? _degreesFor(DorarHadithFilter filter) {
    switch (filter) {
      case DorarHadithFilter.all:
        return null;
      case DorarHadithFilter.sahih:
        return const [
          HadithDegree.authenticHadith,
          HadithDegree.authenticChain
        ];
      case DorarHadithFilter.weak:
        return const [HadithDegree.weakHadith, HadithDegree.weakChain];
    }
  }
}
