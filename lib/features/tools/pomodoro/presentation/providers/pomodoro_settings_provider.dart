import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class PomodoroSettings {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLong;
  const PomodoroSettings(
      {this.focusMinutes = 25,
      this.shortBreakMinutes = 5,
      this.longBreakMinutes = 15,
      this.sessionsBeforeLong = 4});

  PomodoroSettings copyWith(
          {int? focusMinutes,
          int? shortBreakMinutes,
          int? longBreakMinutes,
          int? sessionsBeforeLong}) =>
      PomodoroSettings(
          focusMinutes: focusMinutes ?? this.focusMinutes,
          shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
          longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
          sessionsBeforeLong: sessionsBeforeLong ?? this.sessionsBeforeLong);
}

class PomodoroSettingsNotifier extends Notifier<PomodoroSettings> {
  static const _kFocus = 'pomodoro_focus';
  static const _kShort = 'pomodoro_short';
  static const _kLong = 'pomodoro_long';
  static const _kSessions = 'pomodoro_sessions';

  /// Resolved when the prefs load finishes. [update] awaits it: the load
  /// assigns `state` wholesale, so an edit saved while the load was in
  /// flight was reverted on screen while the prefs kept the new value.
  Completer<void> _ready = Completer<void>();

  @override
  PomodoroSettings build() {
    _ready = Completer<void>();
    _load();
    return const PomodoroSettings();
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = PomodoroSettings(
        focusMinutes: p.getInt(_kFocus) ?? 25,
        shortBreakMinutes: p.getInt(_kShort) ?? 5,
        longBreakMinutes: p.getInt(_kLong) ?? 15,
        sessionsBeforeLong: p.getInt(_kSessions) ?? 4,
      );
    } catch (e) {
      AppLogger.warning('PomodoroSettings', 'prefs load failed: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> update(PomodoroSettings s) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = s;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kFocus, s.focusMinutes);
    await p.setInt(_kShort, s.shortBreakMinutes);
    await p.setInt(_kLong, s.longBreakMinutes);
    await p.setInt(_kSessions, s.sessionsBeforeLong);
  }
}

final pomodoroSettingsProvider =
    NotifierProvider<PomodoroSettingsNotifier, PomodoroSettings>(
        PomodoroSettingsNotifier.new);
