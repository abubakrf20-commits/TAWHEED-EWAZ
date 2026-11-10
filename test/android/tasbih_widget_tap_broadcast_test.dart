import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the tasbih card's tap plumbing **after it left Glance**.
///
/// History, because every rule below is here for a measured failure:
///
/// 1. RemoteViews build: taps were PendingIntents, so the exported receiver
///    had to verify `intent.package` (audit 5.1) — an explicit
///    `Intent(context, cls)` sets only the component, and a missing
///    `setPackage` made every tap look foreign.
/// 2. Glance build: taps became `ActionCallback`s, but this launcher drops a
///    frozen app's widget broadcast, so the card kept drawing while every
///    button was dead. A widget activity PendingIntent always starts, so taps
///    went through `TasbihActionActivity`.
/// 3. 2026-10-29 — **the real defect**: Glance 1.2.0 composes once per process
///    here, so `GlanceAppWidget.update()` re-applied the cached tree and the
///    card never repainted (four taps, four `paint`, ONE `compose`; the number
///    sat still while prefs advanced). The card is hand-built RemoteViews now
///    and a tap is one `partiallyUpdateAppWidget`.
///
/// Dart tests never compile Kotlin, so this scans the sources.
void main() {
  const dir = 'android/app/src/main/kotlin/com/islamic/tawheeed/widget';
  const receiverPath = '$dir/TasbihGlanceWidgetReceiver.kt';
  const viewsPath = '$dir/TasbihNativeViews.kt';
  const enginePath = '$dir/TasbihTapEngine.kt';
  const activityPath = '$dir/TasbihActionActivity.kt';
  // v2 is the locked generation (widget_lock.json; cf17ada renamed the file).
  const layoutPath =
      'android/app/src/main/res/layout/widget_tasbih_native_v2.xml';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue,
        reason: 'run from the project root so $path resolves');
    return file.readAsStringSync();
  }

  /// Code only. The KDocs in this package name the mechanisms they replaced —
  /// `GlanceAppWidget`, `requestRender`, `LatinClockView` — precisely so the
  /// next reader knows why they are gone. A raw substring scan would flag the
  /// explanation and force the history out of the source.
  String code(String path) => read(path)
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('the receiver is a plain AppWidgetProvider, not a Glance host', () {
    final src = read(receiverPath);
    expect(
        src,
        contains(
            'class TasbihGlanceWidgetReceiver : AppWidgetProvider()'),
        reason: 'the Glance session is what froze the card');
    for (final forbidden in [
      'GlanceAppWidgetReceiver',
      'glanceAppWidget',
      'provideContent',
      'GlanceAppWidget',
    ]) {
      expect(code(receiverPath), isNot(contains(forbidden)),
          reason: '$forbidden would put the card back on a session that '
              'composes once per process');
    }
    // The class NAME stays: the provider component keys the placed widget, so
    // renaming it would orphan the card already on the user's home screen.
    expect(src, contains('The class name is historical'),
        reason: 'keep the note explaining why the name is not "TasbihWidget"');
  });

  test('a tap repaints partially; a full render is reserved', () {
    final receiverSrc = read(receiverPath);
    // The merge is the whole point: the launcher applies only the setters we
    // send into the view it already inflated — no re-inflation, no
    // composition, and the ~750 KB surface bitmap never crosses the binder.
    expect(receiverSrc,
        contains('manager.partiallyUpdateAppWidget(widgetId, views)'),
        reason: 'a tap must merge into the existing view');
    expect(receiverSrc, contains('manager.updateAppWidget(widgetId, views)'),
        reason: 'placement/resize/restore still need a full render');
    expect(
        RegExp(r'render\(context, manager, widgetId, full = false\)')
            .hasMatch(receiverSrc),
        isTrue,
        reason: 'the tap path must ask for the partial render');
    expect(
        RegExp(r'render\(context, appWidgetManager, id, full = true\)')
            .hasMatch(receiverSrc),
        isTrue,
        reason: 'onUpdate must ask for the full render');

    final viewsSrc = read(viewsPath);
    // `partial()` must not bind the surface. Binding it would push ~750 KB of
    // gradient through a binder on every bead, which is the cost this
    // architecture exists to avoid.
    final partialBody = viewsSrc.substring(
      viewsSrc.indexOf('fun partial('),
      viewsSrc.indexOf('// ── Bindings'),
    );
    expect(partialBody, isNot(contains('bindSurface')),
        reason: 'the surface cannot change on a tap — do not re-send it');
    expect(partialBody, isNot(contains('bindMetrics')),
        reason: 'the type sizes cannot change on a tap');
    expect(partialBody, isNot(contains('bindClicks')),
        reason: 'the tap intents are identical on every bead');
    expect(partialBody, contains('bindState'),
        reason: 'partial() exists to bind exactly the counter');
  });

  test('the tap intent is per widget, so two cards never collide', () {
    final src = read(viewsPath);
    expect(src, contains('val requestCode = widgetId * 10 + actionCode(action)'),
        reason: 'a shared request code makes the second card move the first '
            "card's counter");
    expect(src, contains('PendingIntent.FLAG_IMMUTABLE'),
        reason: 'the launcher must not be able to edit the tap extras');
    expect(src, contains('PendingIntent.getBroadcast'),
        reason: 'a broadcast skips the window, the activity record and the '
            'lifecycle — most of a cold start');
    expect(
        src,
        contains(
            'putExtra(TasbihGlanceWidgetReceiver.EXTRA_APP_WIDGET_ID'),
        reason: 'without the id the tap can only do a full render of every '
            'instance');
  });

  test('the legacy sender guard still verifies taps', () {
    final src = read(receiverPath);
    expect(src, contains('intent.`package`'),
        reason: 'the exported receiver must keep verifying broadcast senders');
    expect(src, contains('dropped foreign tasbih broadcast'),
        reason: 'the guard that pairs with the broadcast tap path is gone');
  });

  test('no RemoteViews API above minSdk is called unguarded', () {
    // `setColorStateList` is API 31 and this module ships minSdk 24: an
    // unguarded call is a NoSuchMethodError on Android 7–11, thrown while the
    // launcher applies the update. Every tint goes through one helper.
    final src = code(viewsPath);
    expect(src, contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.S'),
        reason: 'both API-31 calls must be behind the version check');
    expect(RegExp(r'setColorStateList\(').allMatches(src).length, 1,
        reason: 'exactly one call site, inside tintBackground()');
    expect(src, contains('fun tintBackground('),
        reason: 'the pre-31 fallback lives in one place');
    expect(src, contains('views.setInt(id, "setBackgroundColor", color)'),
        reason: 'below 31 a flat colour keeps the row legible instead of '
            'crashing the update');
    // The ring's box IS the bitmap (`wrap_content` in the layout).
    // `setViewLayoutWidth(id, dp, 0)` landed as PIXELS on the launcher
    // (box 119dp rendered 117px), so no call may come back: one owner
    // for the size, and the count is sized from the same number.
    expect(src, isNot(contains('setViewLayoutWidth(')));
    expect(src, isNot(contains('setViewLayoutHeight(')));
  });

  test('the trampoline stays a registered, invisible, finishing fallback', () {
    final src = read(activityPath);
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    expect(src, contains('TasbihTapEngine.applyTap('),
        reason: 'the trampoline must run the shared tap state machine');
    expect(src, contains('TasbihGlanceWidgetReceiver.renderAll(this)'),
        reason: 'the fallback must repaint synchronously — the old code '
            'waited on a render queue that no longer exists');
    expect(src, contains('finish()'),
        reason: 'the trampoline must never stay in front of the launcher');
    expect(src, contains('FLAG_NOT_TOUCHABLE'),
        reason: 'a translucent window that ACCEPTS touch eats the next tap, so '
            'every other bead vanished (device 2026-10-25)');
    expect(src, contains('onNewIntent'),
        reason: 'a second tap reuses the live instance — it must still count');
    expect(manifest, contains('android:name=".widget.TasbihActionActivity"'),
        reason: 'an unregistered activity crashes the tap');
    expect(manifest, contains('Theme.Translucent.NoTitleBar'),
        reason: 'a solid theme would flash a blank screen on every bead');
    expect(manifest, contains('android:noHistory="true"'),
        reason: 'the trampoline must not enter the back stack');
    // It is a FALLBACK: the broadcast path is the default and the pref picks
    // the activity only when a launcher proved it drops broadcasts.
    expect(read(viewsPath), contains('WidgetPrefs.useActivityTaps('),
        reason: 'the delivery must stay a pref, not a hard-coded path');
  });

  test('taps render once: no animation and no second repaint', () {
    // A 12-frame bead animation re-rendered the ring twelve times per tap, and
    // a +1.5 s "heal" repaint doubled every bead's cost. Both are gone.
    for (final path in [receiverPath, enginePath, activityPath, viewsPath]) {
      final src = code(path);
      for (final token in [
        'startBeadAnimation',
        'displayedProgress',
        'activeAnimations',
        'activeResults',
        'ringProgressOverride',
        'scheduleHealRepaint',
        'requestRender',
      ]) {
        expect(src, isNot(contains(token)),
            reason: '$token would reintroduce a second frame per bead');
      }
    }
  });

  test('the full circle is kept: a track, no rim/halo/glow', () {
    final src = read('$dir/WidgetArt.kt');
    expect(src, contains('trackPaint'),
        reason: 'the full-circle track is the requested design');
    expect(src, contains('0.18f'),
        reason: 'the track alpha is a design value; changing it silently '
            'weakens the approved ring');
    for (final forbidden in ['haloPaint', 'rimPaint', 'glowPaint']) {
      expect(src, isNot(contains(forbidden)),
          reason: 'no $forbidden may be added');
    }
  });

  test('the ring is one track and one arc — no beads', () {
    final src = read('$dir/WidgetArt.kt');
    expect(src, contains('canvas.drawCircle(half, half, radius, trackPaint)'),
        reason: 'the track is the whole circle');
    expect(src, contains("360f * progressFraction"),
        reason: "the progress is one arc from 12 o'clock");
    expect(src, contains('strokeCap = Paint.Cap.ROUND'));
    expect(src, contains('RING_PROGRESS_STEP'),
        reason: 'the ring quantises its progress so a bead can reuse the '
            'previous bitmap instead of allocating a new one');
    expect(src, isNot(contains('BEAD_COUNT')));
    expect(src, isNot(contains('leadRadius')));
    expect(src, isNot(contains('for (i in 0 until')));
  });

  test('the ring bitmap is sized from the box, not a fixed cap', () {
    // Device 2026-11-04: the density cap was retired because it caused the
    // «دایره خیلی کوچک» report — at 2.5x on a 3.25x screen a "119 dp" box
    // painted at 91.7 dp (a 23 % shrink). The ring now paints at the REAL
    // device density and is capped in PIXELS only, so dp and pixels cannot
    // disagree while the binder payload stays bounded.
    final art = read('$dir/WidgetArt.kt');
    final views = read('$dir/TasbihNativeViews.kt');
    expect(art, contains('RING_MAX_PX'));
    expect(art, contains('sizePx.coerceIn(96, RING_MAX_PX)'));
    expect(views, contains('(boxDp * density).toInt()'));
    expect(views, contains('WidgetArt.RING_MAX_PX'));
    expect(views, contains('WidgetArt.RING_INK_FRACTION'));
    expect(views, isNot(contains('RING_MAX_DENSITY')));
  });

  test('no widget text carries the old halo style', () {
    final layout = read(layoutPath);
    expect(layout, isNot(contains('WidgetShadowText')),
        reason: 'the halo is gone — do not reintroduce it on tasbih texts');
    final preview = read(
        'lib/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart');
    expect(preview, isNot(contains('shadows:')),
        reason: 'the preview must mirror the native widget: no halo');
  });

  test('every view the code binds exists in the layout', () {
    // A RemoteViews action on a missing id is skipped SILENTLY — the card
    // renders half-bound with no error anywhere. This is the only place that
    // can catch it without a device.
    final layout = read(layoutPath);
    final views = read(viewsPath);
    final ids = RegExp(r'R\.id\.([a-z_]+)')
        .allMatches(views)
        .map((m) => m.group(1)!)
        .toSet();
    expect(ids, isNotEmpty, reason: 'no R.id references found — parser drift');
    for (final id in ids) {
      expect(layout, contains('@+id/$id'),
          reason: 'widget_tasbih_native_v2.xml has no @+id/$id, so every setter '
              'for it is dropped silently');
    }
  });

  test('the card counts only: the header no longer opens the app', () {
    final layout = read(layoutPath);
    final views = code(viewsPath);
    expect(layout, isNot(contains('EXTRA_SHORTCUT')));
    expect(views, isNot(contains('MainActivity')));
    // increment, reset, previous and next are the four taps.
    for (final action in [
      'ACTION_INCREMENT',
      'ACTION_RESET',
      'ACTION_PREV_ZIKR',
      'ACTION_NEXT_ZIKR',
    ]) {
      expect(views, contains('TasbihTapEngine.$action'),
          reason: 'the $action tap is no longer wired');
    }
  });

  test('the caption carries the day total and the ring speaks its count', () {
    final model = read('$dir/TasbihWidgetModel.kt');
    expect(model, contains('counts.values.sum()'),
        reason: 'the day total is the sum of the per-zikr counters, which '
            'all reset at midnight');
    expect(model, contains('امروز \$todayTotal'),
        reason: 'the caption dropped the «امروز N» half');
    expect(read(viewsPath), contains('state.accessibilityLabel(confirming)'),
        reason: 'the ring is the tap target — it must speak the counter');
  });

  test('the pending-queue reply crosses the channel as plain maps', () {
    // StandardMessageCodec cannot encode org.json values: a reply carrying one
    // JSONObject fails the WHOLE getTasbihData reply (found on-device
    // 2026-10-16 — «Unsupported value: ... of type JSONObject»), so the drain
    // never ran and taps piled up for days.
    final receiverSrc = read(receiverPath);
    final mainSrc =
        read('android/app/src/main/kotlin/com/islamic/tawheeed/MainActivity.kt');

    expect(receiverSrc, contains('fun plainEvents('),
        reason: 'the JSONObject→Map conversion is gone; every getTasbihData '
            'reply will fail to encode again');
    expect(mainSrc, contains('TasbihGlanceWidgetReceiver.plainEvents('),
        reason: 'getTasbihData must build the queue through plainEvents()');
    expect(mainSrc, isNot(contains('mapNotNull { pending.optJSONObject(it) }')),
        reason: 'a raw List<JSONObject> in the reply is the exact defect this '
            'guard exists for');
  });

  test('no widget variant lets the OS poll (updatePeriodMillis=0)', () {
    // Android 12+ reads the res/xml-v31 copy, and that twin had drifted once.
    for (final path in [
      'android/app/src/main/res/xml/widget_tasbih_info.xml',
      'android/app/src/main/res/xml/widget_prayer_info.xml',
      'android/app/src/main/res/xml-v31/widget_tasbih_info.xml',
      'android/app/src/main/res/xml-v31/widget_prayer_info.xml',
    ]) {
      final src = read(path);
      final match =
          RegExp(r'android:updatePeriodMillis="(\d+)"').firstMatch(src);
      expect(match, isNotNull,
          reason: '$path must declare updatePeriodMillis explicitly');
      expect(match?.group(1), '0',
          reason: '$path would let the OS wake the app to re-render — polling '
              'is not how either widget stays fresh');
    }
  });

  test('a resize re-renders under the token guard', () {
    final src = read(receiverPath);
    expect(
      RegExp(
        r'override fun onAppWidgetOptionsChanged[\s\S]{0,700}?'
        r'try \{\s*WidgetTokens\.init\(context\)[\s\S]{0,200}?'
        r'render\(context, appWidgetManager, appWidgetId, full = true\)',
      ).hasMatch(src),
      isTrue,
      reason: 'a resize changes the cell box every size is derived from, so it '
          'must be a full render — and the tokens must exist before it reads '
          'them (an uninitialised token set paints empty defaults)',
    );
    expect(src, contains('onOptionsChanged failed'),
        reason: 'a guarded resize must log its failure for logcat diagnosis');
  });

  test('the widget self-heals: restore, watchdog and midnight reset', () {
    final src = read(receiverPath);

    expect(RegExp(r'override fun onRestored[\s\S]{0,400}?onUpdate\(')
            .hasMatch(src),
        isTrue,
        reason: 'a restored widget receives ids without onUpdate — it must '
            'render');
    expect(src, contains('ACTION_WATCHDOG = "com.tawheeed.TASBIH_WATCHDOG"'));
    expect(
        src,
        contains(
            'ACTION_MIDNIGHT_RESET = "com.tawheeed.TASBIH_MIDNIGHT_RESET"'));
    expect(src, contains('WATCHDOG_REQUEST_CODE = 9996'));
    expect(src, contains('MIDNIGHT_REQUEST_CODE = 9995'));
    expect(src, contains('WATCHDOG_INTERVAL_MS = 6 * 60 * 60 * 1000L'));
    expect(src, contains('setAndAllowWhileIdle'),
        reason: 'a plain set() is deferred in Doze — the watchdog must allow '
            'while idle');
    expect(src, contains('canScheduleExactAlarms()'),
        reason: 'an exact midnight alarm needs the API 31 capability check');
    expect(src, contains('setExactAndAllowWhileIdle'));
    expect(
      RegExp(r'catch \(_:\s*SecurityException\)[\s\S]{0,200}?'
              r'setAndAllowWhileIdle')
          .hasMatch(src),
      isTrue,
      reason: 'a refused exact alarm must fall back, not crash the receiver',
    );
    expect(
        RegExp(r'override fun onEnabled[\s\S]{0,900}?rearmAll\(context\)')
            .hasMatch(src),
        isTrue,
        reason: 'onEnabled must arm the alarms even if the first render fails');
    expect(
      RegExp(r'override fun onDisabled[\s\S]{0,300}?cancelWatchdog\(context\)'
              r'[\s\S]{0,200}?cancelMidnightReset\(context\)')
          .hasMatch(src),
      isTrue,
      reason: 'the last removed widget must stop both alarms',
    );
  });

  test('framework broadcasts are dispatched by super, not re-rendered', () {
    final src = read(receiverPath);
    expect(src.indexOf('super.onReceive(context, intent)'),
        lessThan(src.indexOf('val action = intent.action')),
        reason: 'the framework dispatch must run before the custom branch');
    expect(
      RegExp(r'if \(action == ACTION_WATCHDOG \|\| action == ACTION_MIDNIGHT_RESET '
              r'\|\|\s*action == Intent\.ACTION_MY_PACKAGE_REPLACED\s*\)')
          .hasMatch(src),
      isTrue,
      reason: 'only the two alarm actions (and the reinstall pass) may render '
          'and re-arm',
    );
    expect(src, isNot(contains('else if (intent.action')),
        reason: 'no catch-all render may be added for framework broadcasts');
  });

  test('a removed card forgets its confirm window', () {
    final src = read(receiverPath);
    expect(
      RegExp(r'override fun onDeleted[\s\S]{0,400}?TasbihTapEngine\.forget\(')
          .hasMatch(src),
      isTrue,
      reason: 'the confirm deadline is keyed by widget id — a removed card must '
          'not leave an entry behind for a recycled id',
    );
    expect(read(enginePath), contains('fun forget(widgetKey: String)'));
  });
}
