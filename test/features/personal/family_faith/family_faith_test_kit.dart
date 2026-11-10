import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_schedulers.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_settings.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/relatives/relative_reminder_planner.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

/// In-memory repositories. They behave like the real ones for the calls the
/// screens make, so a tap that writes is visible after the store reloads —
/// the point of a widget test is the round trip, not the SQL.
class FakeRelativesRepository implements RelativesRepository {
  FakeRelativesRepository([this.snapshot = const RelativesSnapshot()]);

  RelativesSnapshot snapshot;

  @override
  Future<RelativesSnapshot> load() async => snapshot;

  @override
  Future<void> saveRelative(Relative relative) async {
    final rows = [...snapshot.relatives];
    final index = rows.indexWhere((r) => r.id == relative.id);
    if (index >= 0) {
      rows[index] = relative;
    } else {
      rows.add(relative);
    }
    snapshot = RelativesSnapshot(relatives: rows, contacts: snapshot.contacts);
  }

  @override
  Future<void> deleteRelative(String id) async {
    snapshot = RelativesSnapshot(
      relatives: [
        for (final row in snapshot.relatives)
          if (row.id != id) row,
      ],
      contacts: [
        for (final contact in snapshot.contacts)
          if (contact.relativeId != id) contact,
      ],
    );
  }

  @override
  Future<void> saveContact(ContactLog contact) async {
    snapshot = RelativesSnapshot(
      relatives: snapshot.relatives,
      contacts: [
        for (final row in snapshot.contacts)
          if (row.id != contact.id) row,
        contact,
      ],
    );
  }

  @override
  Future<void> deleteContact(String id) async {
    snapshot = RelativesSnapshot(
      relatives: snapshot.relatives,
      contacts: [
        for (final row in snapshot.contacts)
          if (row.id != id) row,
      ],
    );
  }
}

class FakeSavingsRepository implements SavingsRepository {
  FakeSavingsRepository([this.snapshot = const SavingsSnapshot()]);

  SavingsSnapshot snapshot;

  @override
  Future<SavingsSnapshot> load() async => snapshot;

  @override
  Future<void> saveGoal(SavingsGoal goal) async {
    final rows = [...snapshot.goals];
    final index = rows.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      rows[index] = goal;
    } else {
      rows.add(goal);
    }
    snapshot = SavingsSnapshot(goals: rows, deposits: snapshot.deposits);
  }

  @override
  Future<void> deleteGoal(String id) async {
    snapshot = SavingsSnapshot(
      goals: [
        for (final row in snapshot.goals)
          if (row.id != id) row,
      ],
      deposits: [
        for (final row in snapshot.deposits)
          if (row.goalId != id) row,
      ],
    );
  }

  @override
  Future<void> saveDeposit(Deposit deposit) async {
    snapshot = SavingsSnapshot(
      goals: snapshot.goals,
      deposits: [
        for (final row in snapshot.deposits)
          if (row.id != deposit.id) row,
        deposit,
      ],
    );
  }

  @override
  Future<void> deleteDeposit(String id) async {
    snapshot = SavingsSnapshot(
      goals: snapshot.goals,
      deposits: [
        for (final row in snapshot.deposits)
          if (row.id != id) row,
      ],
    );
  }
}

class NoopFamilyReminders implements FamilyReminders {
  @override
  Future<void> sync(RelativesSnapshot snapshot,
      {FamilyReminderSettings? settings}) async {}
}

class NoopSavingsReminders implements SavingsReminders {
  @override
  Future<void> sync(SavingsSnapshot snapshot) async {}
}

/// A launcher that records the URI instead of opening a dialer.
class RecordingLauncher {
  final List<Uri> uris = [];

  Future<bool> call(Uri uri) async {
    uris.add(uri);
    return true;
  }
}

/// Wraps [child] in the app's day theme at [size], RTL, with optional text
/// scale. Mirrors the finance golden harness so the two sets behave alike.
Widget familyTestApp({
  required Widget child,
  required List<Override> overrides,
  Size size = const Size(360, 1400),
  double scale = 1,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Applies the day theme the screens expect (the app calls this at boot).
void applyDayTheme() {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
}
