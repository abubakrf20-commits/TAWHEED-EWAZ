import 'dart:math';

/// Collision-resistant row ids for user data written with
/// `insertOnConflictUpdate`.
///
/// A wall-clock id is not unique: two rows minted in the same millisecond
/// collide, and the upsert then silently REPLACES the first row while its
/// child rows re-attach to the second. `millisecondsSinceEpoch +
/// nextInt(999999)` is a birthday problem, not a guarantee — 500 ids from
/// 999999 slots collide about 12% of the time.
///
/// `epoch_seq_random` makes uniqueness structural within a process (the
/// counter cannot repeat inside one microsecond) while the random half
/// covers the cross-process case. This is the scheme the goals feature
/// adopted after losing rows; tasks and reminders share it.
final _random = Random();

/// Per-process counter, so two ids minted in the same microsecond cannot
/// collide.
int _seq = 0;

int _nextSeq() {
  _seq = (_seq + 1) & 0x1FFFFF;
  return _seq;
}

/// `1748443200123456_5_482913` — sortable by creation time, unique.
String newEntityId() => '${DateTime.now().microsecondsSinceEpoch}_${_nextSeq()}'
    '_${_random.nextInt(1 << 20)}';
