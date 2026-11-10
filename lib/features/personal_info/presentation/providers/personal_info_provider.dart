import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/services/expiry_reminder_scheduler.dart';

/// Aggregates the read side of «اطلاعات من». Providers here expose the raw
/// rows; screens handle encryption/decryption through [SecretVault] helpers.
final personalProfilesProvider =
    FutureProvider<List<PersonalProfileTableData>>((ref) async {
  return ref.read(personalInfoRepositoryProvider).getAllProfiles();
});

final expiringItemsProvider =
    FutureProvider<List<ExpiryItemTableData>>((ref) async {
  return ref.read(personalInfoRepositoryProvider).getExpiryItems();
});

final activeRemindersProvider =
    FutureProvider<List<ExpiryItemTableData>>((ref) async {
  final items =
      await ref.read(personalInfoRepositoryProvider).getActiveRemindableItems();
  // Boot-time re-sync: OS notifications do not survive app restarts/reboots
  // on all platforms, so re-book every still-pending reminder once the rows are
  // loaded. Failures are swallowed inside the scheduler, so a missing
  // permission never breaks the screen.
  unawaited(ExpiryReminderScheduler.syncAll(items));
  return items;
});

/// Aggregated counts shown on the vault dashboard's stats strip. Refreshed
/// with [refetchPersonalInfo] or by invalidating it after returning from a
/// sub-section.
typedef PersonalInfoStats = ({
  int profiles,
  int credentials,
  int assets,
  int insurances,
  int emergencyContacts,
  int expiring,
});

final personalInfoStatsProvider =
    FutureProvider<PersonalInfoStats>((ref) async {
  final repo = ref.read(personalInfoRepositoryProvider);
  final profiles = await repo.getAllProfiles();
  final credentials = await repo.getCredentials();
  final assets = await repo.getAssets();
  final insurances = await repo.getInsurances();
  final emergency = await repo.getEmergencyContacts();
  final expiring = await repo.getExpiryItems();
  return (
    profiles: profiles.length,
    credentials: credentials.length,
    assets: assets.length,
    insurances: insurances.length,
    emergencyContacts: emergency.length,
    expiring: expiring.where((e) => !e.isArchived).length,
  );
});

/// Invalidates all read providers after any write (edit/delete).
void refetchPersonalInfo(Ref ref) {
  ref.invalidate(personalProfilesProvider);
  ref.invalidate(expiringItemsProvider);
  ref.invalidate(activeRemindersProvider);
}
