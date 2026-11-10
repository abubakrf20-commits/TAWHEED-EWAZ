/// نام نمایشی نمازها — با در نظر گرفتن جمعه.
///
/// در روزهای جمعه، نماز ظهر با نام «جمعه» نمایش داده می‌شود. این فقط روی
/// **برچسب نمایشی** اثر می‌گذارد؛ کلیدهای انگلیسی (`dhuhr`)، نگاشت‌های
/// زمان، و منطق «نماز بعدی» دست‌نخورده می‌مانند تا با تغییر نام، مقایسه‌های
/// نقشه‌ای و هایلایت نماز خراب نشود.
///
/// این فایل عمداً زیر `shared` است چون هم ویجت اندروید (`widget_sync_service`)
///
/// و هم کارت‌های داخل برنامه از آن استفاده می‌کنند و `shared` نمی‌تواند به
/// `features` وابسته شود.
library;

/// برچسبی که در روزهای جمعه جایگزین «ظهر» می‌شود.
const String kJumuahLabel = 'جمعه';

/// آیا [label] نامِ نماز ظهر است؟ (برچسب فارسی/عربی، با یا بدون «اذان»)
bool isDhuhrLabel(String label) =>
    label == 'ظهر' ||
    label == 'اذان ظهر' ||
    label == 'الظهر' ||
    label == 'duhr' ||
    label == 'dhuhr';

/// [label] با «جمعه» جایگزین می‌شود اگر روز [date] جمعه باشد.
///
/// ورودی هرچه باشد بدون تغییر برگردانده می‌شود مگر آنکه نام ظهر باشد و روز
/// جمعه باشد؛ «اذان ظهر» هم به «اذان جمعه» تبدیل می‌شود تا نسبتِ «اذان »
/// حفظ شود.
String fridayPrayerLabel(String label, DateTime date) {
  if (date.weekday != DateTime.friday) return label;
  switch (label) {
    case 'ظهر':
    case 'duhr':
    case 'dhuhr':
    case 'الظهر':
      return kJumuahLabel;
    case 'اذان ظهر':
      return 'اذان $kJumuahLabel';
    case 'نماز ظهر':
      return 'نماز $kJumuahLabel';
    default:
      return label;
  }
}

/// مثل [fridayPrayerLabel] ولی برای وقتی که فقط باید بررسی شود روز جمعه است
/// یا نه — بدون تغییر نام. برای جاهایی که تصمیم‌گیری می‌کنند (مثل انتخاب
/// وقت نماز) و نباید نامشان عوض شود.
bool isJumuahDay(DateTime date) => date.weekday == DateTime.friday;
