import 'package:flutter/foundation.dart';

import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';

/// One item's place in a running session.
///
/// [count] is the number of repetitions already said, [done] is the completion
/// flag the adhkar provider has always kept, and [skipped] is the focus mode's
/// «رد کردن»: explicitly passed over, not finished.
@immutable
class DhikrEntry {
  const DhikrEntry({this.count = 0, this.done = false, this.skipped = false});

  final int count;
  final bool done;
  final bool skipped;

  DhikrEntry copyWith({int? count, bool? done, bool? skipped}) => DhikrEntry(
        count: count ?? this.count,
        done: done ?? this.done,
        skipped: skipped ?? this.skipped,
      );

  @override
  bool operator ==(Object other) =>
      other is DhikrEntry &&
      other.count == count &&
      other.done == done &&
      other.skipped == skipped;

  @override
  int get hashCode => Object.hash(count, done, skipped);

  @override
  String toString() => 'DhikrEntry(count: $count, done: $done, '
      'skipped: $skipped)';
}

/// The counting state of ONE dhikr collection, shared by all three view modes.
///
/// This is pure bookkeeping: no widgets, no persistence, no haptics. Every mode
/// renders this same object, so switching from «فهرست» to «تمرکز» mid-dhikr
/// cannot lose a count, and a mode can never disagree with another about what
/// is finished.
///
/// Counts are per item and clamped to that item's target (`repeatCount` from
/// the content file, never parsed out of the text). An item with no structured
/// count has a target of 1, which is what the content ships for most adhkar.
class DhikrSessionController extends ChangeNotifier {
  DhikrSessionController({
    required List<ZikrItem> items,
    Map<String, DhikrEntry> initial = const {},
    int current = 0,
  }) : _items = List<ZikrItem>.unmodifiable(items) {
    for (final item in items) {
      final stored = initial[item.id];
      if (stored != null) _entries[item.id] = stored;
    }
    _current = _restoreCursor(current);
  }

  /// Where the reader left off, made valid for this collection.
  ///
  /// Two corrections, both of which the constructor used to spell out inline:
  /// the stored index is clamped into range, and an index that points at an
  /// item already finished is not "left off" — the first unfinished item is.
  int _restoreCursor(int current) {
    final index = _clamp(current);
    if (_entryAt(index).done) {
      final next = firstUnfinished;
      if (next >= 0) return next;
    }
    return index;
  }

  /// The collection's items, in content order.
  final List<ZikrItem> _items;

  Map<String, DhikrEntry> _entries = {};

  int _current = 0;

  /// Called after a single item changed, so the page can persist just that one.
  ValueChanged<int>? onItemChanged;

  /// Called after a bulk change (mark all, reset all) where every item may
  /// have moved.
  VoidCallback? onBulkChanged;

  List<ZikrItem> get items => _items;

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  /// The repetition target of [index]. Never below 1 — a dhikr said once is
  /// complete with one tap.
  int targetAt(int index) {
    if (index < 0 || index >= _items.length) return 1;
    final repeat = _items[index].repeatCount;
    return repeat < 1 ? 1 : repeat;
  }

  /// How many times the reader has said [index] so far (clamped).
  int countOf(int index) {
    final entry = _entryAt(index);
    return entry.done ? targetAt(index) : entry.count;
  }

  bool isDone(int index) => _entryAt(index).done;

  bool isSkipped(int index) => _entryAt(index).skipped;

  /// True once at least one repetition was said at [index].
  bool isStarted(int index) => _entryAt(index).count > 0;

  DhikrEntry entryAt(int index) => _entryAt(index);

  /// Items finished so far.
  int get doneCount =>
      _items.indexed.where((pair) => _entryAt(pair.$1).done).length;

  int get skippedCount =>
      _items.indexed.where((pair) => _entryAt(pair.$1).skipped).length;

  int get remainingCount => length - doneCount;

  bool get isComplete => length > 0 && doneCount >= length;

  /// 0…1, for the progress ring and the segmented bar.
  double get progress => length == 0 ? 0 : doneCount / length;

  /// Indexed list of items that were skipped, for «برو به رد شده‌ها».
  List<int> get skippedIndexes => [
        for (var i = 0; i < length; i++)
          if (_entryAt(i).skipped && !_entryAt(i).done) i,
      ];

  /// The item the modes centre on.
  int get currentIndex => _clamp(_current);

  /// The first item that is neither finished nor skipped, or -1.
  int get firstUnfinished {
    for (var i = 0; i < length; i++) {
      final entry = _entryAt(i);
      if (!entry.done && !entry.skipped) return i;
    }
    return -1;
  }

  /// The next item still to do, starting at [from] + 1 and wrapping once.
  ///
  /// Skipped items are inside the answer: «رد کردن» passes over an item for
  /// now, it does not remove it from the session.
  int nextUnfinishedAfter(int from) {
    if (length == 0) return -1;
    for (var step = 1; step <= length; step++) {
      final index = (from + step) % length;
      if (!_entryAt(index).done) return index;
    }
    return -1;
  }

  /// +1 for one repetition. Completes the item at its target.
  ///
  /// Returns true when THIS tap finished the item, so the caller can play the
  /// stronger haptic and advance. Extra taps past the target are ignored
  /// rather than thrown away silently as an overshoot: the item stays done and
  /// the count never exceeds the target.
  bool tap(int index) {
    if (index < 0 || index >= length) return false;
    final entry = _entryAt(index);
    if (entry.done) return false;
    final target = targetAt(index);
    final next = entry.count + 1;
    if (next >= target) {
      _put(index, entry.copyWith(count: target, done: true, skipped: false));
      _notifyItem(index);
      return true;
    }
    _put(index, entry.copyWith(count: next, skipped: false));
    _notifyItem(index);
    return false;
  }

  /// -1, the undo button next to the focus ring.
  ///
  /// Undoing a finished item reopens it at one below its target, so the reader
  /// who tapped once too often can correct it without starting the dhikr over.
  void undo(int index) {
    if (index < 0 || index >= length) return;
    final entry = _entryAt(index);
    final target = targetAt(index);
    if (entry.done) {
      _put(index, entry.copyWith(count: target - 1, done: false));
      _notifyItem(index);
      return;
    }
    if (entry.count == 0) return;
    _put(index, entry.copyWith(count: entry.count - 1));
    _notifyItem(index);
  }

  /// Marks [index] finished in one step — the one-tick registration of a dhikr
  /// that would otherwise need a hundred taps, and the list card's checkbox.
  ///
  /// Returns true when THIS action finished the item, which is what tells the
  /// page to ask for the single «what is next» move. Re-completing an item that
  /// is already finished changes nothing and reports false.
  bool complete(int index) {
    if (index < 0 || index >= length) return false;
    final entry = _entryAt(index);
    if (entry.done) return false;
    _put(
      index,
      entry.copyWith(count: targetAt(index), done: true, skipped: false),
    );
    _notifyItem(index);
    return true;
  }

  /// Ticks or un-ticks an item from the list card.
  ///
  /// Un-ticking is the same correction the undo button makes, so the two can
  /// never disagree about what "one step back" means. Returns true only when
  /// the tick finished the item — an un-tick never moves the cursor.
  bool setDone(int index, bool value) {
    if (value) return complete(index);
    undo(index);
    return false;
  }

  /// «رد کردن»: pass over the item without finishing it.
  ///
  /// The count already accumulated is kept — going back to a skipped item
  /// resumes where it stopped, it does not throw repetitions away.
  void skip(int index) {
    if (index < 0 || index >= length) return;
    final entry = _entryAt(index);
    if (entry.done || entry.skipped) return;
    _put(index, entry.copyWith(skipped: true));
    _notifyItem(index);
  }

  /// Puts a skipped item back in the run.
  void unskip(int index) {
    if (index < 0 || index >= length) return;
    final entry = _entryAt(index);
    if (!entry.skipped) return;
    _put(index, entry.copyWith(skipped: false));
    _notifyItem(index);
  }

  /// Every item finished in one step — «انتخاب همه».
  void markAll() {
    if (length == 0) return;
    for (var i = 0; i < length; i++) {
      _put(
        i,
        DhikrEntry(count: targetAt(i), done: true),
      );
    }
    onBulkChanged?.call();
    notifyListeners();
  }

  /// «پاک کردن پیشرفت این مجموعه» — every item back to zero.
  void resetAll() {
    if (length == 0) return;
    _entries = {};
    _current = 0;
    onBulkChanged?.call();
    notifyListeners();
  }

  /// The mode made [index] the one being counted.
  void goTo(int index) {
    if (length == 0) return;
    final next = _clamp(index);
    if (next == _current) return;
    _current = next;
    notifyListeners();
  }

  /// The one «what is next» move: step to the next item still to do and return
  /// it (-1 when all are done, and then the cursor stays put).
  ///
  /// Every mode asks for the cursor to move through this method only. A mode
  /// that steps the cursor itself — or a page that both listens for the
  /// completion and advances after it — moves twice and silently passes over a
  /// dhikr, which is exactly the «برخی ذکرها رد می‌کند» defect.
  int advance() {
    final next = nextUnfinishedAfter(currentIndex);
    if (next >= 0) goTo(next);
    return next;
  }

  /// Re-seeds from storage after the provider finished loading. Stored
  /// completions always mean the whole target was said, so the count follows
  /// the target — the migration for sessions recorded before counts existed.
  void seed({
    required Map<String, bool> done,
    Map<String, int> counts = const {},
    Set<String> skipped = const {},
    int? current,
  }) {
    final seeded = <String, DhikrEntry>{};
    for (var i = 0; i < length; i++) {
      final item = _items[i];
      final target = targetAt(i);
      final isDone = done[item.id] ?? false;
      final count = isDone ? target : (counts[item.id] ?? 0).clamp(0, target);
      final isSkipped = !isDone && (skipped.contains(item.id));
      if (isDone || count > 0 || isSkipped) {
        seeded[item.id] = DhikrEntry(
          count: count,
          done: isDone,
          skipped: isSkipped,
        );
      }
    }
    _entries = seeded;
    _current = _restoreCursor(current ?? 0);
    notifyListeners();
  }

  DhikrEntry _entryAt(int index) {
    if (index < 0 || index >= _items.length) return const DhikrEntry();
    return _entries[_items[index].id] ?? const DhikrEntry();
  }

  void _put(int index, DhikrEntry entry) {
    _entries = {..._entries, _items[index].id: entry};
  }

  void _notifyItem(int index) {
    onItemChanged?.call(index);
    notifyListeners();
  }

  int _clamp(int index) {
    if (length == 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return length - 1;
    return index;
  }
}
