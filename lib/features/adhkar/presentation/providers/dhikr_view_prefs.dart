import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/adhkar/utils/azkar_day_boundary.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// How a dhikr collection is laid out.
///
/// One choice for every collection: the reader picks how they like to read
/// adhkar once, and all ten sections follow. The value is stored by [wire] so a
/// renamed enum constant cannot silently reset somebody's choice.
enum DhikrViewMode {
  list('list', 'فهرست'),
  timeline('timeline', 'تایم‌لاین'),
  focus('focus', 'تمرکز');

  const DhikrViewMode(this.wire, this.label);

  /// Persisted value.
  final String wire;

  /// Persian name on the segmented control.
  final String label;

  static DhikrViewMode fromWire(String? value) {
    for (final mode in DhikrViewMode.values) {
      if (mode.wire == value) return mode;
    }
    return DhikrViewMode.list;
  }
}

/// The session of one collection that is not held by the adhkar provider:
/// which item the reader is on and which ones were passed over.
///
/// Completion flags and repetition counts stay where they have always lived
/// (`azkarProvider`), so this adds state without moving it. The record is
/// stamped with the azkar *day key*, so a session that crosses the daily reset
/// starts clean exactly like the progress rows do.
@immutable
class DhikrSessionStamp {
  const DhikrSessionStamp({
    required this.dayKey,
    this.current = 0,
    this.skipped = const <String>{},
  });

  final String dayKey;
  final int current;
  final Set<String> skipped;

  DhikrSessionStamp copyWith({int? current, Set<String>? skipped}) =>
      DhikrSessionStamp(
        dayKey: dayKey,
        current: current ?? this.current,
        skipped: skipped ?? this.skipped,
      );
}

/// Persisted appearance options for the dhikr collections plus the per
/// collection session stamp.
///
/// Read once at construction, then kept in memory; every setter writes through
/// to [SharedPreferences] without waiting, because these are preferences and
/// not progress (the progress writes are the provider's job).
class DhikrViewPrefs extends ChangeNotifier {
  DhikrViewPrefs() {
    _load();
  }

  static const String modeKey = 'dhikr.viewMode';
  static const String autoAdvanceKey = 'dhikr.autoAdvance';
  static const String hapticsKey = 'dhikr.haptics';
  static const String keepAwakeKey = 'dhikr.keepAwake';

  static String sessionKey(String period) => 'dhikr.session.$period';

  DhikrViewMode _mode = DhikrViewMode.list;
  bool _autoAdvance = true;
  bool _haptics = true;
  bool _keepAwake = true;
  bool _loaded = false;

  DhikrViewMode get mode => _mode;

  /// When a dhikr reaches its count, move on by itself.
  bool get autoAdvance => _autoAdvance;

  /// Light vibration on each count and a stronger one on completion.
  bool get haptics => _haptics;

  /// Keep the screen on while «تمرکز» is open.
  bool get keepAwake => _keepAwake;

  /// False until the stored values arrived; the UI can still render the
  /// defaults, it just must not treat them as the reader's choice yet.
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = DhikrViewMode.fromWire(prefs.getString(modeKey));
      _autoAdvance = prefs.getBool(autoAdvanceKey) ?? true;
      _haptics = prefs.getBool(hapticsKey) ?? true;
      _keepAwake = prefs.getBool(keepAwakeKey) ?? true;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('dhikr_view_prefs', 'load failed: $e');
    }
  }

  Future<void> setMode(DhikrViewMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _write((prefs) => prefs.setString(modeKey, mode.wire));
  }

  Future<void> setAutoAdvance(bool value) async {
    if (_autoAdvance == value) return;
    _autoAdvance = value;
    notifyListeners();
    await _write((prefs) => prefs.setBool(autoAdvanceKey, value));
  }

  Future<void> setHaptics(bool value) async {
    if (_haptics == value) return;
    _haptics = value;
    notifyListeners();
    await _write((prefs) => prefs.setBool(hapticsKey, value));
  }

  Future<void> setKeepAwake(bool value) async {
    if (_keepAwake == value) return;
    _keepAwake = value;
    notifyListeners();
    await _write((prefs) => prefs.setBool(keepAwakeKey, value));
  }

  /// The stored session for [period], or null when there is none for today —
  /// one from a previous dhikr day is dropped, not carried into the new day.
  Future<DhikrSessionStamp?> readSession(String period) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(sessionKey(period));
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final stamp = DhikrSessionStamp(
        dayKey: json['day'] as String? ?? '',
        current: (json['current'] as num?)?.toInt() ?? 0,
        skipped: {
          for (final id in (json['skipped'] as List<dynamic>? ?? const []))
            if (id is String) id,
        },
      );
      if (stamp.dayKey != AzkarDayBoundary.dayKey(DateTime.now())) {
        await prefs.remove(sessionKey(period));
        return null;
      }
      return stamp;
    } catch (e) {
      AppLogger.warning('dhikr_view_prefs', 'session read failed: $e');
      return null;
    }
  }

  Future<void> writeSession(
    String period, {
    required int current,
    required Set<String> skipped,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        sessionKey(period),
        jsonEncode({
          'day': AzkarDayBoundary.dayKey(DateTime.now()),
          'current': current,
          'skipped': skipped.toList(),
        }),
      );
    } catch (e) {
      AppLogger.warning('dhikr_view_prefs', 'session write failed: $e');
    }
  }

  Future<void> _write(Future<bool> Function(SharedPreferences prefs) op) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await op(prefs);
    } catch (e) {
      AppLogger.warning('dhikr_view_prefs', 'write failed: $e');
    }
  }
}

/// The single source of the dhikr collections' appearance and session stamp.
/// The provider owns the notifier and disposes it, so nothing here calls
/// `dispose()` a second time.
final dhikrViewPrefsProvider =
    ChangeNotifierProvider<DhikrViewPrefs>((ref) => DhikrViewPrefs());
