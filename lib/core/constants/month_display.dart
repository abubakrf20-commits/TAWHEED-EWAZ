import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Which names the solar (Shamsi) months are shown with.
///
/// Both values describe the SAME calendar and the same dates; only the twelve
/// month names differ — Iranians say فروردین…اسفند, Afghans say حمل…حوت.
enum MonthDisplay { iranian, afghan }

const String kMonthDisplayPrefKey = 'month_display';

/// The live choice, read by `DateConstants.persianMonths`.
///
/// A plain [ValueNotifier] rather than a Riverpod provider: `core/constants`
/// is read from PDF builders and the home-widget snapshot too, and the
/// display-aware getter lets every existing call site follow without edits.
final ValueNotifier<MonthDisplay> monthDisplayNotifier =
    ValueNotifier<MonthDisplay>(MonthDisplay.iranian);

MonthDisplay monthDisplayFromStored(String? stored) =>
    stored == MonthDisplay.afghan.name
        ? MonthDisplay.afghan
        : MonthDisplay.iranian;

/// Reads the stored choice WITHOUT publishing it — for call sites that must not
/// depend on the root scope having loaded yet (the home-widget snapshot also
/// runs from a background sync).
Future<MonthDisplay> readStoredMonthDisplay() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return monthDisplayFromStored(prefs.getString(kMonthDisplayPrefKey));
  } catch (error, stackTrace) {
    AppLogger.error('MonthDisplay.read', error, stackTrace);
    return monthDisplayNotifier.value;
  }
}

/// Resolves the stored choice and publishes it to [monthDisplayNotifier].
Future<MonthDisplay> loadMonthDisplay() async {
  final value = await readStoredMonthDisplay();
  monthDisplayNotifier.value = value;
  return value;
}

Future<void> setMonthDisplay(MonthDisplay value) async {
  monthDisplayNotifier.value = value;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kMonthDisplayPrefKey, value.name);
  } catch (error, stackTrace) {
    AppLogger.error('MonthDisplay.save', error, stackTrace);
  }
}
