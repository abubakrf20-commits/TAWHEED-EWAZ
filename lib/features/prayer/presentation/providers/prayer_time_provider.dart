import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'prayer_time_provider.g.dart';

@Riverpod(keepAlive: true)
PrayerTimeService prayerTimeService(Ref ref) {
  return PrayerTimeService(ref.read(prayerRepositoryProvider));
}

/// The repository's location problem ('' when there is none), for the home
/// card's warning row. A [ValueNotifier] rather than [PrayerTimes] state: two
/// refreshes can yield equal times, and Riverpod would then drop the rebuild
/// that carries a changed notice.
final prayerLocationNoticeProvider = Provider<ValueNotifier<String>>((ref) {
  final notice = ValueNotifier<String>('');
  ref.onDispose(notice.dispose);
  return notice;
});

@Riverpod(keepAlive: true)
class PrayerTimes extends _$PrayerTimes {
  /// Bumped by every rebuild and every [reload], so a slower background refresh
  /// started earlier can never publish over a newer result.
  int _generation = 0;

  @override
  Future<pi.PrayerTimes?> build() async {
    final repo = ref.watch(prayerRepositoryProvider);
    // Watch only prayer-relevant settings to avoid recalculating on unrelated
    // changes (fonts, theme, accent, etc.). The equality check on
    // PrayerSettingsKey ensures we only rebuild when a prayer-affecting field changes.
    ref.watch(prayerRelevantSettingsProvider);
    final settings = ref.read(settingsProvider).value;
    final writer = ref.read(settingsProvider.notifier);
    final generation = ++_generation;
    // A notice left over from the previous calculation must not sit over the
    // fresh one while it runs.
    ref.read(prayerLocationNoticeProvider).value = '';

    // Paint the saved/cached times right away: the location pipeline below
    // (permission dialog, GPS fix, elevation lookup) can take tens of seconds
    // and must not hold the first frame hostage.
    pi.PrayerTimes? cached;
    try {
      cached = await repo.loadCachedTimes(settings: settings);
    } catch (e) {
      AppLogger.warning('PrayerTimes', 'cached times failed: $e');
    }

    unawaited(() async {
      try {
        await repo.loadPrayerTimes(settings: settings, writer: writer);
      } catch (e) {
        // loadPrayerTimes swallows its own failures; this is belt-and-braces.
        AppLogger.warning('PrayerTimes', 'background refresh failed: $e');
        return;
      }
      _publish(repo, generation);
    }());

    return cached;
  }

  /// Force a recalculation (e.g. pull-to-refresh or after changing location/method).
  Future<void> reload({bool forceRefresh = false}) async {
    final generation = ++_generation;
    final repo = ref.read(prayerRepositoryProvider);
    final settings = ref.read(settingsProvider).value;
    final writer = ref.read(settingsProvider.notifier);
    ref.read(prayerLocationNoticeProvider).value = '';
    try {
      await repo.loadPrayerTimes(
          settings: settings, writer: writer, forceRefresh: forceRefresh);
    } catch (e) {
      AppLogger.warning('PrayerTimes', 'reload failed: $e');
      return;
    }
    _publish(repo, generation);
  }

  void _publish(PrayerRepository repo, int generation) {
    if (generation != _generation || !ref.mounted) return;
    ref.read(prayerLocationNoticeProvider).value = repo.error;
    state = AsyncValue.data(repo.cachedPrayerTimes);
  }
}
