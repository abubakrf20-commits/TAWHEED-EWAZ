import 'package:meta/meta.dart';

/// یک حدیث بازگشتی از الدرر السنية.
///
/// لایه Domain — خالص و بدون وابستگی به Flutter یا Drift یا پکیج dorar.
@immutable
class DorarHadithEntity {
  /// شناسه حدیث در dorar.net؛ اگر سرویس آن را نداده باشد، یک کلید پایدار
  /// از متن + منبع ساخته می‌شود (برای المفضلة).
  final String id;
  final String hadithText;

  /// الراوي
  final String? narrator;

  /// المحدث (حكم‌کننده به حدیث)
  final String? mohdith;

  /// کتاب مصدر (مثلاً «صحيح البخاري»)
  final String? book;

  /// درجه صحت (صحيح / حسن / ضعيف / موضوع …)
  final String? degree;

  /// شماره حدیث یا صفحه و جلد (numberOrPage)
  final String? hadithNumber;

  /// متن شرح — فقط وقتی کاربر «الشرح» را زده باشد پر می‌شود.
  final String? explanation;

  /// لینک‌های احادیث مشابه (خروجی خام درر)
  final List<String> similarHadiths;

  /// متن حدیث بدیلِ صحیح برای احادیث ضعیف
  final List<String> alternatives;

  /// آیا شناسه واقعی درر دارد و صفحه جزئیات باز می‌شود.
  final bool canViewDetails;

  const DorarHadithEntity({
    required this.id,
    required this.hadithText,
    this.narrator,
    this.mohdith,
    this.book,
    this.degree,
    this.hadithNumber,
    this.explanation,
    this.similarHadiths = const [],
    this.alternatives = const [],
    this.canViewDetails = false,
  });

  DorarHadithEntity copyWithExplanation(String? explanation) =>
      DorarHadithEntity(
        id: id,
        hadithText: hadithText,
        narrator: narrator,
        mohdith: mohdith,
        book: book,
        degree: degree,
        hadithNumber: hadithNumber,
        explanation: explanation,
        similarHadiths: similarHadiths,
        alternatives: alternatives,
        canViewDetails: canViewDetails,
      );
}

/// فیلتر درجه صحت برای نوار جستجو.
///
/// API درر فقط «صحت» و «ضعف» را به‌صورت فیلتر می‌دهد؛ حسن و موضوع در
/// برچسب نتایج نمایش داده می‌شوند ولی فیلتر مستقل ندارند.
enum DorarHadithFilter {
  all('همه'),
  sahih('صحیح'),
  weak('ضعیف');

  final String label;
  const DorarHadithFilter(this.label);
}

/// یک صفحه از نتایج جستجو + وضعیت Pagination.
@immutable
class DorarHadithResultsPage {
  final List<DorarHadithEntity> items;
  final bool hasNextPage;
  final int totalResults;

  const DorarHadithResultsPage({
    required this.items,
    this.hasNextPage = false,
    this.totalResults = 0,
  });
}

/// جزئیات کامل یک حدیث با احادیث مشابه و بدیل صحیح.
@immutable
class DorarHadithDetail {
  final DorarHadithEntity hadith;
  final List<DorarHadithEntity> similar;
  final DorarHadithEntity? authenticAlternative;

  const DorarHadithDetail({
    required this.hadith,
    this.similar = const [],
    this.authenticAlternative,
  });
}
