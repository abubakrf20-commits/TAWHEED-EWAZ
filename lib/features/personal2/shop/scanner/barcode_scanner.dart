import 'package:flutter/services.dart';

import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';

/// ═══════════════════════════════════════════════════════════════
/// BarcodeScanner — the seam the POS scans through.
///
/// Stage 2 ships TWO implementations and deliberately no camera:
///  • [KeyboardWedgeScanner] — hardware/Bluetooth scanners are keyboards:
///    they emit a rapid burst of digits ending with Enter. Capturing them in
///    the search field costs zero APK bytes and works on every device.
///  • [ManualBarcodeEntry] — the user types the code; the same onScanned
///    callback fires.
///
/// WHY no camera yet: the viable Flutter options are `mobile_scanner` (ML Kit
/// unbundled via Play Services, ~1.5–2 MB APK, breaks on devices without
/// Google services) and `flutter_zxing` (bundled native lib, ~2–4 MB). Both
/// risk the stage's ≤2 MB budget on top of the shop core itself, and the
/// brief requires the app to work WITHOUT Google services. The decision, the
/// numbers and the follow-up are documented in docs/SHOP_DOMAIN.md §7.
/// ═══════════════════════════════════════════════════════════════
abstract class BarcodeScanner {
  /// Human-facing name for the settings page.
  String get label;

  /// Whether this implementation is available right now (a camera scanner
  /// would report its permission state here). Concrete implementations
  /// override; the default is true for the ones that never need permission.
  bool get isAvailable => true;
}

/// Hardware/Bluetooth scanner input: a burst of digits ending with Enter.
///
/// The POS search field drives this through [KeyEvent]s; the class owns the
/// timing heuristic (a scanner types far faster than a human — bursts shorter
/// than [burstWindow] ending in Enter are treated as a scan).
class KeyboardWedgeScanner implements BarcodeScanner {
  @override
  String get label => 'اسکنر سخت‌افزاری (کیبورد)';

  @override
  bool get isAvailable => true; // no permission needed — it is a keyboard

  /// Scanners type each digit within a few ms; a human cannot.
  static const Duration burstWindow = Duration(milliseconds: 120);

  /// Minimum length to count as a scan, so a stray Enter in a search does not
  /// fire a lookup.
  static const int minLength = 4;
}

/// Typed entry — always available, also the fallback when a camera scanner is
/// denied permission.
class ManualBarcodeEntry implements BarcodeScanner {
  @override
  String get label => 'ورود دستی بارکد';

  @override
  bool get isAvailable => true;
}

/// A controller that turns keystrokes into scan results.
///
/// The UI maps raw [KeyEvent]s onto [feedCharacter]/[feedEnter]; those two are
/// pure Dart, which is what makes the scanner heuristic unit-testable without
/// pumping widgets.
class WedgeBuffer {
  WedgeBuffer({this.onScan});

  final void Function(String barcode)? onScan;

  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeyAt = DateTime.now();
  bool _expired = false;

  /// Feeds one character from a key event.
  String? feedCharacter(String? char) {
    final now = DateTime.now();
    // A gap longer than the burst window means a human is typing: start over.
    if (now.difference(_lastKeyAt) > KeyboardWedgeScanner.burstWindow) {
      _buffer.clear();
      _expired = false;
    }
    _lastKeyAt = now;

    if (char == null || char.isEmpty) return null;
    if (char.codeUnitAt(0) < 0x20) return null; // control chars
    if (_expired) return null;
    _buffer.write(char);
    // A burst that keeps growing past a scanner's realistic length (24) was
    // a human typing digits — discard it entirely, so a later Enter cannot
    // fire a "scan" of someone's typed text (caught by the over-long test:
    // the flag alone left the buffer full and Enter still fired).
    if (_buffer.length > 24) {
      _expired = true;
      _buffer.clear();
    }
    return null;
  }

  /// Enter closes the burst. Returns the barcode when the buffer holds a
  /// plausible scan, and clears either way.
  String? feedEnter() {
    final value = _buffer.toString();
    _buffer.clear();
    _expired = false;
    _lastKeyAt = DateTime.now();
    if (value.length >= KeyboardWedgeScanner.minLength) {
      onScan?.call(value);
      return value;
    }
    return null;
  }

  /// Maps a key event onto the feed methods; the POS screen's Focus.onKeyEvent
  /// calls this. Returns the completed barcode when Enter closes a burst.
  String? onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      return feedEnter();
    }
    return feedCharacter(event.character);
  }

  void clear() {
    _buffer.clear();
    _expired = false;
  }
}

/// The feedback a successful scan gives, per the shop settings. Vibration is
/// free and always works; the beep is a documented follow-up (no suitable
/// short asset ships in this stage — a synthesized one needs an audio graph
/// the tool does not otherwise use).
Future<void> scanFeedback({
  required ShopSettingsRow settings,
  required bool success,
}) async {
  if (!settings.vibrateOnScan) return;
  if (success) {
    HapticFeedback.mediumImpact();
  } else {
    // A distinct double-tick for «چنین بارکدی نیست» so the operator can tell
    // without looking up.
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
  }
}
