import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

class InheritanceContent {
  InheritanceContent._();

  static Map<String, dynamic>? _data;
  static bool get isLoaded => _data != null;

  static Future<void> load() async {
    if (_data != null) return;
    final jsonString =
        await rootBundle.loadString('assets/content/inheritance.json');
    _data = latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
  }

  static String get introText {
    final v = _data?['introText'];
    if (v is String) return v;
    return '';
  }

  static List<String> get introAyat {
    final v = _data?['introAyat'];
    if (v is List) return v.cast<String>();
    return [];
  }

  static List<Map<String, dynamic>> get sections {
    final v = _data?['sections'];
    if (v is List) return v.cast<Map<String, dynamic>>();
    return [];
  }

  static List<Map<String, dynamic>> sectionsByCategory(String category) =>
      sections.where((s) => s['category'] == category).toList();

  static List<Map<String, dynamic>> get basicsSections =>
      sectionsByCategory('basics');

  static List<Map<String, dynamic>> get heirsSections =>
      sectionsByCategory('heirs');

  static List<Map<String, dynamic>> get rulesSections =>
      sectionsByCategory('rules');

  static String get disclaimer {
    final v = _data?['disclaimer'];
    if (v is String) return v;
    return '';
  }

  static Map<Madhab, Map<String, String>> get madhabInfo => {
        Madhab.jumhur: {
          'name': 'جمهور',
          'founder': 'نظر جمهور فقهای اهل سنت',
          'description':
              'نظر جمهور فقهای مذاهب چهارگانه (حنفی، مالکی، شافعی، حنبلی) درباره ارث. در این برنامه به‌عنوان مذهب پیش‌فرض در نظر گرفته شده است.',
          'keyPrinciple': 'اصول عام ارث بر اساس کتاب، سنت، اجماع و قیاس',
          'regions': 'سراسر جهان اسلام',
        },
        Madhab.hanafi: {
          'name': 'حنفی',
          'founder': 'امام ابو حنیفه نعمان بن ثابت (80–150 ه.ق)',
          'description':
              'مذهب حنفی بر اساس رأی و قیاس گسترده استوار است. امام ابو حنیفه از تابعان است و شاگردان بسیاری تربیت کرد. این مذهب بیشترین پیروان را در جهان اسلام دارد.',
          'keyPrinciple': 'کتاب، سنت، اجماع، قیاس، استحسان، عرف',
          'regions':
              'هند، پاکستان، ترکیه، شام، عراق، افغانستان، آسیای میانه، مصر',
        },
        Madhab.maliki: {
          'name': 'مالکی',
          'founder': 'امام مالک بن انس (93–179 ه.ق)',
          'description':
              'مذهب مالکی بر اساس عمل اهل مدینه و حدیث استوار است. امام مالک کتاب الموطأ را تألیف کرد که از قدیمی‌ترین کتب حدیث است.',
          'keyPrinciple': 'کتاب، سنت، اجماع، قیاس، مصالح مرسله، عمل اهل مدینه',
          'regions':
              'شمال آفریقا (مراکش، الجزایر، تونس)، غرب آفریقا، اندلس (اسپانیای سابق)',
        },
        Madhab.shafii: {
          'name': 'شافعی',
          'founder': 'امام محمد بن ادریس شافعی (150–204 ه.ق)',
          'description':
              'مذهب شافعی تلفیقی از مکتب فقهی حجاز (اهل حدیث) و عراق (اهل رأی) است. امام شافعی کتاب الرسالة را بنیان‌گذاری کرد که اولین کتاب در علم اصول فقه است.',
          'keyPrinciple': 'کتاب، سنت، اجماع، قیاس (ترتیب خاص شافعی)',
          'regions': 'مصر، شام، یمن، حجاز، اندونزی، مالزی، شرق آفریقا، کردستان',
        },
        Madhab.hanbali: {
          'name': 'حنبلی',
          'founder': 'امام احمد بن حنبل (164–241 ه.ق)',
          'description':
              'مذهب حنبلی بیش از دیگر مذاهب به ظاهر نصوص تمسک می‌کند. امام احمد بن حنبل صاحب مسند معروف است که شامل حدود 30 هزار حدیث است.',
          'keyPrinciple':
              'کتاب، سنت، فتاوای صحابه، حدیث مرسل و ضعیف (در صورت عدم وجود نص)، قیاس',
          'regions':
              'عربستان سعودی (نجد و مناطق مرکزی)، قطر، بخش‌هایی از شام و عراق',
        },
        Madhab.egyptian: {
          'name': 'قانون مصری',
          'founder': 'قانون میراث مصر 77/1943 و قانون وصیت 71/1946',
          'description':
              'قانون مصر بر پایهٔ فقه جمهور فقها (روش زید بن ثابت) بنا شده است. جد با برادران مقاسمه می‌کند (و از یک‌ششم کمتر نمی‌گیرد)، رد به صاحبان فرضِ نسبی داده می‌شود، مشترکه و غراوین اعمال می‌شوند و ذوی‌الأرحام در چهار طبقه ارث می‌برند.',
          'keyPrinciple':
              'جمهور به‌همراه وصیت واجبه برای فرزندانِ پسر و دخترِ متوفی',
          'regions': 'مصر',
        },
        Madhab.saudi: {
          'name': 'قانون سعودی',
          'founder': 'نظام احوال شخصیهٔ سعودی 1443هـ (م/73)',
          'description':
              'نظام سعودی بر پایهٔ فقه حنبلی و فتاوای کمیتهٔ دائمی فتوا بنا شده است. جد برادران را محجوب می‌کند و به‌جای پدر ارث می‌برد (خروج از مقاسمهٔ جمهور)، مسألهٔ مشترکه اعمال نمی‌شود (نظر علی) و رد بر صاحبان فرض جاری است.',
          'keyPrinciple': 'حنبلی: جد برادران را محجوب می‌کند؛ بدون مشترکه',
          'regions': 'عربستان سعودی',
        },
        Madhab.algerian: {
          'name': 'قانون الجزایری',
          'founder': 'قانون خانوادهٔ الجزایر 84-11 (اصلاحی 05-02)',
          'description':
              'قانون الجزایر بر پایهٔ فقه مالکی است. جد با برادران مقاسمه می‌کند، غراوین بر قول علی (مادر هنگام وجود برادران یک‌سوم اصل می‌گیرد)، رد به صاحبان فرض داده می‌شود، ذوی‌الأرحام فقط از طبقهٔ اول ارث می‌برند و وصیت واجبه (تنزیل) شامل فرزندانِ دخترها و پسرها می‌شود.',
          'keyPrinciple': 'مالکی به‌همراه تنزیل (وصیت واجبه)',
          'regions': 'الجزایر',
        },
        Madhab.moroccan: {
          'name': 'قانون مغربی',
          'founder': 'قانون خانوادهٔ مراکش (مدونة الأسرة) 70.03',
          'description':
              'مدونة الأسرة بر پایهٔ فقه مالکی است. جد با برادران مقاسمه می‌کند، رد بر صاحبان فرض جز همسران جاری می‌شود (خلاف مالک کلاسیک)، غراوین بر قول عمر (مادر یک‌سوم باقی‌مانده می‌گیرد)، وصیت واجبه (تنزیل) برای فرزندانِ پسر و دخترِ متوفی است و ذوی‌الأرحام ارث نمی‌برند.',
          'keyPrinciple': 'مالکی اصلاح‌شده (ردّ + غراوین بر قول عمر)',
          'regions': 'مراکش',
        },
        Madhab.jordanian: {
          'name': 'قانون اردنی',
          'founder': 'قانون احوال شخصیهٔ اردن 61/1976 (اصلاحی 15/2019)',
          'description':
              'قانون اردن بر پایهٔ فقه حنفی با اصلاحات 2019 است: رد یکی از همسران را همراه دیگر صاحبان فرض شامل می‌شود، خواهران با جد مقاسمه می‌کنند (اصلاح)، ذوی‌الأرحام به روش «اهل قرابت» (مرد مانند زن) ارث می‌برند و وصیت واجبه برای فرزندانِ پسرِ متوفی است.',
          'keyPrinciple': 'حنفی اصلاح‌شده (ردّ برای همسر + مقاسمهٔ جد)',
          'regions': 'اردن',
        },
        Madhab.emirati: {
          'name': 'قانون اماراتی',
          'founder': 'قانون احوال شخصیهٔ امارات 28/2005 (اصلاحی 41/2024)',
          'description':
              'قانون امارات (مادهٔ 321) در اختلاف به ترتیب به مالکی، حنبلی، شافعی و حنفی رجوع می‌کند. جد با برادران مقاسمه می‌کند (مقاسمهٔ جمهور)، مشترکه، اکدریه و غراوین (مادر یک‌سوم باقی‌مانده) اعمال می‌شوند، رد مانند قانون مصر است، ذوی‌الأرحام ارث می‌برند و وصیت واجبه وجود دارد.',
          'keyPrinciple': 'ترتیب رجوع: مالکی ← حنبلی ← شافعی ← حنفی',
          'regions': 'امارات',
        },
        Madhab.omani: {
          'name': 'قانون عمانی',
          'founder': 'فرمان سلطانی 32/97 (احکام مواریث)',
          'description':
              'قانون عمان (با خاستگاه اباضی) در احکام میراث آیینهٔ قانون امارات است: جد با برادران مقاسمه می‌کند، مشترکه، اکدریه و غراوین اعمال می‌شوند، رد به صاحبان فرض داده می‌شود، ذوی‌الأرحام ارث می‌برند و وصیت واجبه وجود دارد.',
          'keyPrinciple': 'مطابق قانون امارات',
          'regions': 'عمان',
        },
        Madhab.kuwaiti: {
          'name': 'قانون کویتی',
          'founder': 'قانون احوال شخصیهٔ کویت 51/1984',
          'description':
              'قانون کویت نزدیک به قانون مصر/جمهور است: جد از یک‌ششم کمتر نمی‌گیرد و با برادران مقاسمه می‌کند، مشترکه اعمال می‌شود، رد مانند مصر است (در برخی حالات همسر هم)، ذوی‌الأرحام در چهار طبقه ارث می‌برند و وصیت واجبه وجود دارد (ق 5/1971).',
          'keyPrinciple': 'نزدیک به قانون مصر/جمهور',
          'regions': 'کویت',
        },
        Madhab.tunisia1956: {
          'name': 'تونس 1956',
          'founder': 'مجلهٔ احوال شخصیهٔ تونس 1956 (قانون 77/1959)',
          'description':
              'مجلهٔ تونس بر پایهٔ مالکی با اصلاح ریشه‌ای 1959 است: رد همهٔ صاحبان فرض (حتی هر دو همسر) را شامل می‌شود، دختر باقی‌مانده را به‌صورت رد می‌گیرد حتی با وجود عصبه از برادران و عموها (لغو تعصیب برادران بر دختر)، غراوین بر قول عمر است، ذوی‌الأرحام ارث نمی‌برند و باقی‌مانده به صندوق دولت می‌رسد و وصیت واجبه ندارد.',
          'keyPrinciple': 'اصلاح 1959: لغو تعصیب برادران بر دختر',
          'regions': 'تونس',
        },
      };

  static List<Map<String, String>> get fiqhDifferences {
    final section14 = sections
        .where((s) => s['title'] == 'اختلافات فقهی مهم بین مذاهب اربعه')
        .toList();
    if (section14.isEmpty) return [];
    final tableBody =
        (section14.first['tableBody'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    return tableBody.map((row) {
      final cells = (row['row'] as List).cast<String>();
      return {
        'title': cells[0],
        'hanafi': cells.length > 1 ? cells[1] : '',
        'maliki': cells.length > 2 ? cells[2] : '',
        'shafii': cells.length > 3 ? cells[3] : '',
        'hanbali': cells.length > 4 ? cells[4] : '',
      };
    }).toList();
  }
}
