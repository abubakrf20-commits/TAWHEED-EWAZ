import 'package:flutter/material.dart';
import 'package:tawheeed/app/router/route_names.dart';

/// ═══════════════════════════════════════════════════════════════
/// SectionColors — single source of truth for per-feature topic colors.
///
/// This table serves the OPENED screens: `of(route)` maps a route to the
/// identity hue of the page it opens, so the header, tab bar and icons of
/// the opened page match the tile that opened it.
///
/// The «بیشتر» (More) tiles themselves read [TopicHues] (time_theme.dart) —
/// a parity test pins every shared name equal between the two tables so
/// they cannot drift. SectionHues (also in time_theme.dart) is a different
/// family: the fixed bottom-nav tab identities.
///
/// These colors are fixed topic colors — they never change with the
/// app theme accent, only lighten/darken for readability in dark mode.
/// ═══════════════════════════════════════════════════════════════
abstract final class SectionColors {
  SectionColors._();

  static const Color qibla = Color(0xFF2E7D32); // سبز — کعبه و قبله
  static const Color purification = Color(0xFF1976D2); // آبی — آب و پاکی
  static const Color prayer = Color(0xFF00897B); // فیروزه‌ای — مسجد
  static const Color fasting = Color(0xFF8E24AA); // بنفش — شب‌های رمضان
  static const Color zakat = Color(0xFFF9A825); // طلایی — مال و برکت
  static const Color khatm = Color(0xFF1B5E20); // سبز پررنگ — قرآن
  static const Color dua = Color(0xFF2E7D32); // سبز — دعا و مناجات
  static const Color duas = Color(
      0xFF00897B); // فیروزه‌ای تیره — حصار و حفاظت (هم‌رنگ صفحات حصن المسلم)
  static const Color worshipChecklist =
      Color(0xFFEF6C00); // نارنجی — انجام کارها
  static const Color hajjUmrah = Color(0xFF795548); // قهوه‌ای — خاک و کعبه
  static const Color inheritance = Color(0xFF6A1B9A); // بنفش — قانون و سهم
  static const Color ruqyah = Color(0xFF00A86B); // سبز زمردی — شفا
  static const Color hadithBooks =
      Color(0xFF00838F); // فیروزه‌ای تیره — کتب روایی
  static const Color dorarHadith =
      Color(0xFFBF360C); // نارنجی پررنگ — جستجوی احادیث درر
  static const Color ketabkhaneh = Color(0xFF8D6E63); // قهوه‌ای — کتاب
  static const Color sciences = Color(0xFF3F51B5); // نیلی — دانش
  static const Color study = Color(0xFF0097A7); // فیروزه‌ای پررنگ — مطالعه
  static const Color tasks = Color(0xFF1E88E5); // آبی — برنامه‌ریزی
  static const Color expenses = Color(0xFFE53935); // قرمز — هزینه و خرج
  static const Color worshipNotes = Color(0xFFF9A825); // کهربایی — یادداشت
  static const Color reminders = Color(0xFFFB8C00); // نارنجی — زنگ یادآوری
  static const Color period = Color(0xFFEC407A); // صورتی — بانوان
  static const Color calculator = Color(0xFF607D8B); // آبی‌خاکستری — محاسبه
  static const Color hifz = Color(0xFF00695C); // فیروزه‌ای تیره — حفظ قرآن
  static const Color pomodoro = Color(0xFFE53935); // قرمز گوجه — تایمر پومودور
  static const Color dangi = Color(0xFF00ACC1); // فیروزه‌ای روشن — تقسیم هزینه
  static const Color hadeethEnc = Color(0xFF1565C0); // آبی — موسوعه احادیث
  static const Color moon = Color(0xFF283593); // نیلی تیره — ماه و منازل
  static const Color qafAi =
      Color(0xFF673AB7); // بنفش — هوش مصنوعی شرعی قاف (سایت خارجی)
  static const Color riyad = Color(0xFF558B2F); // سبز زیتونی — ریاض الصالحین
  static const Color taraghib =
      Color(0xFF880E4F); // عنابی — صحیح الترغیب (جدا از ریاض)
  static const Color fatwa = Color(0xFF00695C); // سبز تیره — فتوا و فقاهت
  static const Color yaqeen =
      Color(0xFF37474F); // آبی‌ذغالی — یقین و استواری اعتقاد
  static const Color audioLibrary =
      Color(0xFFE64A19); // نارنجی پررنگ — صدا و گوش دادن
  static const Color anasheed =
      Color(0xFF00838F); // فیروزه‌ای تیره — نشید و مدح
  static const Color lectures = Color(0xFF7B1FA2); // بنفش — سخنرانی و مجالس
  static const Color misc = Color(0xFF8D6E63); // قهوه‌ای — متفرقه و پراکنده
  static const Color goals = Color(0xFF00897B); // سبزآبی — هدف و پیشرفت
  // «ابزارهای شخصی» — رنگ سِکشن در صفحهٔ «بیشتر» (فقط گروه‌بندی)
  static const Color personalTools =
      Color(0xFF5C6BC0); // نیلی — گروه ابزارهای شخصی
  // «اطلاعات من» — صندوق شخصی و امنیت
  static const Color personalInfo =
      Color(0xFF37474F); // آبی‌ذغالی — امنیت و صندوق
  static const Color personalProfile =
      Color(0xFF5C6BC0); // نیلی — افراد و خانواده
  static const Color personalDocs =
      Color(0xFF26A69A); // فیروزه‌ای — اسناد و مدارک
  static const Color personalCredentials =
      Color(0xFFEF6C00); // نارنجی — رمزها و حساب‌ها
  static const Color personalAssets =
      Color(0xFF8D6E63); // قهوه‌ای — اموال و املاک
  static const Color personalInsurance = Color(0xFF00897B); // سبزآبی — بیمه
  static const Color personalEmergency =
      Color(0xFFE53935); // قرمز — تماس اضطراری
  static const Color personalExpiry =
      Color(0xFFF9A825); // کهربایی — تاریخ‌های مهم
  // «ابزارهای شخصی» مجموعهٔ ۲ — دو ابزار تازه، هر کدام هویت خودش
  static const Color kidsHabits =
      Color(0xFFE58A2B); // نارنجی گرم — دفتر عادت کودک
  static const Color teacherLedger =
      Color(0xFF1F7A63); // سبز دریاچه‌ای — دفتر مربی قرآن
  static const Color shopLedger =
      Color(0xFF0E7C86); // فیروزه‌ای تیره — حساب مغازه
  static const Color maliLedger =
      Color(0xFFC9922F); // طلایی کهربایی — دفتر مالی
  static const Color debtLedger =
      Color(0xFF8A5A44); // قهوه‌ای گرم — دفتر دَین
  static const Color carCare = Color(0xFF3A5BA0); // آبی — خودرو
  static const Color homeCare = Color(0xFF0F7B6C); // سبزآبی — خانه
  static const Color kaffaraLedger = Color(0xFFD9822B); // نارنجی — کفاره
  static const Color relativesLedger = Color(0xFFC0507A); // صورتی — صله رحم
  static const Color savingsLedger = Color(0xFF2E8B3D); // سبز — قلک
  static const Color qazaLedger = Color(0xFF6A5BA8); // بنفش — قضایار
  // جمعه — یادآوری هفتگی و آداب روز جمعه (تنها مصرف: باکس آداب جمعه).
  static const Color friday = Color(0xFF7A5AF8); // بنفش — جمعه و آداب آن

  /// Accent color for an audio-library subcategory (رد شبهات / اناشید
  /// اسلامی / سخنرانی). Each subcategory has its own hue so the opened screen
  /// matches the tile that opened it; unknown ids fall back to [audioLibrary].
  static Color audioLibraryCategory(String categoryId) {
    switch (categoryId) {
      case 'yaqeen':
        return yaqeen;
      case 'anasheed':
        return anasheed;
      case 'lectures':
        return lectures;
      case 'misc':
        return misc;
      default:
        return audioLibrary;
    }
  }

  /// Color for the feature behind [route], or [fallback] when unknown.
  static Color of(String route, {Color? fallback}) {
    switch (route) {
      case RouteNames.qibla:
        return qibla;
      case RouteNames.purification:
        return purification;
      case RouteNames.prayer:
        return prayer;
      case RouteNames.fasting:
        return fasting;
      case RouteNames.zakat:
        return zakat;
      case RouteNames.khatm:
        return khatm;
      case RouteNames.dua:
        return dua;
      case RouteNames.duas:
        return duas;
      case RouteNames.worshipChecklist:
        return worshipChecklist;
      case RouteNames.hajjUmrah:
        return hajjUmrah;
      case RouteNames.inheritance:
        return inheritance;
      case RouteNames.ruqyah:
        return ruqyah;
      case RouteNames.hadithBooks:
        return hadithBooks;
      case RouteNames.dorarHadithSearch:
        return dorarHadith;
      case RouteNames.ketabkhaneh:
        return ketabkhaneh;
      case RouteNames.sciences:
        return sciences;
      case RouteNames.study:
        return study;
      case RouteNames.tasks:
        return tasks;
      case RouteNames.expenses:
        return expenses;
      case RouteNames.worshipNotes:
        return worshipNotes;
      case RouteNames.reminders:
        return reminders;
      case RouteNames.period:
        return period;
      case RouteNames.calculator:
        return calculator;
      case RouteNames.hifz:
        return hifz;
      case RouteNames.pomodoro:
        return pomodoro;
      case RouteNames.dangi:
        return dangi;
      case RouteNames.hadeethEnc:
        return hadeethEnc;
      case RouteNames.goals:
        return goals;
      case RouteNames.personalInfo:
        return personalInfo;
      case RouteNames.personalProfiles:
        return personalProfile;
      case RouteNames.personalDocuments:
        return personalDocs;
      case RouteNames.personalCredentials:
        return personalCredentials;
      case RouteNames.personalAssets:
        return personalAssets;
      case RouteNames.personalInsurance:
        return personalInsurance;
      case RouteNames.personalEmergencyContacts:
        return personalEmergency;
      case RouteNames.personalExpiry:
        return personalExpiry;
      case RouteNames.kidsHome:
      case RouteNames.kidsChildSetup:
      case RouteNames.kidsChildMode:
      case RouteNames.kidsHabits:
      case RouteNames.kidsRewards:
      case RouteNames.kidsApprovals:
      case RouteNames.kidsReport:
        return kidsHabits;
      case RouteNames.quranTeacherHome:
      case RouteNames.quranTeacherLesson:
      case RouteNames.quranTeacherStudent:
      case RouteNames.quranTeacherReport:
      case RouteNames.quranTeacherClasses:
        return teacherLedger;
      case RouteNames.shopHome:
      case RouteNames.shopPos:
      case RouteNames.shopSettings:
      case RouteNames.shopCustomers:
      case RouteNames.shopCustomerDetail:
      case RouteNames.shopProducts:
      case RouteNames.shopReport:
        return shopLedger;
      case RouteNames.personalCar:
      case RouteNames.personalCarHistory:
        return carCare;
      case RouteNames.personalHomeCare:
      case RouteNames.personalHomeHistory:
        return homeCare;
      case RouteNames.personalFinance:
      case RouteNames.personalFinancePerson:
      case RouteNames.personalFinancePersonPattern:
        return maliLedger;
      case RouteNames.personalKaffara:
        return kaffaraLedger;
      case RouteNames.personalSavings:
        return savingsLedger;
      case RouteNames.personalQaza:
        return qazaLedger;
      case RouteNames.personalRelatives:
        return relativesLedger;
      case RouteNames.moon:
        return moon;
      case RouteNames.riyad:
        return riyad;
      case RouteNames.taraghib:
        return taraghib;
      case RouteNames.fatwa:
        return fatwa;
      case RouteNames.yaqeen:
        return yaqeen;
      case RouteNames.audioLibrary:
        return audioLibrary;
      default:
        return fallback ?? const Color(0xFF6B7D8C);
    }
  }
}
