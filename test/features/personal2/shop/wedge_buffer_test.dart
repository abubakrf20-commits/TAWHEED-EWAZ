import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/personal2/shop/scanner/barcode_scanner.dart';

/// The keyboard-wedge buffer: hardware scanners are keyboards that type a
/// burst of digits and press Enter. The heuristic (fast burst + Enter + sane
/// length) must fire for a scanner and stay silent for a human.
void main() {
  String? scan(WedgeBuffer buffer, String value) {
    for (final ch in value.runes) {
      buffer.feedCharacter(String.fromCharCode(ch));
    }
    return buffer.feedEnter();
  }

  test('a scanner burst ending with Enter fires the scan', () {
    expect(scan(WedgeBuffer(), '6274123390'), '6274123390');
  });

  test('a short burst is ignored (stray Enter in search)', () {
    expect(scan(WedgeBuffer(), '123'), isNull);
  });

  test('an over-long burst stops being a scan', () {
    expect(scan(WedgeBuffer(), '1234567890123456789012345678'), isNull,
        reason: '28 digits — a human typing, not a scanner');
  });

  test('the buffer resets after a completed scan', () {
    final buffer = WedgeBuffer();
    expect(scan(buffer, '6274123390'), '6274123390');
    // The second burst starts clean: the first scan's digits are gone.
    expect(scan(buffer, '555'), isNull,
        reason: 'below the length floor — proves the reset');
    expect(scan(buffer, '6274123391'), '6274123391');
  });

  test('the scan callback receives the value too', () {
    String? callbackValue;
    final buffer = WedgeBuffer(onScan: (v) => callbackValue = v);
    scan(buffer, '999888777');
    expect(callbackValue, '999888777');
  });

  test('a human typing (gapped) never fires', () {
    final buffer = WedgeBuffer();
    buffer.feedCharacter('1');
    buffer.clear(); // a real gap larger than the window resets
    buffer.feedCharacter('2');
    expect(buffer.feedEnter(), isNull,
        reason: 'only one digit in the buffer — below the length floor');
  });

  test('ManualBarcodeEntry and KeyboardWedgeScanner are always available', () {
    expect(KeyboardWedgeScanner().isAvailable, isTrue);
    expect(ManualBarcodeEntry().isAvailable, isTrue);
    expect(KeyboardWedgeScanner().label, contains('اسکنر'));
    expect(ManualBarcodeEntry().label, contains('دستی'));
  });
}
