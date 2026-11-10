import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards every widget layout against views the RemoteViews host will reject.
///
/// 2026-10-14: the prayer widget showed the launcher's "cannot load widget"
/// placeholder right after the per-prayer icons landed — the five `<Space>`
/// gaps (and the small layout's plain `<View>` hairline) inflate fine inside
/// the app process but the stock host throws on them, so the whole update is
/// dropped. MIUI's lenient factory masked it locally, which is why no device
/// in hand reproduced it. Dart tests never inflate layouts, so this scans the
/// XML instead.
///
/// 2026-10-23 → 2026-10-24, the lesson that shapes the rest of this file: the
/// clock and countdown were briefly our own `LatinClockView` /
/// `LatinCountdownView` (`@RemoteViews.RemoteView`), so they could format
/// Latin digits. MIUI's host **silently** refused that nested composition —
/// the cell showed «لا يمكن تحميل التطبيق المصغر» while `provideGlance` logged
/// a healthy duration and nothing anywhere named the leaf.
///
/// 2026-10-30: the ticking leaves are gone entirely (user: «تیک زدن اوقات را
/// کاملا حذف کنید»), so the only hand-written widget layout left is the tasbih
/// card. Both live layouts were deleted with `WidgetLiveLeaves.kt`, and this
/// file now pins that they stay deleted — a re-added `TextClock` would bring
/// back the launcher-locale digits and the frozen-minute disagreement.
void main() {
  // v2 is the locked generation (widget_lock.json; cf17ada renamed the file).
  const tasbihLayout =
      'android/app/src/main/res/layout/widget_tasbih_native_v2.xml';
  const widgetDir =
      'android/app/src/main/kotlin/com/islamic/tawheeed/widget';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue,
        reason: 'run from the project root so $path resolves');
    // Normalise CRLF: the assertions below quote multi-line Kotlin and XML
    // snippets, and a Windows checkout must not change the answer.
    return file.readAsStringSync().replaceAll('\r\n', '\n');
  }

  test('the tasbih layout uses only RemoteViews-allowlisted views', () {
    final src = read(tasbihLayout);

    // `<Space` / `<View` with a word boundary — TextView/ImageView must not
    // match, so the boundary after the tag name is load-bearing.
    expect(RegExp(r'<Space[\s>]').hasMatch(src), isFalse,
        reason: 'Space is outside the RemoteViews allowlist; use margins');
    expect(RegExp(r'<View[\s>]').hasMatch(src), isFalse,
        reason: 'a plain View is outside the allowlist; a 1dp TextView '
            'draws the same hairline');
    expect(RegExp(r'<FrameLayout[\s>]').hasMatch(src), isTrue,
        reason: 'the card is a FrameLayout with the gradient behind it');
  });

  test('the tasbih layout declares no view class of our own', () {
    // The MIUI failure was a custom `@RemoteViews.RemoteView` class inside a
    // nested RemoteViews. Nothing in res/layout may name one.
    expect(RegExp(r'<com\.islamic\.tawheeed\.').hasMatch(read(tasbihLayout)),
        isFalse,
        reason: 'a custom view class here is the composition MIUI dropped '
            'silently; use a framework view');
  });

  test('no custom RemoteViews view class survives anywhere', () {
    // LatinWidgetViews.kt was deleted with its tests. If the annotation comes
    // back anywhere in the widget package, the MIUI failure comes back too.
    // Only CODE lines count: the surviving KDocs deliberately name the deleted
    // classes to explain why they are gone.
    final dir = Directory(widgetDir);
    expect(dir.existsSync(), isTrue);
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.kt')) continue;
      final src = entity
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(src, isNot(contains('@RemoteViews.RemoteView')),
          reason: '${entity.path} declares a custom RemoteViews view — that is '
              'what MIUI refused to inflate');
      expect(src, isNot(contains('class LatinClockView')));
      expect(src, isNot(contains('class LatinCountdownView')));
    }
  });

  test('the ticking leaves stay deleted', () {
    // They formatted with the launcher's locale, stopped silently at 00:00 and
    // could disagree with the baked string by a whole minute.
    for (final gone in [
      '$widgetDir/WidgetLiveLeaves.kt',
      'android/app/src/main/res/layout/widget_live_clock.xml',
      'android/app/src/main/res/layout/widget_live_countdown.xml',
    ]) {
      expect(File(gone).existsSync(), isFalse,
          reason: '$gone is back — the card no longer ticks itself, and a '
              're-added leaf reintroduces launcher-locale digits');
    }
    for (final entity in Directory(widgetDir).listSync()) {
      if (entity is! File || !entity.path.endsWith('.kt')) continue;
      // Only CODE lines count, exactly as in the class-name scan above: the
      // live PrayerNativeViews.kt names the token in its KDoc to explain why
      // Glance was abandoned, and that prose is not a nested leaf.
      final src = entity
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(src, isNot(contains('AndroidRemoteViews')),
          reason: '${entity.path} nests a RemoteViews leaf; nothing on either '
              'card does that any more');
    }
  });

  test('the tasbih card carries the app\'s own font', () {
    // Calibri is the app's brand font (assets/fonts/calibri.ttf, mirrored to
    // res/font so RemoteViews can resolve it). Before this the card inherited
    // the launcher's default and read as a different app on the same screen.
    final src = read(tasbihLayout);
    expect(src, contains('android:fontFamily="@font/calibri"'),
        reason: 'the card must use the app font, not the launcher default');
    expect(File('android/app/src/main/res/font/calibri.ttf').existsSync(),
        isTrue,
        reason: 'the font resource the layout names must exist');
  });

  test('the tasbih digits keep one advance width', () {
    // A counter that repaints on every bead must not jitter. Calibri is
    // proportional, so `tnum` is what keeps «11» and «18» the same width.
    final src = read(tasbihLayout);
    expect(src, contains('android:fontFeatureSettings="tnum"'),
        reason: 'tabular figures are what stop the count and the pills from '
            'reflowing as the digits change');
  });

  test('the whole card is the +1 target, not just the ring', () {
    final views =
        read('$widgetDir/TasbihNativeViews.kt');
    expect(views, contains('R.id.tasbih_root,\n            tapIntent('),
        reason: 'the increment listener belongs on the root: the user expects '
            'a tap anywhere on the card to count');
    expect(views, isNot(contains('R.id.tasbih_ring_box,\n            tapIntent(')),
        reason: 'a listener on the ring only made the disc tappable');
  });
}
