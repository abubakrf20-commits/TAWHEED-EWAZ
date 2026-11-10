class NisabService {
  NisabService._();

  static const double goldNisabGrams = 85.0;
  static const double silverNisabGrams = 595.0;

  // هیچ قیمت پیش‌فرضی وجود ندارد — عمداً.
  //
  // قبلاً اینجا دو عدد ثابت بود (طلا ۲۵٬۰۰۰٬۰۰۰ و نقره ۳٬۵۰۰٬۰۰۰ تومان/گرم) که
  // هنگام خالی بودن فیلد قیمت، بی‌صدا جای قیمت روز می‌نشست. دو مشکل داشت:
  //   ۱) با گذشت زمان کهنه می‌شد و کاربر خبر نداشت؛ عدد کهنه نصاب را جابه‌جا
  //      می‌کند و «زکات واجب است/نیست» را برعکس می‌کند — یک خطای شرعی، نه
  //      فقط یک خطای نمایش.
  //   ۲) هیچ راهی برای به‌روز نگه‌داشتنش در برنامه نبود؛ فقط انتشار نسخهٔ
  //      جدید آن را عوض می‌کرد.
  // حالا قیمت باید یا دستی وارد شود یا با «دریافت قیمت روز» بیاید. اگر نباشد،
  // نتیجه صریحاً می‌گوید «نصاب قابل محاسبه نیست» و هیچ زکاتی جعل نمی‌کند.

  static double nisabByGold(double goldPricePerGram) {
    return goldNisabGrams * goldPricePerGram;
  }

  static double nisabBySilver(double silverPricePerGram) {
    return silverNisabGrams * silverPricePerGram;
  }
}
