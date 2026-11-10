import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';

/// Audit U8 (unit 8 P1): the sign-in error surface collapsed «شبکه قطع»,
/// «اعتبارنامهٔ اشتباه» and «سرویس ابری ناموجود» into one generic sentence,
/// so an offline user filed the same support ticket as a wrong-password one.
///
/// This mapper is the single source for the account hub's friendly Persian
/// copy. It distinguishes, in order:
///  1. repository-authored messages (they already carry the precise story —
///     e.g. the Google-link «account-exists» explanation) — passed through,
///  2. connectivity failures (auth network codes, sockets, timeouts),
///  3. credential/identity failures (per-code copy),
///  4. a catch-all that names what the user can actually do next.
class AuthErrorMessages {
  AuthErrorMessages._();

  static const String offline = 'اینترنت در دسترس نیست. '
      'اتصال را بررسی کنید و دوباره تلاش کنید.';
  static const String cloudUnavailable = 'سرویس ابری در دسترس نیست. '
      'اتصال اینترنت را بررسی کنید یا بعداً دوباره تلاش کنید.';
  static const String fallback = 'ورود ناموفق بود. '
      'ایمیل/رمز را بررسی کنید و دوباره تلاش کنید.';

  static String map(Object e) {
    if (e is StateError) return e.message.toString();
    // `Exception('…').toString()` prefixes «Exception: » — strip wrapper
    // prefixes so repository-authored Persian sentences match and pass
    // through clean.
    final raw = e
        .toString()
        .replaceFirst(RegExp(r'^(Exception|FormatException|ArgumentError):\s*'), '');
    // Repository-authored sentences carry a Persian lead — they are already
    // user-ready and more precise than anything inferred here.
    if (raw.contains('سرویس ابری در دسترس نیست')) return cloudUnavailable;
    if (raw.contains('ورود با گوگل') ||
        raw.contains('این ایمیل قبلاً') ||
        raw.contains('ابتدا وارد حساب') ||
        raw.contains('برای حذف حساب')) {
      return raw;
    }
    if (e is SocketException || e is TimeoutException) return offline;
    if (e is auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'حسابی با این ایمیل ساخته نشده است. '
              '«حساب ندارید؟ ساخت حساب» را بزنید.';
        case 'wrong-password':
          return 'رمز عبور اشتباه است.';
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'ایمیل یا رمز عبور درست نیست. اگر حساب ندارید، '
              'اول «ساخت حساب» را بزنید و همان ایمیل/رمز را بار دیگر استفاده کنید.';
        case 'invalid-email':
          return 'ایمیل واردشده معتبر نیست.';
        case 'email-already-in-use':
          return 'این ایمیل قبلاً ثبت شده است. از دکمهٔ «ورود» استفاده کنید.';
        case 'weak-password':
          return 'رمز عبور باید حداقل 6 کاراکتر باشد.';
        case 'user-disabled':
          return 'این حساب غیرفعال شده است.';
        case 'operation-not-allowed':
          return 'ورود با ایمیل/رمز در این پروژه فعال نیست.';
        case 'network-request-failed':
        case 'network_timeout':
          return offline;
        case 'too-many-requests':
          return 'دفعات تلاش زیاد شده؛ چند دقیقه بعد دوباره تلاش کنید.';
      }
    }
    if (e is FirebaseException) {
      // Storage/Firestore transport failures read like the network case:
      // the user's actionable step is the same.
      const networkCodes = {'unavailable', 'network-request-failed'};
      if (networkCodes.contains(e.code) ||
          (e.message ?? '').toLowerCase().contains('network')) {
        return offline;
      }
    }
    return fallback;
  }
}
