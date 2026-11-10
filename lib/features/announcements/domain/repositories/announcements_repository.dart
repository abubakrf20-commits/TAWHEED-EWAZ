import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';

/// چرا یک نوشتن روی پیام‌های مدیریت شکست خورد.
///
/// تا پیش از این کلاس، لایهٔ داده هنگام در دسترس نبودن Firebase بی‌صدا
/// `return` می‌کرد و رابط کاربری هم «پیام منتشر شد» نشان می‌داد؛ یعنی کاربر
/// پیام موفقیت می‌دید در حالی که هیچ چیز ذخیره نشده بود. اکنون هر شکستی به یک
/// [AnnouncementsWriteError] تبدیل می‌شود تا صفحه بتواند دلیل واقعی را به
/// کاربر بگوید.
enum AnnouncementsFailure {
  /// Firebase در این اجرا راه‌اندازی نشده (یا تنظیمات پروژه ناقص است).
  unavailable,

  /// قوانین امنیتی Firestore نوشتن را رد کردند.
  ///
  /// عملاً یعنی یکی از این دو: قوانین منتشرشده با `firestore.rules` هم‌خوان
  /// نیستند، یا uid این حساب در `config/app.adminUids` نیست.
  permissionDenied,

  /// خطای شبکه یا سرور.
  network,

  /// خطای ناشناخته.
  unknown,
}

/// خطای نوشتن پیام مدیریت، با دلیل قابل‌نمایش به کاربر.
class AnnouncementsWriteError implements Exception {
  const AnnouncementsWriteError(this.reason, {this.cause});

  final AnnouncementsFailure reason;

  /// خطای اصلی، برای ثبت در لاگ.
  final Object? cause;

  /// پیام فارسیِ قابل‌فهم برای کاربر.
  ///
  /// عمداً راهنمای عملی می‌دهد: خطای «دوباره تلاش کنید» برای رد شدنِ سمتِ
  /// قوانین بی‌فایده است، چون هیچ‌چیز تغییر نمی‌کند.
  String get message => switch (reason) {
        AnnouncementsFailure.unavailable =>
          'سرویس پیام‌رسانی در دسترس نیست؛ اتصال اینترنت و پیکربندی Firebase را بررسی کنید.',
        AnnouncementsFailure.permissionDenied =>
          'دسترسی مجاز نیست. قوانین امنیتی Firestore باید منتشر شده باشند '
              '(firebase deploy --only firestore:rules) و شناسهٔ این حساب در '
              'فهرست adminUids سند config/app ثبت شده باشد.',
        AnnouncementsFailure.network =>
          'ارتباط با سرور برقرار نشد؛ اتصال اینترنت را بررسی کنید.',
        AnnouncementsFailure.unknown => 'انتشار ناموفق بود؛ دوباره تلاش کنید.',
      };

  @override
  String toString() =>
      'AnnouncementsWriteError(${reason.name}${cause == null ? '' : ': $cause'})';
}

/// حداکثر طول عنوان و متن پیام — هم‌تراز با تابع `isValidAnnouncement()` در
/// `firestore.rules`.
///
/// این مقادیر عمداً در لایهٔ domain هستند تا دیالوگِ انتشار (`maxLength`) و
/// مخزنِ Firestore از یک منبع بخوانند. اگر سمت کلاینت بزرگ‌تر باشد نوشتن را
/// قوانین رد می‌کنند و کاربر فقط یک خطای مبهم می‌بیند؛ اگر کوچک‌تر باشد
/// پیام‌های معتبر بی‌دلیل محدود می‌شوند.
const int kAnnouncementMaxTitleLength = 80;
const int kAnnouncementMaxBodyLength = 2000;

/// نتیجهٔ انتشار.
///
/// [pushQueued] عمداً کنار گذاشته شده است: انتشار مستقیم فقط کالکشن
/// `announcements` را می‌نویسد و به Cloud Function وابسته نیست (کارکردن روی
/// پلن Spark بدون توابع).
class AnnounceResult {
  const AnnounceResult({
    required this.id,
    required this.pushQueued,
    this.pushError,
  });

  /// شناسهٔ سند پیام ایجادشده.
  final String id;

  /// همیشه false در انتشار مستقیم — فقط برای سازگاری با واسط حفظ شده است.
  final bool pushQueued;

  /// دلیل صف‌نشدن اعلان، در صورت شکست.
  final Object? pushError;
}

/// مخزن پیام‌های اطلاع‌رسانی مدیر.
///
/// کاربران فقط [watchAll] را مصرف می‌کنند؛ نوشتن و حذف فقط در اختیار مدیر
/// است و در Firestore rules هم محدود شده است.
abstract interface class AnnouncementsRepository {
  /// آیا Firebase در این اجرا راه‌اندازی شده است؟
  bool get isAvailable;

  /// جریان لحظه‌ای پیام‌های منتشرشده: سنجاق‌شده‌ها اول، سپس جدیدترین.
  Stream<List<Announcement>> watchAll();

  /// انتشار یک پیام جدید (تنها مدیر).
  ///
  /// پیام را مستقیم در `announcements` ذخیره می‌کند؛ نیازی به Cloud Function
  /// یا صندوق خروجی نیست.
  ///
  /// در صورت شکست [AnnouncementsWriteError] پرتاب می‌شود.
  Future<AnnounceResult> publish({required String title, required String body});

  /// سنجاق یا لغو سنجاق یک پیام (تنها مدیر).
  Future<void> setPinned(String id, bool isPinned);

  /// ویرایش عنوان و متن یک پیام (تنها مدیر).
  ///
  /// محدودیت‌های طول با [kAnnouncementMaxTitleLength]/
  /// [kAnnouncementMaxBodyLength] سمت کلاینت نیز چک می‌شوند تا پیش از رسیدن
  /// به قوانین Firestore خطای فهم‌پذیر بدهد.
  Future<void> update({
    required String id,
    required String title,
    required String body,
  });

  /// حذف یک پیام (تنها مدیر).
  Future<void> delete(String id);
}
