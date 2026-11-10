/// Riverpod wiring for the stage-3 tools.
///
/// One store per tool, all following the stage-1/2 contract: **persist first,
/// republish second**, then sync reminders through an injectable scheduler so
/// widget tests never touch the notification plugin.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_custom_gifts.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_schedulers.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_settings.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_gift_ideas.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/relatives/relative_reminder_planner.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final Random _rng = Random();

String _id(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(99999)}';

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

// ── صله رحم ────────────────────────────────────────────────────────────────

final relativesRepositoryProvider = Provider<RelativesRepository>(
  (ref) => DriftRelativesRepository(ref.watch(appDatabaseProvider)),
);

final familyRemindersProvider =
    Provider<FamilyReminders>((ref) => const FamilyReminderScheduler());

final familySettingsProvider =
    FutureProvider<FamilyReminderSettings>((ref) => FamilySettingsStore.load());

final giftIdeasProvider = FutureProvider<List<GiftIdea>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/gift_ideas.json');
    return parseGiftIdeas(raw);
  } catch (e) {
    AppLogger.warning('GiftIdeas', 'bundle read failed: $e');
    return const [];
  }
});

/// Opens a `tel:` / `sms:` URI. A provider so widget tests can assert the URI
/// without a real dialer (and so no screen ever needs a `BuildContext` for it).
typedef FamilyUriLauncher = Future<bool> Function(Uri uri);

final familyUriLauncherProvider = Provider<FamilyUriLauncher>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class RelativesStore extends AsyncNotifier<RelativesSnapshot> {
  RelativesRepository get _repo => ref.read(relativesRepositoryProvider);

  @override
  Future<RelativesSnapshot> build() => _repo.load();

  Future<RelativesSnapshot> _reload() async {
    final snapshot = await _repo.load();
    state = AsyncData(snapshot);
    _syncReminders();
    return snapshot;
  }

  void _syncReminders() {
    unawaited(
      ref
          .read(familyRemindersProvider)
          .sync(state.requireValue, settings: ref.read(familySettingsProvider).value)
          .catchError((Object e) {
        AppLogger.warning('RelativesStore', 'reminder sync failed: $e');
      }),
    );
  }

  Future<Relative> addRelative({
    required String name,
    required RelationKind relation,
    String relationLabel = '',
    String phone = '',
    String note = '',
    int? intervalDays,
    GiftAudience? audience,
  }) async {
    final relative = Relative(
      id: _id('rel'),
      name: name.trim(),
      relation: relation,
      relationLabel: relationLabel.trim(),
      phone: phone.trim(),
      note: note.trim(),
      audience: audience,
      intervalDays: (intervalDays ?? relation.defaultIntervalDays).clamp(1, 3650),
      createdAt: _day(DateTime.now()),
    );
    await _repo.saveRelative(relative);
    await _reload();
    return relative;
  }

  Future<void> updateRelative(Relative relative) async {
    await _repo.saveRelative(relative);
    await _reload();
  }

  Future<void> deleteRelative(String id) async {
    await _repo.deleteRelative(id);
    await _reload();
  }

  /// Logs a contact and moves the relative's last-contact day.
  ///
  /// Returns the row so the caller can offer «بازگردانی»; [previousLastContact]
  /// is what the undo restores.
  Future<ContactLog?> logContact({
    required Relative relative,
    required ContactKind kind,
    DateTime? date,
    String note = '',
  }) async {
    final when = _day(date ?? DateTime.now());
    final contact = ContactLog(
      id: _id('contact'),
      relativeId: relative.id,
      date: when,
      kind: kind,
      note: note.trim(),
    );
    // Write against the CURRENT row, not the object the screen has in hand:
    // a sheet can save a gift note and log the gift in the same turn, and the
    // stale copy would write that note back to ''. The same staleness used to
    // make a visit look like it did nothing when the card's copy was a build
    // old.
    final latest = state.value?.relatives.firstWhere(
          (row) => row.id == relative.id,
          orElse: () => relative,
        ) ??
        relative;
    await _repo.saveContact(contact);
    await _repo.saveRelative(latest.copyWith(
      lastContactAt: when,
      snoozeUntil: null,
    ));
    await _reload();
    return contact;
  }

  Future<void> undoContact({
    required Relative relative,
    required ContactLog contact,
    DateTime? previousLastContact,
  }) async {
    await _repo.deleteContact(contact.id);
    await _repo.saveRelative(relative.copyWith(lastContactAt: previousLastContact));
    await _reload();
  }

  /// Removes one row from the history sheet and repairs `lastContactAt` to the
  /// newest row that is left — deleting the latest visit must not leave the
  /// card claiming a contact that no longer exists.
  Future<void> removeContact({
    required Relative relative,
    required ContactLog contact,
  }) async {
    await _repo.deleteContact(contact.id);
    final remaining = [
      for (final row in state.requireValue.contactsFor(relative.id))
        if (row.id != contact.id) row,
    ]..sort((a, b) => b.date.compareTo(a.date));
    await _repo.saveRelative(relative.copyWith(
      lastContactAt: remaining.isEmpty ? null : remaining.first.date,
    ));
    await _reload();
  }

  Future<void> snooze(Relative relative, Duration duration) async {
    final until = _day(DateTime.now().add(duration));
    await _repo.saveRelative(relative.copyWith(snoozeUntil: until));
    await _reload();
  }

  Future<void> setMuted(Relative relative, bool muted) async {
    await _repo.saveRelative(relative.copyWith(muted: muted));
    await _reload();
  }

  Future<void> setArchived(Relative relative, bool archived) async {
    await _repo.saveRelative(relative.copyWith(archived: archived));
    await _reload();
  }

  Future<void> saveGiftNote(Relative relative, String note) async {
    await _repo.saveRelative(relative.copyWith(giftNote: note.trim()));
    await _reload();
  }

  Future<void> saveSettings(FamilyReminderSettings settings) async {
    await FamilySettingsStore.save(settings);
    ref.invalidate(familySettingsProvider);
    _syncReminders();
  }
}

final relativesStoreProvider =
    AsyncNotifierProvider<RelativesStore, RelativesSnapshot>(RelativesStore.new);

/// «هدایای دلخواه من» — the user's own list, beside the bundled catalogue.
class CustomGiftsNotifier extends AsyncNotifier<List<CustomGift>> {
  @override
  Future<List<CustomGift>> build() => CustomGiftsStorage.load();

  Future<void> add(String title, {String note = ''}) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final current = state.value ?? const <CustomGift>[];
    // Same title twice is not two ideas; keep the first, update its note.
    final existing = current.indexWhere((gift) => gift.title == clean);
    final next = [...current];
    if (existing >= 0) {
      next[existing] = next[existing].copyWith(note: note.trim());
    } else {
      next.insert(
        0,
        CustomGift(id: _id('gift'), title: clean, note: note.trim()),
      );
    }
    await CustomGiftsStorage.save(next);
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final current = state.value ?? const <CustomGift>[];
    final next = [for (final gift in current) if (gift.id != id) gift];
    await CustomGiftsStorage.save(next);
    state = AsyncData(next);
  }
}

final customGiftsProvider =
    AsyncNotifierProvider<CustomGiftsNotifier, List<CustomGift>>(
        CustomGiftsNotifier.new);

// ── قلک ────────────────────────────────────────────────────────────────────

final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => DriftSavingsRepository(ref.watch(appDatabaseProvider)),
);

final savingsRemindersProvider =
    Provider<SavingsReminders>((ref) => const SavingsReminderScheduler());

class SavingsStore extends AsyncNotifier<SavingsSnapshot> {
  SavingsRepository get _repo => ref.read(savingsRepositoryProvider);

  @override
  Future<SavingsSnapshot> build() => _repo.load();

  Future<SavingsSnapshot> _reload() async {
    final snapshot = await _repo.load();
    state = AsyncData(snapshot);
    unawaited(
      ref
          .read(savingsRemindersProvider)
          .sync(snapshot)
          .catchError((Object e) {
        AppLogger.warning('SavingsStore', 'reminder sync failed: $e');
      }),
    );
    return snapshot;
  }

  Future<SavingsGoal> addGoal({
    required String title,
    required double targetAmount,
    DateTime? targetDate,
    String iconKey = 'savings',
    String accentKey = 'gold',
    String note = '',
    bool remindWeekly = false,
  }) async {
    final goal = SavingsGoal(
      id: _id('goal'),
      title: title.trim(),
      targetAmount: targetAmount <= 0 ? 0 : targetAmount,
      targetDate: targetDate == null ? null : _day(targetDate),
      iconKey: iconKey,
      accentKey: accentKey,
      note: note.trim(),
      remindWeekly: remindWeekly,
      createdAt: _day(DateTime.now()),
    );
    await _repo.saveGoal(goal);
    await _reload();
    return goal;
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await _repo.saveGoal(goal);
    await _reload();
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    await _reload();
  }

  Future<Deposit> addDeposit({
    required SavingsGoal goal,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    final deposit = Deposit(
      id: _id('dep'),
      goalId: goal.id,
      date: _day(date ?? DateTime.now()),
      amount: amount.abs(),
      note: note.trim(),
    );
    await _repo.saveDeposit(deposit);
    await _reload();
    return deposit;
  }

  /// Withdraws [amount]. Returns false (and writes nothing) when the goal does
  /// not hold that much — the balance can never go negative.
  Future<bool> withdraw({
    required SavingsGoal goal,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    final deposits = state.requireValue.depositsFor(goal.id);
    if (amount <= 0 || amount > maxWithdrawable(deposits)) return false;
    final deposit = Deposit(
      id: _id('dep'),
      goalId: goal.id,
      date: _day(date ?? DateTime.now()),
      amount: -amount,
      note: note.trim(),
    );
    await _repo.saveDeposit(deposit);
    await _reload();
    return true;
  }

  Future<void> deleteDeposit(String id) async {
    await _repo.deleteDeposit(id);
    await _reload();
  }
}

final savingsStoreProvider =
    AsyncNotifierProvider<SavingsStore, SavingsSnapshot>(SavingsStore.new);

