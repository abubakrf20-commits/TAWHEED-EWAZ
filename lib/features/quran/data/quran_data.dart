import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tawheeed/shared/utils/app_logger.dart';

/// متون کامل قرآن — پیش‌تر به‌صورت literal داخل همین فایل (45 هزار خط)
/// کامپایل می‌شد که هر اصلاح متنی را به کامپایل مجدد کل اپ گره می‌زد و
/// حجم snapshot را زیاد می‌کرد. حالا از asset جیسون بارگذاری می‌شود.
///
/// تمام مصرف‌کننده‌ها ([quran]) به‌صورت همگام کار می‌کنند؛ بنابراین
/// [loadQuranData] یک‌بار در `main()` پیش از `runApp` فراخوانی می‌شود.
/// در آزمون‌ها هم `setUpAll` معادل آن است.

List<Map<String, dynamic>> _quran = const [];

/// آیا متون قرآن بارگذاری شده‌اند؟
bool get quranDataLoaded => _quran.isNotEmpty;

/// بارگذاری متون از asset (یک‌بار؛ فراخوانی‌های بعدی بی‌هزینه‌اند).
/// decode در isolate جداگانه اجرا می‌شود تا رشتهٔ 2.5 مگابایتیِ JSON
/// thread اصلی را مسدود نکند.
Future<void> loadQuranData() async {
  if (_quran.isNotEmpty) return;
  try {
    final raw = await rootBundle.loadString('assets/quran/quran_data.json');
    _quran = await Isolate.run(() {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    });
  } catch (e, st) {
    // هرگز مانع شروع برنامه نشو — جستجو/اشتراک متنی خالی می‌ماند ولی
    // مصحف QCF4 (که از سرور/فونت کار می‌کند) سالم است.
    AppLogger.error('QuranData', 'failed to load quran_data.json: $e', st);
  }
}

/// فهرست کامل آیات — هر ردیف: `sora`, `aya_no`, `aya_text`,
/// `aya_text_emlaey`. پیش از نخستین دسترسی، [loadQuranData] باید کامل
/// شده باشد (در `main()` انجام می‌شود)؛ در غیر این صورت فهرست خالی است.
List<Map<String, dynamic>> get quran => _quran;
