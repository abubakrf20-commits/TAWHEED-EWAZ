import 'package:flutter/material.dart';

/// یک حدیث دربارهٔ فضیلت جمعه.
class FridayHadith {
  const FridayHadith({
    required this.arabic,
    required this.translation,
    required this.source,
  });

  final String arabic;
  final String translation;
  final String source;
}

/// یک توصیه/آداب از روز جمعه، با حدیث معتبرِ مربوط به خودش (در صورت وجود).
class FridayAdab {
  const FridayAdab({
    required this.icon,
    required this.title,
    required this.detail,
    this.hadith,
  });

  final IconData icon;
  final String title;
  final String detail;
  final FridayHadith? hadith;
}

/// منبع واحدِ فضایل و آداب روز جمعه.
///
/// احادیث دیگر در بوکس جداگانه نیستند؛ هر آداب حدیث صحیح خودش را با منبع
/// زیر همان آیتم دارد (نسخه ۱٫۷٫۲ — درخواست کاربر برای صفحهٔ کوتاه‌تر).
/// روایت‌های ضعیف/ساخته («مَثَلُوا فی سبعین»، «یوم الجمعه بدء النهار»،
/// «أفضل ما قلنا…»، «من صام یوم الجمعه…»، زیارت و «دختر آفتاب») حذف شدند.
///
/// آدابِ «اطعام و سخاوت» و «تلاوت و ختم قرآن» هم به‌درخواست کاربر از کارت
/// برداشته شدند؛ لطفاً دوباره اضافه نشوند.
class FridayContent {
  const FridayContent._();

  static const String title = 'آداب و فضایل روز جمعه';

  static bool isFriday(DateTime date) => date.weekday == DateTime.friday;

  /// حدیث فراگیرِ فضیلت جمعه — سرصفحهٔ کارت و خط اول اعلان.
  static const FridayHadith headline = FridayHadith(
    arabic: 'خَيْرُ يَوْمٍ طَلَعَتْ عَلَيْهِ الشَّمْسُ يَوْمُ الْجُمُعَةِ',
    translation: 'بهترین روزی که خورشید بر آن طلوع کرد، روز جمعه است.',
    source: 'صحیح مسلم',
  );

  /// حدیث سوره کهف — یک متن مشترک میان کارت صفحهٔ خانه و اعلان هفتگیِ کهف،
  /// تا این دو از هم دور نیفتند.
  static const FridayHadith kahfHadith = FridayHadith(
    arabic:
        'مَنْ قَرَأَ سُورَةَ الْكَهْفِ فِي يَوْمِ الْجُمُعَةِ أَضَاءَ لَهُ مِنَ النُّورِ مَا بَيْنَ الْجُمُعَتَيْنِ',
    translation:
        'هر کس سوره کهف را در روز جمعه بخواند، نوری از جمعه تا جمعه بر او می‌تابد.',
    source: 'سنن ترمذی و مستدرک حاکم',
  );

  /// آداب و اعمال مستحب روز جمعه — هرکدام با حدیث صحیح خودش.
  static const List<FridayAdab> adabs = [
    FridayAdab(
      icon: Icons.water_drop_outlined,
      title: 'غسل جمعه',
      detail: 'غسل کردن پیش از رفتن به مسجد، مستحب و سبب پاداش فراوان است.',
      hadith: FridayHadith(
        arabic:
            'مَنِ اغْتَسَلَ يَوْمَ الْجُمُعَةِ غُسْلَ الْجَنَابَةِ ثُمَّ رَاحَ فَكَأَنَّمَا قَرَّبَ بَدَنَةً',
        translation:
            'هر کس روز جمعه غسل جنابت کند و سپس به مسجد برود، گویی شتری قربانی کرده است.',
        source: 'صحیح بخاری و مسلم',
      ),
    ),
    FridayAdab(
      icon: Icons.auto_stories_outlined,
      title: 'خواندن سوره کهف',
      detail: 'خواندن سوره کهف در روز جمعه نوری میان دو جمعه برای خواننده است.',
      hadith: kahfHadith,
    ),
    FridayAdab(
      icon: Icons.mosque_outlined,
      title: 'حضور زودتر در نماز جمعه',
      detail:
          'آمدن پیش از اذان و نشستن نزدیک خطیب، موجب بخشش گناهان و پاداش فزون است.',
      hadith: FridayHadith(
        arabic:
            'مَنِ اغْتَسَلَ يَوْمَ الْجُمُعَةِ ثُمَّ أَتَى الْمَسْجِدَ فَرَكَعَ رَكْعَتَيْنِ قَبْلَ صَلَاةِ الْجُمُعَةِ غُفِرَ لَهُ مَا بَيْنَهُمَا',
        translation:
            'هر کس روز جمعه غسل کند، به مسجد بیاید و پیش از نماز جمعه دو رکعت بخواند، میان آن دو آمرزیده می‌شود.',
        source: 'صحیح بخاری',
      ),
    ),
    FridayAdab(
      icon: Icons.favorite_outline,
      title: 'صلوات بسیار',
      detail:
          'رسیدن صلوات شما به پیامبر ﷺ، وی را شاد می‌کند و آن را به شما بازمی‌گرداند.',
      hadith: FridayHadith(
        arabic: 'أَكْثِرُوا عَلَيَّ مِنَ الصَّلَاةِ يَوْمَ الْجُمُعَةِ',
        translation:
            'در روز جمعه بر من بسیار صلوات بفرستید؛ زیرا صلوات شما بر من عرضه می‌شود.',
        source: 'سنن ابن ماجه و مسند احمد',
      ),
    ),
    FridayAdab(
      icon: Icons.volunteer_activism_outlined,
      title: 'دعا در ساعت استجابت',
      detail: 'پس از اذان ظهر تا غروب، ساعتی است که دعای مؤمن پذیرفته می‌شود.',
      hadith: FridayHadith(
        arabic:
            'فِيهِ سَاعَةٌ لَا يُوَافِقُهَا عَبْدٌ مُسْلِمٌ وَهُوَ قَائِمٌ يُصَلِّي يَسْأَلُ اللَّهَ شَيْئًا إِلَّا أَعْطَاهُ إِيَّاهُ',
        translation:
            'در روز جمعه ساعتی است که هیچ بندهٔ مسلمانی در حال نماز چیزی از خدا نخواهد مگر آنکه خدا به او می‌دهد.',
        source: 'صحیح بخاری و مسلم',
      ),
    ),
    FridayAdab(
      icon: Icons.spa_outlined,
      title: 'طهارت، عطر و لباس نیکو',
      detail:
          'تمیزی و خوشبویی در روز جمعه از نشانه‌های اهمیت دادن به نماز جمعه است.',
    ),
  ];

  /// همهٔ احادیثِ کارت، به‌ترتیب نمایش (سرصفحه + احادیثِ هر آداب).
  static List<FridayHadith> get hadiths => [
        headline,
        for (final a in adabs)
          if (a.hadith != null) a.hadith!,
      ];

  /// متن اعلان روز جمعه — از همان منبع واحد ساخته می‌شود.
  static String get notificationBody {
    final adabLines =
        adabs.take(6).map((a) => '• ${a.title}: ${a.detail}').join('\n');
    return '✨ فضیلت روز جمعه\n\n'
        '«${headline.arabic}»\n${headline.translation} (${headline.source})\n\n'
        '🕌 آداب و اذکار جمعه\n'
        '$adabLines\n\n'
        '🌹 از خداوند بخواهید؛ در این ساعت دعا پذیرفته است.';
  }
}
