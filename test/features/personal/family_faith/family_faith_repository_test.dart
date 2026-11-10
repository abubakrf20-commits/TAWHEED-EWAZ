import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

void main() {
  late AppDatabase db;
  late DriftRelativesRepository relatives;
  late DriftSavingsRepository savings;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    relatives = DriftRelativesRepository(db);
    savings = DriftSavingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('relatives', () {
    Relative sample({String id = 'r1'}) => Relative(
          id: id,
          name: 'عمه زهرا',
          relation: RelationKind.paternalAunt,
          relationLabel: '',
          phone: '09120000000',
          note: 'هفته‌ای یک بار',
          giftNote: 'گلاب',
          audience: GiftAudience.elder,
          intervalDays: 21,
          lastContactAt: DateTime(2026, 9, 1),
          snoozeUntil: DateTime(2026, 9, 20),
          muted: true,
          archived: false,
          createdAt: DateTime(2026, 1, 2),
        );

    test('round-trips every column', () async {
      await relatives.saveRelative(sample());
      final row = (await relatives.load()).relatives.single;
      expect(row.name, 'عمه زهرا');
      expect(row.relation, RelationKind.paternalAunt);
      expect(row.phone, '09120000000');
      expect(row.giftNote, 'گلاب');
      expect(row.effectiveAudience, GiftAudience.elder);
      expect(row.intervalDays, 21);
      expect(row.lastContactAt, DateTime(2026, 9, 1));
      expect(row.snoozeUntil, DateTime(2026, 9, 20));
      expect(row.muted, isTrue);
      expect(row.archived, isFalse);
      expect(row.createdAt, DateTime(2026, 1, 2));
    });

    test('an edit replaces rather than duplicates', () async {
      await relatives.saveRelative(sample());
      await relatives.saveRelative(sample().copyWith(phone: '09121111111'));
      final snapshot = await relatives.load();
      expect(snapshot.relatives, hasLength(1));
      expect(snapshot.relatives.single.phone, '09121111111');
    });

    test('contacts come back newest first for their relative', () async {
      await relatives.saveRelative(sample());
      await relatives.saveContact(ContactLog(
        id: 'c1',
        relativeId: 'r1',
        date: DateTime(2026, 8, 1),
        kind: ContactKind.call,
      ));
      await relatives.saveContact(ContactLog(
        id: 'c2',
        relativeId: 'r1',
        date: DateTime(2026, 9, 1),
        kind: ContactKind.visit,
      ));
      await relatives.saveContact(ContactLog(
        id: 'c3',
        relativeId: 'other',
        date: DateTime(2026, 9, 2),
        kind: ContactKind.message,
      ));
      final contacts = (await relatives.load()).contactsFor('r1');
      expect(contacts.map((c) => c.id), ['c2', 'c1']);
    });

    test('deleting a relative removes its contacts too', () async {
      await relatives.saveRelative(sample());
      await relatives.saveContact(ContactLog(
        id: 'c1',
        relativeId: 'r1',
        date: DateTime(2026, 8, 1),
        kind: ContactKind.call,
      ));
      await relatives.deleteRelative('r1');
      final snapshot = await relatives.load();
      expect(snapshot.relatives, isEmpty);
      expect(snapshot.contacts, isEmpty);
    });

    test('active excludes archived rows', () async {
      await relatives.saveRelative(sample(id: 'a'));
      await relatives.saveRelative(sample(id: 'b').copyWith(archived: true));
      expect((await relatives.load()).active.map((r) => r.id), ['a']);
    });
  });

  group('savings', () {
    SavingsGoal goal() => SavingsGoal(
          id: 'g1',
          title: 'سفر شمال',
          targetAmount: 8000000,
          targetDate: DateTime(2027, 3, 1),
          iconKey: 'travel',
          note: 'تابستان',
          remindWeekly: true,
          createdAt: DateTime(2026, 9, 1),
        );

    test('round-trips a goal and its deposits', () async {
      await savings.saveGoal(goal());
      await savings.saveDeposit(Deposit(
        id: 'd1',
        goalId: 'g1',
        date: DateTime(2026, 9, 2),
        amount: 1000000,
      ));
      await savings.saveDeposit(Deposit(
        id: 'd2',
        goalId: 'g1',
        date: DateTime(2026, 9, 3),
        amount: -200000,
        note: 'برداشت',
      ));
      final snapshot = await savings.load();
      final loaded = snapshot.goals.single;
      expect(loaded.title, 'سفر شمال');
      expect(loaded.targetDate, DateTime(2027, 3, 1));
      expect(loaded.iconKey, 'travel');
      expect(loaded.remindWeekly, isTrue);
      expect(snapshot.depositsFor('g1').map((d) => d.amount), [-200000, 1000000]);
    });

    test('a negative deposit is a withdrawal, not a separate row type', () async {
      await savings.saveGoal(goal());
      await savings.saveDeposit(Deposit(
        id: 'd1',
        goalId: 'g1',
        date: DateTime(2026, 9, 2),
        amount: -500,
      ));
      expect((await savings.load()).deposits.single.isWithdrawal, isTrue);
    });

    test('deleting a goal deletes its deposits', () async {
      await savings.saveGoal(goal());
      await savings.saveDeposit(Deposit(
        id: 'd1',
        goalId: 'g1',
        date: DateTime(2026, 9, 2),
        amount: 1000,
      ));
      await savings.deleteGoal('g1');
      final snapshot = await savings.load();
      expect(snapshot.goals, isEmpty);
      expect(snapshot.deposits, isEmpty);
    });
  });
}
