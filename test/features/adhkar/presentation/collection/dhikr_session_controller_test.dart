import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';

ZikrItem _item(String id, {int repeat = 1}) => ZikrItem(
      id: id,
      title: 'title $id',
      arabicText: 'arabic $id',
      translation: 'translation $id',
      source: 'source $id',
      period: PrayerPeriod.fajr,
      repeatCount: repeat,
    );

void main() {
  group('counting', () {
    test('a single-repeat dhikr completes with one tap and never overshoots',
        () {
      final c = DhikrSessionController(items: [_item('a')]);
      expect(c.tap(0), isTrue);
      expect(c.isDone(0), isTrue);
      expect(c.countOf(0), 1);
      // A second tap on a finished item is not a second completion.
      expect(c.tap(0), isFalse);
      expect(c.countOf(0), 1);
      expect(c.doneCount, 1);
    });

    test('a counted dhikr walks to its target and stops there', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 3)]);
      expect(c.targetAt(0), 3);
      expect(c.tap(0), isFalse);
      expect(c.countOf(0), 1);
      expect(c.tap(0), isFalse);
      expect(c.countOf(0), 2);
      expect(c.tap(0), isTrue);
      expect(c.countOf(0), 3);
      expect(c.isDone(0), isTrue);
      // The clamp: nothing can push a count past its target.
      expect(c.tap(0), isFalse);
      expect(c.countOf(0), 3);
    });

    test('100 rapid taps on a target of 33 stop exactly at 33', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 33)]);
      for (var i = 0; i < 100; i++) {
        c.tap(0);
      }
      expect(c.countOf(0), 33);
      expect(c.isDone(0), isTrue);
      expect(c.doneCount, 1);
    });

    test('a missing repeat count is a target of 1, never inferred', () {
      final zero = ZikrItem(
        id: 'z',
        title: 't',
        arabicText: 'a',
        translation: 'tr',
        source: 's',
        period: PrayerPeriod.fajr,
        repeatCount: 0,
      );
      final c = DhikrSessionController(items: [zero]);
      expect(c.targetAt(0), 1);
      expect(c.tap(0), isTrue);
    });

    test('undo steps back by one, and reopens a finished item below target',
        () {
      final c = DhikrSessionController(items: [_item('a', repeat: 3)]);
      c.tap(0);
      c.tap(0);
      c.undo(0);
      expect(c.countOf(0), 1);
      c.tap(0);
      c.tap(0);
      expect(c.isDone(0), isTrue);
      c.undo(0);
      expect(c.isDone(0), isFalse);
      expect(c.countOf(0), 2);
      // Undo at zero is a no-op, not a negative count.
      final fresh = DhikrSessionController(items: [_item('b')]);
      fresh.undo(0);
      expect(fresh.countOf(0), 0);
    });

    test('completion notifies once and persists exactly that item', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      final touched = <int>[];
      c.onItemChanged = touched.add;
      c.complete(1);
      expect(touched, [1]);
      expect(c.isDone(1), isTrue);
      expect(c.isDone(0), isFalse);
    });

    test('the one tick reports once, and a repeat reports nothing', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 100)]);
      expect(c.complete(0), isTrue, reason: 'a hundred repetitions, one tick');
      expect(c.countOf(0), 100);
      expect(c.complete(0), isFalse,
          reason: 'already finished is not a second completion — a second '
              'report is a second cursor step');
      expect(c.setDone(0, true), isFalse);
    });

    test('un-ticking an untouched item invents no count', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 3)]);
      expect(c.setDone(0, false), isFalse);
      expect(c.countOf(0), 0,
          reason: 'the old path wrote target-1 onto a dhikr nobody tapped');
      expect(c.isStarted(0), isFalse);
      expect(c.doneCount, 0);
    });

    test('a skipped item keeps its count through skip, tick and undo', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 5)]);
      c.tap(0);
      c.tap(0);
      c.skip(0);
      expect(c.countOf(0), 2, reason: 'going back resumes where it stopped');
      c.unskip(0);
      expect(c.complete(0), isTrue);
      expect(c.isSkipped(0), isFalse,
          reason: 'a finished item is not passed over');
      expect(c.countOf(0), 5);
      c.undo(0);
      expect(c.countOf(0), 4, reason: 'the correction steps back, not to zero');
      expect(c.isSkipped(0), isFalse);
    });
  });

  group('skipping and navigation', () {
    test('skip marks without finishing and keeps the count', () {
      final c = DhikrSessionController(items: [
        _item('a', repeat: 3),
        _item('b'),
      ]);
      c.tap(0);
      c.skip(0);
      expect(c.isSkipped(0), isTrue);
      expect(c.isDone(0), isFalse);
      expect(c.countOf(0), 1, reason: 'going back resumes the count');
      expect(c.skippedIndexes, [0]);

      c.unskip(0);
      expect(c.isSkipped(0), isFalse);
    });

    test('nextUnfinishedAfter walks past done items and wraps once', () {
      final c = DhikrSessionController(items: [
        _item('a'),
        _item('b'),
        _item('c'),
      ]);
      c.complete(0);
      expect(c.nextUnfinishedAfter(0), 1);
      c.complete(1);
      expect(c.nextUnfinishedAfter(1), 2);
      c.complete(2);
      expect(c.nextUnfinishedAfter(2), -1);
    });

    test('advance goes to the first unfinished item and reports all done', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      c.goTo(0);
      c.complete(0);
      expect(c.advance(), 1);
      expect(c.currentIndex, 1);
      c.complete(1);
      expect(c.advance(), -1);
      expect(c.currentIndex, 1, reason: 'the last item stays current');
    });

    test('finishing an item moves no cursor — advance() is the only step', () {
      final c = DhikrSessionController(items: [
        _item('a'),
        _item('b'),
        _item('c'),
      ]);
      c.goTo(0);
      expect(c.tap(0), isTrue);
      expect(c.currentIndex, 0,
          reason: 'the completion tick itself must not step, or the page '
              'stepping too skips a dhikr');
      c.complete(2);
      expect(c.currentIndex, 0);
      expect(c.advance(), 1, reason: 'the one step lands on b, not past it');
      expect(c.currentIndex, 1);
    });

    test('firstUnfinished ignores skipped items but not wrapped ones', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      c.skip(0);
      expect(c.firstUnfinished, 1);
      c.skip(1);
      expect(c.firstUnfinished, -1);
    });

    test('goTo clamps to the collection', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      c.goTo(99);
      expect(c.currentIndex, 1);
      c.goTo(-5);
      expect(c.currentIndex, 0);
    });
  });

  group('bulk actions and derived values', () {
    test('markAll completes everything with each target count', () {
      final c = DhikrSessionController(items: [
        _item('a', repeat: 3),
        _item('b'),
        _item('c', repeat: 7),
      ]);
      c.markAll();
      expect(c.doneCount, 3);
      expect(c.countOf(0), 3);
      expect(c.countOf(2), 7);
      expect(c.progress, 1);
      expect(c.isComplete, isTrue);
    });

    test('resetAll returns every item and the cursor to the start', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 2), _item('b')]);
      c.tap(0);
      c.complete(1);
      c.goTo(1);
      c.resetAll();
      expect(c.doneCount, 0);
      expect(c.countOf(0), 0);
      expect(c.isDone(1), isFalse);
      expect(c.currentIndex, 0);
      expect(c.progress, 0);
    });

    test('percent and the segmented states describe the same session', () {
      final c = DhikrSessionController(items: [
        _item('a', repeat: 4),
        _item('b'),
        _item('c'),
        _item('d'),
      ]);
      c.tap(0);
      c.complete(1);
      expect(c.doneCount, 1);
      expect(c.progress, 0.25);
      expect(c.isStarted(0), isTrue);
      expect(c.isDone(0), isFalse);
    });

    test('bulk changes notify through onBulkChanged, not per item', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      var bulk = 0;
      var single = 0;
      c.onBulkChanged = () => bulk++;
      c.onItemChanged = (_) => single++;
      c.markAll();
      expect(bulk, 1);
      expect(single, 0);
    });
  });

  group('seeding from storage', () {
    test('a stored completion becomes a full count at its target', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 5)]);
      c.seed(done: {'a': true});
      expect(c.isDone(0), isTrue);
      expect(c.countOf(0), 5);
    });

    test('a stored partial count survives and stays below the target', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 5)]);
      c.seed(done: {'a': false}, counts: {'a': 2});
      expect(c.countOf(0), 2);
      expect(c.isDone(0), isFalse);
      expect(c.isStarted(0), isTrue);
    });

    test('a count stored above the target is clamped on the way in', () {
      final c = DhikrSessionController(items: [_item('a', repeat: 3)]);
      c.seed(done: const {}, counts: {'a': 99});
      expect(c.countOf(0), 3);
    });

    test('skipped ids are honoured, and done wins over skipped', () {
      final c = DhikrSessionController(items: [_item('a'), _item('b')]);
      c.seed(done: {'b': true}, skipped: {'a', 'b'});
      expect(c.isSkipped(0), isTrue);
      expect(c.isSkipped(1), isFalse);
      expect(c.isDone(1), isTrue);
    });

    test('the stored current item is restored, and a done one is skipped', () {
      final c = DhikrSessionController(items: [
        _item('a'),
        _item('b'),
        _item('c'),
      ]);
      c.seed(done: const {}, current: 2);
      expect(c.currentIndex, 2);

      final again = DhikrSessionController(items: [
        _item('a'),
        _item('b'),
        _item('c'),
      ]);
      again.seed(done: {'a': true, 'b': true}, current: 0);
      expect(again.currentIndex, 2);
    });

    test('the constructor opens exactly where seed would', () {
      final items = [_item('a'), _item('b'), _item('c')];
      // The stored cursor is index 0 — the default — and that item is already
      // finished, which is the case the restoration rule exists to correct.
      final opened = DhikrSessionController(
        items: items,
        initial: const {'a': DhikrEntry(count: 1, done: true)},
      );
      expect(opened.currentIndex, 1,
          reason: 'a stored cursor on a finished dhikr is not where the reader '
              'left off — the same rule seed() applies, not a second copy');

      final finished = DhikrSessionController(
        items: items,
        initial: const {
          'a': DhikrEntry(count: 1, done: true),
          'b': DhikrEntry(count: 1, done: true),
        },
        current: 2,
      );
      expect(finished.currentIndex, 2, reason: 'a complete collection keeps it');

      final seeded = DhikrSessionController(items: items)
        ..seed(
          done: const {'a': true, 'b': true},
          current: 0,
        );
      expect(seeded.currentIndex, 2);
    });

    test('seeding does not touch the persistence callbacks', () {
      final c = DhikrSessionController(items: [_item('a')]);
      var called = 0;
      c.onItemChanged = (_) => called++;
      c.onBulkChanged = () => called++;
      c.seed(done: {'a': true});
      expect(called, 0, reason: 'restoring is not a change to write back');
    });
  });
}
