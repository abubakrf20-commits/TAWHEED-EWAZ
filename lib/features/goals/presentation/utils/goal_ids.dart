import 'package:tawheeed/shared/utils/entity_ids.dart';

/// Primary-key strategy for the goals feature.
///
/// Ids used to be `DateTime.now().millisecondsSinceEpoch.toString()` on the
/// goal row and `microsecondsSinceEpoch` on progress rows. Two problems:
///
///  * A wall-clock id is not unique. Two goals saved inside the same
///    millisecond collide, and because the write is
///    `insertOnConflictUpdate`, the second one silently REPLACES the first
///    goal row — while the first goal's progress rows still point at that id
///    and so re-attach themselves to the new goal.
///  * The two tables used different precisions of the same non-unique
///    source, so a parent and a child row could not even be reasoned about
///    together.
///
/// Both id minters now share the counter+random scheme in
/// [newEntityId], which tasks and reminders use too.
String newGoalId() => newEntityId();

/// A fresh id for a manually logged progress entry.
String newProgressId() => newEntityId();

/// The id of the single «done today» row of a boolean goal.
///
/// Deliberately derived from (goal, day) instead of random:
///
///  * Tapping the toggle twice is idempotent — the second write updates the
///    same row instead of adding a second completion.
///  * Undo deletes exactly this id. The old toggle scanned the whole history
///    and deleted EVERY positive entry for today, so a numeric entry logged
///    the same day was destroyed along with the boolean check.
String booleanProgressId(String goalId, String date) => 'bool_${goalId}_$date';
