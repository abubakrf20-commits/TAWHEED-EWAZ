import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// شناسهٔ ناشناس دستگاه برای هر پیشنهاد — بدون هیچ اطلاعات شخصی، فقط یک
/// رشتهٔ تصادفی که در تنظیمات محلی ذخیره می‌شود تا مدیر بتواند پیام‌های
/// تکراری یک دستگاه را تشخیص دهد.
class SuggestionDeviceTag {
  SuggestionDeviceTag._();

  static const _key = 'suggestion_device_tag';
  static const _tagLength = 8; // 8 بایت = 16 نویسهٔ hex

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    var tag = prefs.getString(_key);
    if (tag == null || tag.isEmpty) {
      tag = _randomHex();
      await prefs.setString(_key, tag);
    }
    return tag;
  }

  static String _randomHex() {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < _tagLength; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
