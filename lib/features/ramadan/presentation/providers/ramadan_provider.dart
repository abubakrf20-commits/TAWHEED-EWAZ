import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/ramadan/data/ramadan_service.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/settings.dart';

part 'ramadan_provider.g.dart';

class RamadanState {
  final bool isRamadan;
  final int currentDay;
  final int daysRemaining;
  final int daysUntilRamadan;
  final ({String label, Duration remaining, bool isSuhoor})? nextMeal;
  final int hijriOffset;

  const RamadanState({
    this.isRamadan = false,
    this.currentDay = 0,
    this.daysRemaining = 0,
    this.daysUntilRamadan = 0,
    this.nextMeal,
    this.hijriOffset = 0,
  });

  RamadanState copyWith({
    bool? isRamadan,
    int? currentDay,
    int? daysRemaining,
    int? daysUntilRamadan,
    ({String label, Duration remaining, bool isSuhoor})? nextMeal,
    int? hijriOffset,
  }) {
    return RamadanState(
      isRamadan: isRamadan ?? this.isRamadan,
      currentDay: currentDay ?? this.currentDay,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      daysUntilRamadan: daysUntilRamadan ?? this.daysUntilRamadan,
      nextMeal: nextMeal ?? this.nextMeal,
      hijriOffset: hijriOffset ?? this.hijriOffset,
    );
  }

  String get remainingFormatted {
    if (nextMeal == null) return '--:--:--';
    final d = nextMeal!.remaining;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get progress => isRamadan && currentDay > 0 ? currentDay / 30.0 : 0.0;
}

@riverpod
RamadanState ramadan(Ref ref) {
  final prayerService = ref.watch(prayerTimeServiceProvider);
  final offset = ref.watch(hijriOffsetProvider);

  final isRamadan = RamadanService.isRamadan(hijriOffset: offset);
  final currentDay = RamadanService.ramadanDay(hijriOffset: offset);
  final daysRemaining =
      RamadanService.ramadanDaysRemaining(hijriOffset: offset);
  final daysUntilRamadan = RamadanService.daysUntilRamadan(hijriOffset: offset);
  final nextMeal = RamadanService.timeUntilNextMeal(prayerService);

  return RamadanState(
    isRamadan: isRamadan,
    currentDay: currentDay,
    daysRemaining: daysRemaining,
    daysUntilRamadan: daysUntilRamadan,
    nextMeal: nextMeal,
    hijriOffset: offset,
  );
}

@riverpod
bool isRamadan(Ref ref) {
  final offset = ref.watch(hijriOffsetProvider);
  return RamadanService.isRamadan(hijriOffset: offset);
}
