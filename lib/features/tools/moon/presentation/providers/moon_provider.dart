import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/constants/moon_constants.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

class MoonState {
  final DateTime date;
  final double age;
  final double phase;
  final double illumination;
  final MoonPhaseName phaseName;
  final MoonManzil manzil;
  final DateTime nextNewMoon;
  final DateTime nextFullMoon;
  final bool isAyamBeed;

  MoonState({
    required this.date,
    required this.age,
    required this.phase,
    required this.illumination,
    required this.phaseName,
    required this.manzil,
    required this.nextNewMoon,
    required this.nextFullMoon,
    required this.isAyamBeed,
  });
}

final moonForDateProvider = Provider.family<MoonState, DateTime>((ref, date) {
  // Date-only key: the time-of-day must neither multiply cache entries nor
  // shift the age between the Today tab (opened at some hour) and the 30-day
  // list (built at midnight).
  final day = DateTime(date.year, date.month, date.day);
  return MoonState(
    date: day,
    age: LunarCalculator.moonAge(day),
    phase: LunarCalculator.phase(day),
    illumination: LunarCalculator.illumination(day),
    phaseName: LunarCalculator.phaseName(day),
    manzil: LunarCalculator.currentManzil(day),
    nextNewMoon: LunarCalculator.nextNewMoon(day),
    nextFullMoon: LunarCalculator.nextFullMoon(day),
    isAyamBeed:
        HijriUtils.isAyamAlBidh(day, offset: ref.watch(hijriOffsetProvider)),
  );
});
