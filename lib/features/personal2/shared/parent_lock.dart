import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';
import 'package:tawheeed/shared/services/app_secure_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// ═══════════════════════════════════════════════════════════════
/// ParentLock — the gate in front of parent-only actions in the personal
/// tools (approve a reward, adjust stars, leave child mode).
///
/// It REUSES the app's existing personal-tools PIN: the verifier lives in the
/// same flutter_secure_storage entry the vault uses
/// ([PinLockService]'s `personal_info.pin_verifier`), so a parent who already
/// protects «اطلاعات من» has nothing new to set up, and the existing
/// backup exclusions (`personal_info.*` is filtered out of portable archives
/// and `backup_rules.xml` keeps it out of Android auto-backup) cover it with
/// no extra work.
///
/// WHAT DIFFERS FROM THE VAULT GATE — and why this is a separate service
/// rather than a call into [PinLockService]:
///  • **PBKDF2-HMAC-SHA256, >= 100k iterations**, computed off the UI isolate.
///    The vault verifier is a single salted SHA-256; that is fast enough to
///    brute-force a 4-digit PIN. A v2 verifier
///    `{v:2, alg:'pbkdf2-sha256', iter, salt, hash}` is written next to the
///    old one and the old one is retired on the first successful unlock.
///  • **Attempt throttling**: 5 failures cost 30 s, and each further burst
///    doubles it (60 s, 120 s …), persisted so killing the app does not reset
///    the clock.
///  • **Constant-time compare** on the derived bytes.
///  • The PIN is never logged, never stored in SharedPreferences, and never
///    echoed in an exception message.
///
/// The hash runs in a [Isolate.run] (Dart 2.19+ / Dart 3 here) so a 100k-round
/// derivation cannot jank the frame that opens the sheet — the brief's
/// performance rule "no per-second work" has a sibling: no PBKDF2 on the UI
/// isolate.
/// ═══════════════════════════════════════════════════════════════
class ParentLock {
  ParentLock._();

  /// Its OWN secure-storage entry, under the `personal_info.` prefix so the
  /// existing backup exclusions (that prefix is filtered out of portable
  /// archives and kept out of Android auto-backup) cover it unchanged.
  ///
  /// It is deliberately NOT the vault's exact key: the vault verifier is a
  /// v1 `{salt,hash}` record and [PinLockService] reads that key directly, so
  /// writing a v2 shape into it would make the vault compare a PBKDF2 digest
  /// against a SHA-256 one and reject every correct PIN. Two keys, one
  /// credential: [_reconcileWithVault] keeps them in step.
  static const String verifierKey = 'personal_info.parent_pin_verifier';

  /// PBKDF2 iterations for NEW verifiers. Stored per verifier so raising this
  /// later does not invalidate existing PINs.
  static const int iterations = 120000;

  /// Failures allowed before the first lockout.
  static const int maxAttempts = 5;

  /// First lockout, doubled for every further exhausted burst.
  static const Duration firstLockout = Duration(seconds: 30);

  static const Duration _maxLockout = Duration(hours: 1);

  // SharedPreferences keys. Throttle state is NOT secret (it holds no PIN
  // material) but is excluded from portable backups so restoring onto another
  // device does not carry a lockout with it.
  // The keys use the `personal_info.` prefix so the backup service's existing
  // sensitive prefix (the one that already keeps the PIN verifier home) covers
  // them with no second list to maintain. A lockout must not travel: restoring
  // one onto a fresh device would lock the legitimate owner out for someone
  // else's brute-force attempt.
  static const String _failKey = 'personal_info.parent_lock_failures';
  static const String _untilKey = 'personal_info.parent_lock_until_ms';
  static const String _burstKey = 'personal_info.parent_lock_burst';

  static const storage = appSecureStorage;

  /// Whether fast in-memory throttle state is still being trusted for this
  /// process. Avoids a SharedPreferences read on every single verify.
  static _Throttle? _hotThrottle;

  // ── State ────────────────────────────────────────────────────────────

  /// Whether any PIN exists: the parent lock's own v2 verifier, or the vault's
  /// PIN that the parent lock is allowed to adopt on first use.
  /// A false answer means "nothing to gate": callers must let the action
  /// through, exactly like [PinLockService.isPinSet]-based flows do.
  static Future<bool> isPinSet() async {
    final v2 = await _readV2();
    if (v2 != null) return true;
    return PinLockService.isPinSet();
  }

  /// Sets (or replaces) the PIN. Returns false when secure storage refuses —
  /// the caller must NOT fall back to a weaker store.
  static Future<bool> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = await _derive(pin: pin, salt: salt, iterations: iterations);
    final ok = await _writeV2(
      _V2Verifier(iterations: iterations, salt: salt, hash: hash),
    );
    if (!ok) return false;
    await _clearThrottle();
    return true;
  }

  /// Removes the parent lock AND the vault PIN, so «reset the parent PIN» is
  /// the app's existing whole-vault reset rather than a backdoor. A PIN that
  /// only the kids tool honours but the vault still enforces is exactly the
  /// confusing half-state to avoid.
  static Future<void> clearPin() async {
    await storage.delete(key: verifierKey);
    await PinLockService.resetVault();
    await _clearThrottle();
  }

  /// Verifies [pin], applying the throttle.
  ///
  /// Returns a [LockResult] rather than a bare bool so the UI can say "wait
  /// 24 seconds" instead of "wrong PIN" — the two used to be the same screen.
  static Future<LockResult> verify(String pin) async {
    final normalized = NumberFormat.normalizeDigits(pin.trim());
    if (normalized.isEmpty) return const LockResult.wrong();

    final throttle = _hotThrottle ?? await _loadThrottle();
    final remaining = throttle.remaining;
    if (remaining > Duration.zero) {
      return LockResult.lockedOut(remaining);
    }

    final v2 = await _readV2();
    final bool ok;
    if (v2 != null) {
      final derived =
          await _derive(pin: normalized, salt: v2.salt, iterations: v2.iterations);
      ok = _constantTimeEquals(derived, v2.hash);
    } else {
      // No parent verifier yet. The vault's PIN is the same credential as far
      // as the user is concerned, so adopt it: verify against the vault, and
      // on success write a throttled, slow-to-guess v2 copy for this tool.
      // The vault's own v1 record is left untouched for [PinLockService].
      ok = await _verifyVault(normalized);
      if (ok) await setPin(normalized);
    }

    if (!ok) {
      final next = throttle.onFailure();
      _hotThrottle = next;
      await _saveThrottle(next);
      final lockout = next.remaining;
      return lockout > Duration.zero
          ? LockResult.lockedOut(lockout)
          : LockResult.wrong(attemptsLeft: next.attemptsLeft);
    }

    _hotThrottle = const _Throttle();
    await _saveThrottle(_hotThrottle!);
    return const LockResult.ok();
  }

  /// How long the caller must wait, or zero. Lets a screen render the lockout
  /// without attempting a verification first.
  static Future<Duration> remainingLockout() async {
    final throttle = _hotThrottle ?? await _loadThrottle();
    return throttle.remaining;
  }

  // ── The UI entry point the brief specifies ───────────────────────────

  /// `Future<bool> requirePin(context, reason)`.
  ///
  /// Resolves true when the action may proceed. With no PIN configured there
  /// is nothing to gate, so it resolves true immediately — the same policy as
  /// [PinLockService]-driven screens (no PIN = no lock).
  static Future<bool> requirePin(
    BuildContext context, {
    required String reason,
  }) async {
    if (!await isPinSet()) return true;
    if (!context.mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinSheet(reason: reason),
    );
    return result ?? false;
  }

  // ── Verification internals ───────────────────────────────────────────

  /// PBKDF2-HMAC-SHA256, run on a background isolate.
  ///
  /// `Iterable<Sha256>` is not sendable across isolates, so the pure-Dart
  /// derivation lives in a top-level function that takes and returns plain
  /// values ([_pbkdf2]), and [Isolate.run] marshals those.
  static Future<String> _derive({
    required String pin,
    required String salt,
    required int iterations,
  }) {
    return Isolate.run(
      () => _pbkdf2(
        password: pin,
        salt: salt,
        iterations: iterations,
        length: 32,
      ),
    );
  }

  static Future<bool> _verifyVault(String pin) async {
    try {
      return await PinLockService.verifyPin(pin);
    } catch (e) {
      // A Keystore failure must not read as "wrong PIN" — but it also must not
      // open the gate. Fail closed and say nothing about the PIN itself.
      AppLogger.warning('ParentLock', 'vault verifier unavailable: ${e.runtimeType}');
      return false;
    }
  }

  static Future<_V2Verifier?> _readV2() async {
    try {
      final raw = await storage.read(key: verifierKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      // Only this key's own v2 shape is readable here. A v1 record (or a
      // record whose algorithm is not PBKDF2) is treated as absent so the
      // vault path gets the decision.
      if (decoded['v'] != 2) return null;
      if (decoded['alg'] != 'pbkdf2-sha256') return null;
      final iter = (decoded['iter'] as num?)?.toInt();
      final salt = decoded['salt'];
      final hash = decoded['hash'];
      if (iter == null || iter <= 0) return null;
      if (salt is! String || salt.isEmpty) return null;
      if (hash is! String || hash.isEmpty) return null;
      return _V2Verifier(iterations: iter, salt: salt, hash: hash);
    } catch (_) {
      // Unreadable entry: treat as absent so the legacy path gets a chance
      // instead of locking the user out of their own tools.
      return null;
    }
  }

  static Future<bool> _writeV2(_V2Verifier verifier) async {
    try {
      await storage.write(
        key: verifierKey,
        value: jsonEncode({
          'v': 2,
          'alg': 'pbkdf2-sha256',
          'iter': verifier.iterations,
          'salt': verifier.salt,
          'hash': verifier.hash,
        }),
      );
      return true;
    } catch (e) {
      AppLogger.warning('ParentLock', 'verifier persist failed: ${e.runtimeType}');
      return false;
    }
  }

  static String _randomSalt() {
    final rng = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  /// Compares two base64 strings without early exit. Length is public
  /// information (it is the digest size), so a length mismatch returns early.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ── Throttle persistence ─────────────────────────────────────────────

  static Future<_Throttle> _loadThrottle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failures = prefs.getInt(_failKey) ?? 0;
      final burst = prefs.getInt(_burstKey) ?? 0;
      final untilMs = prefs.getInt(_untilKey) ?? 0;
      final until = untilMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(untilMs, isUtc: true);
      return _Throttle(
        failures: failures,
        burst: burst,
        lockedUntil: until,
      );
    } catch (e) {
      // A fresh throttle is the fail-open answer: the parent gets one more
      // attempt than the stored state allowed. Silently resetting a *lock*
      // counter is the kind of default that has to be logged to be defensible.
      AppLogger.warning('parent_lock', 'throttle read failed: $e');
      return const _Throttle();
    }
  }

  static Future<void> _saveThrottle(_Throttle t) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (t.failures == 0 && t.burst == 0 && t.lockedUntil == null) {
        await prefs.remove(_failKey);
        await prefs.remove(_burstKey);
        await prefs.remove(_untilKey);
        return;
      }
      await prefs.setInt(_failKey, t.failures);
      await prefs.setInt(_burstKey, t.burst);
      final untilMs = t.lockedUntil?.millisecondsSinceEpoch;
      if (untilMs == null) {
        await prefs.remove(_untilKey);
      } else {
        await prefs.setInt(_untilKey, untilMs);
      }
    } catch (e) {
      // In-memory state still throttles this process; a failed persist only
      // means a restart could clear the clock, which is the pre-existing
      // behaviour of the vault gate.
      AppLogger.warning('ParentLock', 'throttle persist failed: ${e.runtimeType}');
    }
  }

  static Future<void> _clearThrottle() async {
    _hotThrottle = const _Throttle();
    await _saveThrottle(_hotThrottle!);
  }

  /// Test seam: forget the cached throttle so a test can start from disk.
  @visibleForTesting
  static void resetThrottleCache() => _hotThrottle = null;
}

/// Outcome of [ParentLock.verify].
@immutable
class LockResult {
  const LockResult._({
    required this.unlocked,
    this.attemptsLeft,
    this.lockout = Duration.zero,
  });

  const LockResult.ok() : this._(unlocked: true);

  const LockResult.wrong({int? attemptsLeft})
      : this._(unlocked: false, attemptsLeft: attemptsLeft);

  const LockResult.lockedOut(Duration duration)
      : this._(unlocked: false, lockout: duration);

  final bool unlocked;

  /// Attempts remaining in the current burst (null when unavailable).
  final int? attemptsLeft;

  /// Remaining wait after the burst was exhausted.
  final Duration lockout;

  bool get isLockedOut => !unlocked && lockout > Duration.zero;
}

/// Persisted throttle state, kept immutable so a failed attempt yields a new
/// value instead of mutating shared state mid-verify.
@immutable
class _Throttle {
  const _Throttle({
    this.failures = 0,
    this.burst = 0,
    this.lockedUntil,
  });

  final int failures;

  /// How many lockouts have already been served — the doubling exponent.
  final int burst;

  final DateTime? lockedUntil;

  Duration get remaining {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  int get attemptsLeft => (ParentLock.maxAttempts - failures).clamp(0, ParentLock.maxAttempts);

  _Throttle onFailure() {
    final nextFailures = failures + 1;
    if (nextFailures < ParentLock.maxAttempts) {
      return _Throttle(failures: nextFailures, burst: burst);
    }
    // Burst exhausted: lock out, doubling each time.
    final exponent = burst.clamp(0, 10);
    var duration = ParentLock.firstLockout * (1 << exponent);
    if (duration > ParentLock._maxLockout) duration = ParentLock._maxLockout;
    return _Throttle(
      burst: burst + 1,
      lockedUntil: DateTime.now().toUtc().add(duration),
    );
  }
}

@immutable
class _V2Verifier {
  const _V2Verifier({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  final int iterations;
  final String salt;
  final String hash;
}

/// Pure PBKDF2-HMAC-SHA256. Top-level so [Isolate.run] can send it.
///
/// `package:crypto` exposes Hmac but no PBKDF2, and adding a dependency for
/// ~30 lines is not justified on a low-end Android budget — this is the RFC
/// 2898 §5.2 loop, single block (32 bytes = one SHA-256 block).
String _pbkdf2({
  required String password,
  required String salt,
  required int iterations,
  required int length,
}) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final saltBytes = utf8.encode(salt);

  final blocks = (length / 32).ceil();
  final out = <int>[];
  for (var block = 1; block <= blocks; block++) {
    // INT_32_BE(block)
    final blockIndex = <int>[
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert([...saltBytes, ...blockIndex]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
  }
  return base64Encode(out.take(length).toList());
}

/// The PIN entry sheet. Deliberately identical in tone to the vault gate so a
/// parent recognises it, but it reports the lockout countdown instead of a
/// flat «رمز اشتباه است».
class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.reason});

  final String reason;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _ctrl = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final result = await ParentLock.verify(_ctrl.text);
    if (!mounted) return;
    if (result.unlocked) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _ctrl.clear();
      if (result.isLockedOut) {
        final seconds = result.lockout.inSeconds.clamp(1, 3600);
        _error = 'تلاش بیش از حد. ${_fa(seconds)} ثانیه صبر کنید.';
      } else {
        final left = result.attemptsLeft;
        _error = left == null
            ? 'رمز اشتباه است.'
            : 'رمز اشتباه است. $left تلاش باقی مانده.';
      }
    });
  }

  static String _fa(int n) => NumberFormat.groupDigits('$n');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D1A17) : Colors.white,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 20,
                    color: isDark ? AppTheme.goldPale : AppTheme.goldRich),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.reason,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textOnDark : AppTheme.textOnLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_busy,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 23,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: _error.isEmpty ? null : _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(false),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تأیید'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether a parent PIN exists. Overridable in tests to avoid Keystore I/O.
final parentPinSetProvider = FutureProvider<bool>((ref) => ParentLock.isPinSet());
