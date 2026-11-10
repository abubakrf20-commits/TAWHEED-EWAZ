import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/account/domain/auth_error_messages.dart';

/// Audit U8: sign-in errors must distinguish «اینترنت قطع», «اعتبارنامهٔ
/// اشتباه» and «سرویس ابری ناموجود» — an offline user must never see the
/// same sentence as a wrong-password one, and the copy must be testable
/// without pumping the account hub.
void main() {
  auth.FirebaseAuthException authError(String code) =>
      auth.FirebaseAuthException(code: code);

  test('connectivity failures read as the offline message', () {
    expect(
      AuthErrorMessages.map(const SocketException('offline')),
      AuthErrorMessages.offline,
    );
    expect(
      AuthErrorMessages.map(TimeoutException('timeout')),
      AuthErrorMessages.offline,
    );
    expect(
      AuthErrorMessages.map(authError('network-request-failed')),
      AuthErrorMessages.offline,
    );
    final storage = FirebaseException(
      plugin: 'firebase_storage',
      code: 'unavailable',
    );
    expect(AuthErrorMessages.map(storage), AuthErrorMessages.offline);
  });

  test('credential failures keep their per-code copy', () {
    expect(
      AuthErrorMessages.map(authError('wrong-password')),
      'رمز عبور اشتباه است.',
    );
    expect(AuthErrorMessages.map(authError('user-not-found')),
        contains('ساخت حساب'));
    expect(AuthErrorMessages.map(authError('email-already-in-use')),
        contains('ورود'));
    expect(AuthErrorMessages.map(authError('weak-password')),
        contains('6 کاراکتر'));
    expect(AuthErrorMessages.map(authError('too-many-requests')),
        contains('چند دقیقه'));
  });

  test('the config-missing sentence names what the user can do', () {
    // The repository throws Exception('سرویس ابری در دسترس نیست.') when
    // Firebase never initialized; the mapper upgrades it with the
    // actionable hint instead of echoing the bare sentence.
    final mapped =
        AuthErrorMessages.map(Exception('سرویس ابری در دسترس نیست.'));
    expect(mapped, contains('سرویس ابری در دسترس نیست'));
    expect(mapped, contains('اینترنت'));
  });

  test('repository-authored explanations pass through verbatim', () {
    final googleLink = StateError(
      'این ایمیل قبلاً با رمز عبور ثبت شده است؛ '
      'برای اتصال ابری، اول با ایمیل و رمز وارد شوید.',
    );
    expect(AuthErrorMessages.map(googleLink), googleLink.message);
    expect(AuthErrorMessages.map(Exception('ابتدا وارد حساب شوید.')),
        contains('ابتدا وارد حساب'));
  });

  test('unknown errors keep the generic retry copy', () {
    expect(AuthErrorMessages.map(Object()), AuthErrorMessages.fallback);
  });
}
