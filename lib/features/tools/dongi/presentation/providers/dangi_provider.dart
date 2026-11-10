import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

/// SharedPreferences key used by app versions before schema v33, when
/// per-expense consumer amounts lived in a JSON side-store. Migrated into the
/// expense rows once on first load, then the key is deleted.
const String _legacyConsumersKey = 'dangi_consumers_v1';

const Object _unset = Object();

/// Immutable state of the dangi feature.
class DangiState {
  final List<DangiGroupModel> groups;
  final Map<String, List<DangiMemberModel>> membersByGroup;
  final Map<String, List<DangiExpenseModel>> expensesByGroup;
  final bool loaded;

  /// The failure of the last load, so the screens can offer a retry instead
  /// of spinning forever; cleared when a retry starts or a load succeeds.
  final Object? loadError;

  const DangiState({
    this.groups = const [],
    this.membersByGroup = const {},
    this.expensesByGroup = const {},
    this.loaded = false,
    this.loadError,
  });

  DangiState copyWith({
    List<DangiGroupModel>? groups,
    Map<String, List<DangiMemberModel>>? membersByGroup,
    Map<String, List<DangiExpenseModel>>? expensesByGroup,
    bool? loaded,
    Object? loadError = _unset,
  }) {
    return DangiState(
      groups: groups ?? this.groups,
      membersByGroup: membersByGroup ?? this.membersByGroup,
      expensesByGroup: expensesByGroup ?? this.expensesByGroup,
      loaded: loaded ?? this.loaded,
      loadError: identical(loadError, _unset)
          ? this.loadError
          : loadError,
    );
  }

  List<DangiMemberModel> membersOf(String groupId) =>
      membersByGroup[groupId] ?? const [];

  List<DangiExpenseModel> expensesOf(String groupId) =>
      expensesByGroup[groupId] ?? const [];

  /// Real spendings of the group — settlement rows are transfers, not
  /// spendings, so totals and the report use this list.
  List<DangiExpenseModel> spendingsOf(String groupId) =>
      expensesOf(groupId).where((e) => !isDangiSettlement(e)).toList();

  /// Recorded settlements (transfers) of the group, newest first.
  List<DangiExpenseModel> settlementsOf(String groupId) =>
      expensesOf(groupId).where(isDangiSettlement).toList();

  /// Per-member consumer amounts for the current expense list, keyed by
  /// expense id (memberId → consumed amount). Empty lists mean equal split.
  Map<String, Map<String, double>> get consumersByExpense {
    final out = <String, Map<String, double>>{};
    expensesByGroup.forEach((groupId, list) {
      for (final e in list) {
        if (e.consumers.isNotEmpty) out[e.id] = e.consumers;
      }
    });
    return out;
  }

  double totalOf(String groupId) {
    var t = 0.0;
    for (final e in spendingsOf(groupId)) {
      t += e.amount;
    }
    return t;
  }
}

final dangiProvider =
    NotifierProvider<DangiNotifier, DangiState>(DangiNotifier.new);

class DangiNotifier extends Notifier<DangiState> {
  DangiDao get _dao => ref.read(dangiDaoProvider);
  bool _loaded = false;

  /// Serializes loads: every new load waits for the previous one, so a
  /// reload triggered right after the provider was first built never gets
  /// overwritten by a stale snapshot (which could make the UI show deleted
  /// members/expenses or miss just-created ones).
  Future<void> _queue = Future.value();

  @override
  DangiState build() {
    _load();
    return const DangiState();
  }

  Future<void> _load() async {
    final next = _queue.then((_) => _loadNow());
    _queue = next.catchError((_) {});
    await next;
  }

  Future<void> _loadNow() async {
    if (_loaded) return;
    if (state.loadError != null) state = state.copyWith(loadError: null);
    try {
      final groups = await _dao.getAllGroups();
      final members = <String, List<DangiMemberModel>>{};
      final expenses = <String, List<DangiExpenseModel>>{};
      for (final g in groups) {
        members[g.id] = await _dao.getMembers(g.id);
        expenses[g.id] = await _dao.getExpenses(g.id);
      }
      await _migrateLegacyConsumers(groups, members, expenses);
      _loaded = true;
      state = DangiState(
        groups: groups,
        membersByGroup: members,
        expensesByGroup: expenses,
        loaded: true,
      );
    } catch (e, st) {
      AppLogger.error('dangi: load failed', e, st);
      state = state.copyWith(loadError: e);
    }
  }

  /// One-time migration for pre-v33 data: consumer amounts used to live in
  /// SharedPreferences (`dangi_consumers_v1`) instead of the expense rows.
  /// Move everything we still recognise into the database — only entries
  /// whose member still belongs to the expense's group are kept — then clear
  /// the key. Never throws (missing plugin / bad JSON are simply skipped).
  Future<void> _migrateLegacyConsumers(
    List<DangiGroupModel> groups,
    Map<String, List<DangiMemberModel>> members,
    Map<String, List<DangiExpenseModel>> expenses,
  ) async {
    final pending = <DangiExpenseModel>[
      for (final g in groups)
        for (final e in expenses[g.id] ?? const <DangiExpenseModel>[])
          if (e.consumers.isEmpty) e,
    ];
    if (pending.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyConsumersKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final allowedIds = <String, Set<String>>{
        for (final g in groups)
          g.id: {
            for (final m in members[g.id] ?? const <DangiMemberModel>[]) m.id,
          },
      };
      for (final e in pending) {
        final rawEntry = decoded[e.id];
        if (rawEntry is! Map) continue;
        final consumers = <String, double>{};
        rawEntry.forEach((k, v) {
          final amt = v is num ? v.toDouble() : null;
          // A legacy share survives only when it is positive and fits inside
          // the expense — negative/zero or over-sized values would corrupt
          // balances, so they are dropped like unknown members.
          if (amt == null || amt <= 0 || amt > e.amount) return;
          if (allowedIds[e.groupId]?.contains(k.toString()) ?? false) {
            consumers[k.toString()] = amt;
          }
        });
        if (consumers.isEmpty) continue;
        await _dao.upsertExpense(e.copyWith(consumers: consumers));
        final list = expenses[e.groupId];
        if (list != null) {
          final i = list.indexWhere((x) => x.id == e.id);
          if (i >= 0) list[i] = e.copyWith(consumers: consumers);
        }
      }
      // The database is now the source of truth: once the map has been read
      // and walked, every entry in it is stale — even when nothing matched,
      // so the key always goes and the migration never runs twice.
      await prefs.remove(_legacyConsumersKey);
    } catch (_) {
      // Missing plugin (e.g. tests) or malformed JSON — nothing to migrate.
    }
  }

  Future<void> reload() async {
    _loaded = false;
    await _load();
  }

  Future<void> addGroup({
    required String name,
    required String colorHex,
    required List<String> memberNames,
  }) async {
    final group = DangiGroupModel(
      id: _id(),
      name: name,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
    await _dao.upsertGroup(group);
    for (final n in memberNames) {
      await _dao.upsertMember(DangiMemberModel(
        id: _id(),
        groupId: group.id,
        name: n,
        createdAt: DateTime.now(),
      ));
    }
    await reload();
  }

  /// Updates the group. Members are matched by **id**, so renaming a
  /// member keeps their id (and therefore their expenses). Only members
  /// whose id is absent from [members] are removed; new members (id ==
  /// null) are created.
  Future<void> updateGroup(
      DangiGroupModel group, List<({String? id, String name})> members) async {
    await _dao.upsertGroup(group);
    final existing = await _dao.getMembers(group.id);
    final keptIds = members.map((m) => m.id).whereType<String>().toSet();
    // اعضایی که دیگر در لیست نیستند حذف می‌شوند.
    for (final m in existing) {
      if (!keptIds.contains(m.id)) {
        await _dao.deleteMember(m.id, group.id);
      }
    }
    // به‌روزرسانی نام اعضای موجود و ساخت اعضای جدید.
    for (final m in members) {
      if (m.id != null) {
        final current = existing.where((e) => e.id == m.id).firstOrNull;
        if (current != null && current.name != m.name) {
          await _dao.upsertMember(DangiMemberModel(
            id: current.id,
            groupId: current.groupId,
            name: m.name,
            createdAt: current.createdAt,
          ));
        }
      } else {
        await _dao.upsertMember(DangiMemberModel(
          id: _id(),
          groupId: group.id,
          name: m.name,
          createdAt: DateTime.now(),
        ));
      }
    }
    await reload();
  }

  /// Deletes [id] and returns a snapshot of everything removed, so the caller
  /// can offer undo. Returns `null` when the group is already gone.
  Future<DangiGroupSnapshot?> deleteGroup(String id) async {
    final group = state.groups.where((g) => g.id == id).firstOrNull;
    if (group == null) return null;
    final members = List<DangiMemberModel>.from(state.membersOf(id));
    final expenses = List<DangiExpenseModel>.from(state.expensesOf(id));
    await _dao.deleteGroup(id);
    await reload();
    return DangiGroupSnapshot(
        group: group, members: members, expenses: expenses);
  }

  /// Re-inserts a group deleted by [deleteGroup] (the snackbar «بازگردانی»).
  Future<void> restoreGroup(DangiGroupSnapshot snapshot) async {
    await _dao.restoreGroup(snapshot);
    await reload();
  }

  /// Removes a single member (and the expenses they paid) plus their share
  /// from any other expense's per-member consumer list. Returns a snapshot of
  /// everything removed or mutated so the caller can offer undo, or `null`
  /// when the member is already gone.
  Future<DangiMemberSnapshot?> deleteMember(
      String memberId, String groupId) async {
    final member =
        state.membersOf(groupId).where((m) => m.id == memberId).firstOrNull;
    if (member == null) return null;
    final groupExpenses = state.expensesOf(groupId);
    final ownExpenses = [
      for (final e in groupExpenses)
        if (e.payerId == memberId) e,
    ];
    final strippedExpenses = [
      for (final e in groupExpenses)
        if (e.consumers.containsKey(memberId)) e,
    ];
    if (strippedExpenses.isNotEmpty) {
      await _dao.removeConsumerFromExpenses(
          [for (final e in strippedExpenses) e.id], memberId);
    }
    await _dao.deleteMember(memberId, groupId);
    await reload();
    return DangiMemberSnapshot(
      member: member,
      ownExpenses: ownExpenses,
      strippedExpenses: strippedExpenses,
    );
  }

  /// Re-inserts a member deleted by [deleteMember] (the snackbar «بازگردانی»).
  Future<void> restoreMember(DangiMemberSnapshot snapshot) async {
    await _dao.restoreMember(snapshot);
    await reload();
  }

  /// Renames a single member, keeping their id so their expenses survive.
  Future<void> renameMember(
      String memberId, String groupId, String name) async {
    final existing = await _dao.getMembers(groupId);
    final m = existing.where((e) => e.id == memberId).firstOrNull;
    if (m == null || m.name == name) return;
    await _dao.upsertMember(DangiMemberModel(
      id: m.id,
      groupId: m.groupId,
      name: name,
      createdAt: m.createdAt,
    ));
    await reload();
  }

  Future<void> addExpense({
    required String groupId,
    required String payerId,
    required String title,
    required String category,
    required double amount,
    Map<String, double>? consumers,
    DateTime? date,
  }) async {
    await _dao.upsertExpense(DangiExpenseModel(
      id: _id(),
      groupId: groupId,
      payerId: payerId,
      title: title,
      category: category,
      amount: amount,
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
      consumers: consumers ?? const {},
    ));
    await reload();
  }

  Future<void> updateExpense(DangiExpenseModel expense) async {
    await _dao.upsertExpense(expense);
    await reload();
  }

  Future<void> deleteExpense(String id) async {
    await _dao.deleteExpense(id);
    await reload();
  }

  /// Records every open transfer of [groupId] as a settlement row, so all
  /// balances become zero («حساب بسته شد»). Returns the inserted row ids so
  /// the snackbar can undo the whole batch.
  Future<List<String>> settleGroup(String groupId) async {
    final members = state.membersOf(groupId);
    final expenses = state.expensesOf(groupId);
    final transfers = DangiSettlement.settle(
      memberIds: [for (final m in members) m.id],
      expenses: [
        for (final e in expenses) (payerId: e.payerId, amount: e.amount)
      ],
      consumerSharesByIndex: {
        for (var i = 0; i < expenses.length; i++)
          if (expenses[i].consumers.isNotEmpty) i: expenses[i].consumers,
      },
    );
    if (transfers.isEmpty) return const [];
    final now = DateTime.now();
    final rows = [
      for (final t in transfers)
        DangiExpenseModel(
          id: _id(),
          groupId: groupId,
          // The debtor pays …
          payerId: t.fromId,
          title: 'تسویه: ${_memberName(members, t.fromId)} → '
              '${_memberName(members, t.toId)}',
          category: dangiSettlementCategory,
          amount: t.amount,
          date: now,
          createdAt: now,
          // … and the creditor is the only consumer of that payment.
          consumers: {t.toId: t.amount},
        ),
    ];
    // One atomic batch: a row-by-row loop left the group half-settled when a
    // later insert threw (member deleted mid-way, DB busy) — balances that
    // do not add up and no undo list to clean them with.
    await _dao.insertExpenses(rows);
    await reload();
    return [for (final r in rows) r.id];
  }

  /// Undoes a recorded settlement batch — the «لغو» snackbar action.
  Future<void> undoSettlement(List<String> ids) async {
    await _dao.deleteExpenses(ids);
    await reload();
  }

  String _memberName(List<DangiMemberModel> members, String id) =>
      members.where((m) => m.id == id).firstOrNull?.name ?? id;

  String _id() => newEntityId();
}
