/// 28 منازل القمر — هر منزل 12°51′26″ از دائرةالبروج
class MoonManzil {
  final int index; // 0..27
  final String arabic;
  final String persian;
  final String star;
  final String description;
  const MoonManzil({
    required this.index,
    required this.arabic,
    required this.persian,
    required this.star,
    required this.description,
  });
}

/// فهرست کامل 28 منزل به ترتیب دائرةالبروج (حمل تا حوت)
const List<MoonManzil> kMoonManazil = [
  MoonManzil(
      index: 0,
      arabic: 'الشرطين',
      persian: 'شرطین',
      star: 'حمل — β Ari',
      description: 'دو شاخ قوچ'),
  MoonManzil(
      index: 1,
      arabic: 'البطين',
      persian: 'بطین',
      star: 'حمل — ε Ari',
      description: 'شکم قوچ'),
  MoonManzil(
      index: 2,
      arabic: 'الثريا',
      persian: 'ثریا',
      star: 'ثور — Pleiades',
      description: 'خوشه پروین'),
  MoonManzil(
      index: 3,
      arabic: 'الدبران',
      persian: 'دبران',
      star: 'ثور — α Tau',
      description: 'پیرو ثریا'),
  MoonManzil(
      index: 4,
      arabic: 'الهقعة',
      persian: 'هقعه',
      star: 'جوزا — λ Ori',
      description: 'سه ستاره جبار'),
  MoonManzil(
      index: 5,
      arabic: 'الهنعة',
      persian: 'هنعه',
      star: 'جوزا — γ Gem',
      description: 'نشان سینه'),
  MoonManzil(
      index: 6,
      arabic: 'الذراع',
      persian: 'ذراع',
      star: 'جوزا — α Gem',
      description: 'بازوی شیر'),
  MoonManzil(
      index: 7,
      arabic: 'النثرة',
      persian: 'نثره',
      star: 'سرطان — Praesepe',
      description: 'بینی شیر'),
  MoonManzil(
      index: 8,
      arabic: 'الطرف',
      persian: 'طرف',
      star: 'سرطان — λ Leo',
      description: 'چشم شیر'),
  MoonManzil(
      index: 9,
      arabic: 'الجبهة',
      persian: 'جبهه',
      star: 'اسد — α Leo',
      description: 'پیشانی شیر'),
  MoonManzil(
      index: 10,
      arabic: 'الزبرة',
      persian: 'زبره',
      star: 'اسد — γ Leo',
      description: 'یال شیر'),
  MoonManzil(
      index: 11,
      arabic: 'الصرفة',
      persian: 'صرفه',
      star: 'اسد — β Leo',
      description: 'دم شیر'),
  MoonManzil(
      index: 12,
      arabic: 'العواء',
      persian: 'عواء',
      star: 'سنبله — β Vir',
      description: 'پارس سگ'),
  MoonManzil(
      index: 13,
      arabic: 'السماك',
      persian: 'سماک',
      star: 'سنبله — α Vir',
      description: 'سماک اعزل'),
  MoonManzil(
      index: 14,
      arabic: 'الغفر',
      persian: 'غفر',
      star: 'سنبله — ι Vir',
      description: 'پوشاننده'),
  MoonManzil(
      index: 15,
      arabic: 'الزبانا',
      persian: 'زبانا',
      star: 'میزان — α Lib',
      description: 'چنگال عقرب'),
  MoonManzil(
      index: 16,
      arabic: 'الإكليل',
      persian: 'اکلیل',
      star: 'عقرب — β Sco',
      description: 'تاج عقرب'),
  MoonManzil(
      index: 17,
      arabic: 'القلب',
      persian: 'قلب',
      star: 'عقرب — α Sco',
      description: 'قلب عقرب'),
  MoonManzil(
      index: 18,
      arabic: 'الشولة',
      persian: 'شوله',
      star: 'عقرب — λ Sco',
      description: 'نیش عقرب'),
  MoonManzil(
      index: 19,
      arabic: 'النعائم',
      persian: 'نعائم',
      star: 'قوس — γ Sgr',
      description: 'شترمرغان'),
  MoonManzil(
      index: 20,
      arabic: 'البلدة',
      persian: 'بلده',
      star: 'قوس — π Sgr',
      description: 'شهر تهی'),
  MoonManzil(
      index: 21,
      arabic: 'سعد الذابح',
      persian: 'سعد ذابح',
      star: 'جدی — α Cap',
      description: 'سعادت ذبح‌کننده'),
  MoonManzil(
      index: 22,
      arabic: 'سعد بلع',
      persian: 'سعد بلع',
      star: 'دلو — ε Aqr',
      description: 'سعادت بلعنده'),
  MoonManzil(
      index: 23,
      arabic: 'سعد السعود',
      persian: 'سعد السعود',
      star: 'دلو — β Aqr',
      description: 'سعادت سعادت‌ها'),
  MoonManzil(
      index: 24,
      arabic: 'سعد الأخبية',
      persian: 'سعد اخبیه',
      star: 'دلو — γ Aqr',
      description: 'سعادت خیمه‌ها'),
  MoonManzil(
      index: 25,
      arabic: 'الفرغ المقدم',
      persian: 'فرغ مقدم',
      star: 'دلو — α Peg',
      description: 'ریزش پیشین'),
  MoonManzil(
      index: 26,
      arabic: 'الفرغ المؤخر',
      persian: 'فرغ مؤخر',
      star: 'حوت — α Peg',
      description: 'ریزش پسین'),
  MoonManzil(
      index: 27,
      arabic: 'الرشا / بطن الحوت',
      persian: 'رشا',
      star: 'حوت — β And',
      description: 'ریسمان ماهی'),
];

/// نام فازهای 8گانه
enum MoonPhaseName {
  newMoon('محاق', 'هلال نو'),
  waxingCrescent('هلال افزاینده', 'هلال'),
  firstQuarter('تربیع اول', 'نیمه اول'),
  waxingGibbous('محدب افزاینده', ''),
  fullMoon('بدر کامل', 'ماه کامل'),
  waningGibbous('محدب کاهنده', ''),
  lastQuarter('تربیع آخر', 'نیمه دوم'),
  waningCrescent('هلال کاهنده', 'هلال آخر');

  final String persian;
  final String shortName;
  const MoonPhaseName(this.persian, this.shortName);
}
