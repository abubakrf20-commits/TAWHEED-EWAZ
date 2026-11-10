import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final dangiDaoProvider = Provider<DangiDao>((ref) {
  return DangiDao(ref.read(appDatabaseProvider));
});

/// Thrown when a write references a member that no longer belongs to the group
/// — a stale screen (the member was deleted elsewhere) would otherwise record
/// an expense or a settlement that nobody can ever be charged for.
class DangiStaleMemberException implements Exception {
  final String memberId;
  final String groupId;
  const DangiStaleMemberException(this.memberId, this.groupId);

  @override
  String toString() =>
      'DangiStaleMemberException: $memberId is not a member of $groupId';
}

class DangiDao {
  final AppDatabase db;
  DangiDao(this.db);

  /// Runs [action] in a single database transaction. Used for the multi-row
  /// operations (group + members, settlement batches, member removal) so a
  /// failure part-way cannot leave half-written state behind.
  Future<T> transaction<T>(Future<T> Function() action) =>
      db.transaction<T>(action);

  // ── Groups ────────────────────────────────────────────────────────

  Future<List<DangiGroupModel>> getAllGroups() async {
    final rows = await (db.select(db.dangiGroupTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toGroup).toList();
  }

  Future<DangiGroupModel?> getGroup(String id) async {
    final row = await (db.select(db.dangiGroupTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toGroup(row);
  }

  Future<void> upsertGroup(DangiGroupModel g) async {
    await db
        .into(db.dangiGroupTable)
        .insertOnConflictUpdate(DangiGroupTableData(
          id: g.id,
          name: g.name,
          colorHex: g.colorHex,
          createdAt: g.createdAt,
        ));
  }

  /// Creates a group together with its initial members in one transaction:
  /// a group whose members were only half-inserted would silently skew every
  /// balance.
  Future<void> createGroupWithMembers(
      DangiGroupModel g, List<DangiMemberModel> members) async {
    await transaction(() async {
      await upsertGroup(g);
      for (final m in members) {
        await _writeMember(m);
      }
    });
  }

  /// Deletes the group with all of its members and expenses — atomically, so
  /// a failure mid-way never leaves orphaned members/expenses behind.
  Future<void> deleteGroup(String id) async {
    await db.transaction(() async {
      await (db.delete(db.dangiExpenseTable)
            ..where((t) => t.groupId.equals(id)))
          .go();
      await (db.delete(db.dangiMemberTable)..where((t) => t.groupId.equals(id)))
          .go();
      await (db.delete(db.dangiGroupTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Re-inserts a deleted group with its exact prior members and expenses, so
  /// `deleteGroup` can be undone without recomputing anything. Uses the raw
  /// writers (no payer re-validation) because a captured snapshot is by
  /// definition internally consistent.
  Future<void> restoreGroup(DangiGroupSnapshot s) => transaction(() async {
        await upsertGroup(s.group);
        for (final m in s.members) {
          await _writeMember(m);
        }
        for (final e in s.expenses) {
          await _writeExpense(e);
        }
      });

  // ── Members ───────────────────────────────────────────────────────

  Future<List<DangiMemberModel>> getMembers(String groupId) async {
    final rows = await (db.select(db.dangiMemberTable)
          ..where((t) => t.groupId.equals(groupId)))
        .get();
    return rows.map(_toMember).toList();
  }

  Future<void> upsertMember(DangiMemberModel m) async {
    await _writeMember(m);
  }

  Future<void> _writeMember(DangiMemberModel m) async {
    await db
        .into(db.dangiMemberTable)
        .insertOnConflictUpdate(DangiMemberTableData(
          id: m.id,
          groupId: m.groupId,
          name: m.name,
          createdAt: m.createdAt,
        ));
  }

  /// Removes a member **of [groupId]** together with the expenses they paid in
  /// that group.
  ///
  /// Group-scoped on purpose: the previous version ignored [groupId], so a
  /// stale id from another group could take out rows it had nothing to do with.
  /// Returns whether the member existed, so callers can skip pointless reloads.
  ///
  /// The member delete is scoped by [groupId] as well. Today `DangiMemberTable`
  /// keys on `id` alone, so this matches the row the lookup above already
  /// found; keeping both predicates aligned means the delete stays correct if
  /// the key ever becomes `(id, groupId)`.
  Future<bool> deleteMember(String id, String groupId) async {
    return transaction(() async {
      final member = await (db.select(db.dangiMemberTable)
            ..where((t) => t.id.equals(id) & t.groupId.equals(groupId)))
          .getSingleOrNull();
      if (member == null) return false;
      await (db.delete(db.dangiExpenseTable)
            ..where((t) => t.groupId.equals(groupId) & t.payerId.equals(id)))
          .go();
      await (db.delete(db.dangiMemberTable)
            ..where((t) => t.id.equals(id) & t.groupId.equals(groupId)))
          .go();
      return true;
    });
  }

  /// Strips [memberId] from the per-member consumer list of every expense in
  /// [expenseIds] (used when a member is deleted, so their share never
  /// silently survives in another expense's consumers).
  Future<void> removeConsumerFromExpenses(
      List<String> expenseIds, String memberId) async {
    if (expenseIds.isEmpty) return;
    await db.transaction(() async {
      for (final id in expenseIds) {
        final row = await (db.select(db.dangiExpenseTable)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (row == null) continue;
        final consumers = consumersFromJson(row.consumersJson);
        if (!consumers.containsKey(memberId)) continue;
        consumers.remove(memberId);
        await (db.update(db.dangiExpenseTable)..where((t) => t.id.equals(id)))
            .write(DangiExpenseTableData(
          id: row.id,
          groupId: row.groupId,
          payerId: row.payerId,
          title: row.title,
          category: row.category,
          amount: row.amount,
          date: row.date,
          createdAt: row.createdAt,
          consumersJson: consumersToJson(consumers),
        ));
      }
    });
  }

  /// Re-inserts a deleted member, the expenses they paid, and the full original
  /// rows of the expenses whose consumer share had been stripped — restoring
  /// the exact pre-delete state in one transaction. Uses the raw writers so a
  /// consistent snapshot needs no payer re-validation.
  Future<void> restoreMember(DangiMemberSnapshot s) => transaction(() async {
        await _writeMember(s.member);
        for (final e in s.strippedExpenses) {
          await _writeExpense(e);
        }
        for (final e in s.ownExpenses) {
          await _writeExpense(e);
        }
      });

  // ── Expenses ──────────────────────────────────────────────────────

  Future<List<DangiExpenseModel>> getExpenses(String groupId) async {
    final rows = await (db.select(db.dangiExpenseTable)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toExpense).toList();
  }

  /// Writes an expense, rejecting a payer that is not a member of the expense's
  /// group. A group with no members at all is left alone (nothing to validate
  /// against, and legacy rows must stay editable).
  Future<void> upsertExpense(DangiExpenseModel e) async {
    await _assertMemberOfGroup(e.payerId, e.groupId);
    await _writeExpense(e);
  }

  /// Inserts a whole batch (e.g. a settlement) atomically and validates every
  /// payer against the group once. A partially written settlement would leave
  /// balances that do not add up.
  Future<void> insertExpenses(List<DangiExpenseModel> rows) async {
    if (rows.isEmpty) return;
    await transaction(() async {
      final groupIds = rows.map((e) => e.groupId).toSet();
      final known = <String, Set<String>>{};
      for (final gid in groupIds) {
        known[gid] = {
          for (final m in await getMembers(gid)) m.id,
        };
      }
      for (final row in rows) {
        final ids = known[row.groupId] ?? const <String>{};
        if (ids.isNotEmpty && !ids.contains(row.payerId)) {
          throw DangiStaleMemberException(row.payerId, row.groupId);
        }
      }
      for (final row in rows) {
        await _writeExpense(row);
      }
    });
  }

  /// Deletes several expenses atomically (undoing a settlement batch).
  Future<void> deleteExpenses(List<String> ids) async {
    if (ids.isEmpty) return;
    await transaction(() async {
      for (final id in ids) {
        await (db.delete(db.dangiExpenseTable)..where((t) => t.id.equals(id)))
            .go();
      }
    });
  }

  Future<void> _writeExpense(DangiExpenseModel e) async {
    await db
        .into(db.dangiExpenseTable)
        .insertOnConflictUpdate(DangiExpenseTableData(
          id: e.id,
          groupId: e.groupId,
          payerId: e.payerId,
          title: e.title,
          category: e.category,
          amount: e.amount,
          date: e.date,
          createdAt: e.createdAt,
          consumersJson: consumersToJson(e.consumers),
        ));
  }

  Future<void> _assertMemberOfGroup(String memberId, String groupId) async {
    final members = await getMembers(groupId);
    if (members.isEmpty) return;
    if (!members.any((m) => m.id == memberId)) {
      throw DangiStaleMemberException(memberId, groupId);
    }
  }

  Future<void> deleteExpense(String id) async {
    await (db.delete(db.dangiExpenseTable)..where((t) => t.id.equals(id))).go();
  }

  // ── Mapping ───────────────────────────────────────────────────────

  DangiGroupModel _toGroup(DangiGroupTableData r) => DangiGroupModel(
        id: r.id,
        name: r.name,
        colorHex: r.colorHex,
        createdAt: r.createdAt,
      );

  DangiMemberModel _toMember(DangiMemberTableData r) => DangiMemberModel(
        id: r.id,
        groupId: r.groupId,
        name: r.name,
        createdAt: r.createdAt,
      );

  DangiExpenseModel _toExpense(DangiExpenseTableData r) => DangiExpenseModel(
        id: r.id,
        groupId: r.groupId,
        payerId: r.payerId,
        title: r.title,
        category: r.category,
        amount: r.amount,
        date: r.date,
        createdAt: r.createdAt,
        consumers: consumersFromJson(r.consumersJson),
      );

  /// JSON `{memberId: amount}` → map. Invalid or empty input yields `{}`.
  static Map<String, double> consumersFromJson(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      final out = <String, double>{};
      decoded.forEach((k, v) {
        if (v is num) out[k.toString()] = v.toDouble();
      });
      return out;
    } catch (_) {
      AppLogger.warning('dangi_dao', 'operation failed');
      return const {};
    }
  }

  static String consumersToJson(Map<String, double> consumers) =>
      consumers.isEmpty ? '{}' : jsonEncode(consumers);
}
