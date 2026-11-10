import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';

void main() {
  group('drainedTasbihCounts — pending widget tap events', () {
    const zikrList = ['سبحان الله', 'الحمد لله', 'الله اکبر'];

    test('inc events add their delta additively', () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'inc', 'z': 0, 'd': 3},
          {'s': 2, 'k': 'inc', 'z': 0, 'd': 2},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10, 'الحمد لله': 5},
        appliedSeq: 0,
      );
      expect(result['سبحان الله'], 15);
      expect(result['الحمد لله'], 5);
    });

    test('events at or below the applied seq are ignored (idempotent retry)',
        () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'inc', 'z': 0, 'd': 3},
          {'s': 2, 'k': 'inc', 'z': 0, 'd': 2},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10},
        appliedSeq: 1,
      );
      expect(result['سبحان الله'], 12);
    });

    test('reset zeroes one zikr; z = -1 zeroes them all (daily reset)', () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'reset', 'z': 1},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10, 'الحمد لله': 5, 'الله اکبر': 7},
        appliedSeq: 0,
      );
      expect(result['الحمد لله'], 0);
      expect(result['سبحان الله'], 10);
      expect(result['الله اکبر'], 7);

      final all = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'reset', 'z': -1},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10, 'الحمد لله': 5, 'الله اکبر': 7},
        appliedSeq: 0,
      );
      expect(all.values.every((c) => c == 0), isTrue);
    });

    test('full (queue-collapse) event sets committed counts exactly', () {
      final result = drainedTasbihCounts(
        events: const [
          {
            's': 9,
            'k': 'full',
            'c': {'0': 41, '2': 3},
          },
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10, 'الحمد لله': 5, 'الله اکبر': 7},
        appliedSeq: 0,
      );
      expect(result['سبحان الله'], 41);
      expect(result['الحمد لله'], 5);
      expect(result['الله اکبر'], 3);
    });

    test('zikr (selection) events never touch counters', () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'zikr', 'z': 2},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10},
        appliedSeq: 0,
      );
      expect(result['سبحان الله'], 10);
    });

    test('out-of-range indices and unknown zikrs are skipped', () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'inc', 'z': 7, 'd': 3},
          {'s': 2, 'k': 'inc', 'z': 1, 'd': 4},
        ],
        zikrList: zikrList,
        appCounts: const {'الحمد لله': 5},
        appliedSeq: 0,
      );
      expect(result['الحمد لله'], 9);
      expect(result.containsKey('سبحان الله'), isFalse);
    });

    test('inc then reset keeps the reset (sequence order matters)', () {
      final result = drainedTasbihCounts(
        events: const [
          {'s': 1, 'k': 'inc', 'z': 0, 'd': 5},
          {'s': 2, 'k': 'reset', 'z': 0},
        ],
        zikrList: zikrList,
        appCounts: const {'سبحان الله': 10},
        appliedSeq: 0,
      );
      expect(result['سبحان الله'], 0);
    });
  });

  group('mergedTasbihCount — last interaction wins', () {
    test('widget is the latest editor → widget count wins exactly', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: true,
          widgetCount: 12,
          appCount: 0,
          widgetBeforeResetBoundary: false,
        ),
        12,
      );
    });

    test('widget is the latest editor → widget-side reset reaches the app', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: true,
          widgetCount: 0,
          appCount: 33,
          widgetBeforeResetBoundary: false,
        ),
        0,
      );
    });

    test('app is the latest editor → a higher widget count still advances', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: false,
          widgetCount: 40,
          appCount: 33,
          widgetBeforeResetBoundary: false,
        ),
        40,
      );
    });

    test('app is the latest editor → a stale lower widget count never erases',
        () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: false,
          widgetCount: 5,
          appCount: 33,
          widgetBeforeResetBoundary: false,
        ),
        33,
      );
    });

    test('equal counts are a no-op', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: false,
          widgetCount: 33,
          appCount: 33,
          widgetBeforeResetBoundary: false,
        ),
        33,
      );
      expect(
        mergedTasbihCount(
          widgetIsLatest: true,
          widgetCount: 0,
          appCount: 0,
          widgetBeforeResetBoundary: false,
        ),
        0,
      );
    });
  });

  group('mergedTasbihCount — daily reset boundary', () {
    test(
        'counts written before the reset boundary never resurrect after a '
        'reset (app wins exactly, even against a higher widget count)', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: false,
          widgetCount: 40,
          appCount: 0,
          widgetBeforeResetBoundary: true,
        ),
        0,
      );
    });

    test(
        'counts written before the reset boundary cannot resurrect a higher '
        'pre-reset widget count either', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: true,
          widgetCount: 12,
          appCount: 5,
          widgetBeforeResetBoundary: true,
        ),
        5,
      );
    });

    test('counts recorded after the reset boundary merge normally', () {
      expect(
        mergedTasbihCount(
          widgetIsLatest: false,
          widgetCount: 40,
          appCount: 33,
          widgetBeforeResetBoundary: false,
        ),
        40,
      );
      expect(
        mergedTasbihCount(
          widgetIsLatest: true,
          widgetCount: 12,
          appCount: 0,
          widgetBeforeResetBoundary: false,
        ),
        12,
      );
    });
  });

  group('drain → merge ordering', () {
    // The drain runs first and hands its applied dhikr texts to the counts
    // merge, which must skip them: the widget's per-zikr snapshot still
    // holds the pre-drain values (the push that re-aligns it runs at the end
    // of the sync), so re-merging would roll the freshly imported taps back —
    // on the 2026-10-16 device state that would have wiped a 103-tap import
    // to the widget's stale 0 one line after the ack pruned the queue. No
    // pure function reaches this ordering, so the source is scanned instead.
    test('dhikrs the drain just wrote are excluded from the merge', () {
      final src = File('lib/shared/services/widget_sync_service.dart')
          .readAsStringSync();
      expect(src,
          contains('final drainedTexts = await _drainPendingTasbihEvents('),
          reason: 'the drain must hand its applied dhikr texts to the merge');
      expect(src, contains('if (drainedTexts.contains(dhikrText)) continue;'),
          reason: 'without this skip the merge re-writes the stale widget '
              'value over the drain\'s import in the same sync');
    });

    test('a push counts as an app-side edit, not a widget tap', () {
      final src = File('lib/shared/services/widget_sync_service.dart')
          .readAsStringSync();
      // The push stamps WidgetRepository.persistSnapshot's last_tap_at on
      // the native side; the app-change stamp must follow the push so the
      // next reconcile cannot read that stamp as "the user tapped the widget
      // after the app" — the 2026-10-16 rollback path: the second sync pass
      // of the same boot re-wrote the widget's pre-import counts over the
      // drain's fresh import.
      final pushIdx = src.indexOf('await widgetSync.syncSnapshot(snapshot);');
      expect(pushIdx, greaterThan(-1));
      final stampAfterPush =
          src.indexOf('await _markAppChangedNow();', pushIdx);
      expect(stampAfterPush, greaterThan(pushIdx),
          reason: 'without this stamp the next merge pass lets the widget\'s '
              'just-pushed copy roll a drain import back');
      // The drain import is an app-side change too: if the push after it
      // fails, the stamp is what keeps the widget from looking like the
      // latest editor on the next boot.
      expect(
          src,
          contains(
              'if (appliedTexts.isNotEmpty) await _markAppChangedNow();'));
    });

    test('the snapshot is rebuilt from fresh counts after the drain', () {
      final src = File('lib/shared/services/widget_sync_service.dart')
          .readAsStringSync();
      // The drain invalidates tasbihProvider; awaiting its rebuild is what
      // keeps the push from carrying the stale pre-import value (which the
      // next pass would then treat as the widget's latest edit).
      final reconcileIdx =
          src.indexOf('await reconcileTasbihFromWidget(ref);');
      expect(reconcileIdx, greaterThan(-1));
      final freshIdx =
          src.indexOf('await ref.read(tasbihProvider.future);', reconcileIdx);
      expect(freshIdx, greaterThan(reconcileIdx),
          reason: 'the pushed snapshot must read the post-drain counts');
    });
  });
}
