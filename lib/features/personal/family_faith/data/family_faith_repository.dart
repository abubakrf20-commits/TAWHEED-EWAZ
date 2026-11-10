/// Storage for the stage-3 personal tools: relatives and savings goals.
///
/// Same shape as the stage-1/2 repositories: an abstract surface (so widget
/// tests run against an in-memory fake) and a raw-SQL implementation over the
/// tables in `family_faith_tables.dart`. Dates go through the shared
/// `yyyy-MM-dd` helpers, so every personal tool stores a day the same way.
library;

import 'package:drift/drift.dart' show QueryRow;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart'
    show careDateFromStore, careDateToStore;
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

// ── صله رحم ────────────────────────────────────────────────────────────────

class RelativesSnapshot {
  const RelativesSnapshot({this.relatives = const [], this.contacts = const []});

  final List<Relative> relatives;
  final List<ContactLog> contacts;

  List<ContactLog> contactsFor(String relativeId) => [
        for (final contact in contacts)
          if (contact.relativeId == relativeId) contact,
      ]..sort((a, b) => b.date.compareTo(a.date));

  List<Relative> get active => [
        for (final relative in relatives)
          if (relative.isActive) relative,
      ];
}

abstract class RelativesRepository {
  Future<RelativesSnapshot> load();
  Future<void> saveRelative(Relative relative);
  Future<void> deleteRelative(String id);
  Future<void> saveContact(ContactLog contact);
  Future<void> deleteContact(String id);
}

class DriftRelativesRepository implements RelativesRepository {
  DriftRelativesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<RelativesSnapshot> load() async {
    final relativeRows =
        await _db.customSelect('SELECT * FROM relative ORDER BY archived, name').get();
    final contactRows = await _db
        .customSelect(
            'SELECT * FROM relative_contact ORDER BY date DESC, created_at DESC')
        .get();
    return RelativesSnapshot(
      relatives: relativeRows.map(_relative).toList(),
      contacts: contactRows.map(_contact).toList(),
    );
  }

  Relative _relative(QueryRow row) => Relative(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        relation: RelationKind.fromKey(row.read<String>('relation_key')),
        relationLabel: row.read<String>('relation_label'),
        phone: row.read<String>('phone'),
        // The `birthday` column stays in the schema (additive-only migrations)
        // but is read by nobody: no birthday is stored or shown since the
        // 2026-11-07 decision, so old values are simply ignored.
        note: row.read<String>('note'),
        giftNote: row.read<String>('gift_note'),
        audience: GiftAudience.fromKey(row.read<String>('gift_audience')),
        intervalDays: row.read<int>('interval_days'),
        lastContactAt: careDateFromStore(row.readNullable<String>('last_contact_at')),
        snoozeUntil: careDateFromStore(row.readNullable<String>('snooze_until')),
        muted: row.read<bool>('muted'),
        archived: row.read<bool>('archived'),
        createdAt: careDateFromStore(row.read<String>('created_at')) ??
            DateTime.now(),
      );

  ContactLog _contact(QueryRow row) => ContactLog(
        id: row.read<String>('id'),
        relativeId: row.read<String>('relative_id'),
        date: careDateFromStore(row.read<String>('date')) ?? DateTime.now(),
        kind: ContactKind.fromKey(row.read<String>('kind')),
        note: row.read<String>('note'),
      );

  @override
  Future<void> saveRelative(Relative relative) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO relative ('
      'id, name, relation_key, relation_label, phone, birthday, note, '
      'gift_note, gift_audience, interval_days, last_contact_at, '
      'snooze_until, muted, archived, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        relative.id,
        relative.name,
        relative.relation.key,
        relative.relationLabel,
        relative.phone,
        null,
        relative.note,
        relative.giftNote,
        relative.effectiveAudience.key,
        relative.intervalDays,
        relative.lastContactAt == null
            ? null
            : careDateToStore(relative.lastContactAt!),
        relative.snoozeUntil == null
            ? null
            : careDateToStore(relative.snoozeUntil!),
        relative.muted ? 1 : 0,
        relative.archived ? 1 : 0,
        careDateToStore(relative.createdAt),
      ],
    );
  }

  @override
  Future<void> deleteRelative(String id) async {
    await _db.customStatement('DELETE FROM relative_contact WHERE relative_id = ?', [id]);
    await _db.customStatement('DELETE FROM relative WHERE id = ?', [id]);
  }

  @override
  Future<void> saveContact(ContactLog contact) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO relative_contact '
      '(id, relative_id, date, kind, note, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        contact.id,
        contact.relativeId,
        careDateToStore(contact.date),
        contact.kind.key,
        contact.note,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> deleteContact(String id) async {
    await _db.customStatement('DELETE FROM relative_contact WHERE id = ?', [id]);
  }
}

// ── قلک ────────────────────────────────────────────────────────────────────

class SavingsSnapshot {
  const SavingsSnapshot({this.goals = const [], this.deposits = const []});

  final List<SavingsGoal> goals;
  final List<Deposit> deposits;

  List<Deposit> depositsFor(String goalId) => [
        for (final deposit in deposits)
          if (deposit.goalId == goalId) deposit,
      ]..sort((a, b) => b.date.compareTo(a.date));

  List<SavingsGoal> get active => [
        for (final goal in goals)
          if (goal.isActive) goal,
      ];
}

abstract class SavingsRepository {
  Future<SavingsSnapshot> load();
  Future<void> saveGoal(SavingsGoal goal);
  Future<void> deleteGoal(String id);
  Future<void> saveDeposit(Deposit deposit);
  Future<void> deleteDeposit(String id);
}

class DriftSavingsRepository implements SavingsRepository {
  DriftSavingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<SavingsSnapshot> load() async {
    final goalRows = await _db
        .customSelect('SELECT * FROM savings_goal ORDER BY archived, created_at')
        .get();
    final depositRows = await _db
        .customSelect(
            'SELECT * FROM savings_deposit ORDER BY date DESC, created_at DESC')
        .get();
    return SavingsSnapshot(
      goals: goalRows.map(_goal).toList(),
      deposits: depositRows.map(_deposit).toList(),
    );
  }

  SavingsGoal _goal(QueryRow row) => SavingsGoal(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        targetAmount: row.read<double>('target_amount'),
        targetDate: careDateFromStore(row.readNullable<String>('target_date')),
        iconKey: row.read<String>('icon_key'),
        accentKey: row.read<String>('accent_key'),
        note: row.read<String>('note'),
        remindWeekly: row.read<bool>('remind_weekly'),
        archived: row.read<bool>('archived'),
        createdAt: careDateFromStore(row.read<String>('created_at')) ??
            DateTime.now(),
      );

  Deposit _deposit(QueryRow row) => Deposit(
        id: row.read<String>('id'),
        goalId: row.read<String>('goal_id'),
        date: careDateFromStore(row.read<String>('date')) ?? DateTime.now(),
        amount: row.read<double>('amount'),
        note: row.read<String>('note'),
      );

  @override
  Future<void> saveGoal(SavingsGoal goal) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO savings_goal ('
      'id, title, target_amount, target_date, icon_key, accent_key, note, '
      'remind_weekly, archived, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        goal.id,
        goal.title,
        goal.targetAmount,
        goal.targetDate == null ? null : careDateToStore(goal.targetDate!),
        goal.iconKey,
        goal.accentKey,
        goal.note,
        goal.remindWeekly ? 1 : 0,
        goal.archived ? 1 : 0,
        careDateToStore(goal.createdAt),
      ],
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _db.customStatement('DELETE FROM savings_deposit WHERE goal_id = ?', [id]);
    await _db.customStatement('DELETE FROM savings_goal WHERE id = ?', [id]);
  }

  @override
  Future<void> saveDeposit(Deposit deposit) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO savings_deposit '
      '(id, goal_id, date, amount, note, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        deposit.id,
        deposit.goalId,
        careDateToStore(deposit.date),
        deposit.amount,
        deposit.note,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> deleteDeposit(String id) async {
    await _db.customStatement('DELETE FROM savings_deposit WHERE id = ?', [id]);
  }
}
