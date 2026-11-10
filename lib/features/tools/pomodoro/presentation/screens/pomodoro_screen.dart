import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/features/tools/pomodoro/data/daos/pomodoro_session_dao.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/pomodoro_constants.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/providers/pomodoro_settings_provider.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/session_history.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/timer_controls.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/timer_headers.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/timer_ring.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/widgets/timer_settings_sheet.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  PomodoroMode _mode = PomodoroMode.classic;

  // ── کلاسیک (تمرکز/استراحت) ─────────────────────────────────────────
  int _focusMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _sessionsBeforeLongBreak = 4;

  PomodoroPhase _phase = PomodoroPhase.focus;
  int _completedSessions = 0;
  int _sessionsInCycle = 0;

  // ── شمارش معکوس (مسابقه و…) ───────────────────────────────────────
  int _cdMinutes = 2;
  int _cdSeconds = 0;
  int _cdRounds = 1;
  int _cdRound = 1;
  bool _cdStartBeep = true;
  bool _cdKeepAwake = true;

  bool _running = false;
  bool _cdReady = false; // آماده‌باش 3-2-1
  int _readyLeft = 3;

  // ── تاریخچهٔ جلسات ─────────────────────────────────────────────────
  String _focusType = focusTypes.first;
  List<PomodoroSessionTableData> _history = const [];
  int _todayMinutes = 0;
  List<int> _weekTotals = List.filled(7, 0);
  bool _historyLoading = true;

  /// Failure of the last history read. Without it a failed read rendered as
  /// «هنوز جلسه‌ای ثبت نشده» — an empty history claimed from no data.
  Object? _historyError;

  /// Volume (0..1) of the beep, independent of the device media volume.
  double _beepVolume = 1.0;
  Duration _remaining = const Duration(minutes: 25);

  Timer? _ticker;

  /// Absolute end instant of the current run phase while [_running]. Ticks
  /// clamp the tick-counted remainder against it, so a throttled/backgrounded
  /// Timer never drifts behind real time. Every external change of
  /// `_remaining` re-anchors or clears it.
  DateTime? _deadline;
  late final AnimationController _ring;
  final AudioPlayer _beep = AudioPlayer();
  Future<void> _beepQueue = Future<void>.value();
  bool _disposed = false;

  /// True once a paused/deadline run state was restored from prefs — the
  /// settings listener must not overwrite the restored remaining time.
  bool _runStateRestored = false;

  @override
  void initState() {
    super.initState();
    _remaining = const Duration(minutes: 25);
    _ring =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _ring.value = 1.0;
    _loadPrefs();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final dao = ref.read(pomodoroSessionDaoProvider);
      final history = await dao.recentSessions();
      final today = await dao.todayMinutes();
      final week = await dao.last7DaysTotals();
      if (!mounted) return;
      setState(() {
        _history = history;
        _todayMinutes = today;
        _weekTotals = week;
        _historyError = null;
        _historyLoading = false;
      });
    } catch (e, st) {
      AppLogger.error('pomodoro: history load failed', e, st);
      if (!mounted) return;
      setState(() {
        _historyError = e;
        _historyLoading = false;
      });
    }
  }

  /// Retry from the history block. The failure stays on screen until the fresh
  /// read lands, so the summary never re-claims a zero it does not have.
  Future<void> _retryHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    await _loadHistory();
  }

  Future<void> _recordSession({required String mode}) async {
    final dao = ref.read(pomodoroSessionDaoProvider);
    final duration =
        mode == 'countdown' ? (_cdTotal.inSeconds + 59) ~/ 60 : _focusMinutes;
    await dao.insert(
      startedAt: DateTime.now(),
      durationMinutes: duration,
      mode: mode,
      focusType: _focusType,
    );
    await _loadHistory();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    // A running timer keeps its scheduled completion alert even when the
    // user leaves the screen — that notification is the point of running a
    // timer in the first place. Paused/finished runs have nothing to announce.
    if (!_running) _cancelPomodoroNotif();
    _ring.dispose();
    // Queue cleanup behind any in-flight stop/play operation. Some Android
    // MediaPlayer implementations crash when disposed during a transition.
    final cleanup = _beepQueue.then<void>((_) async {
      try {
        await _beep.stop();
      } catch (_) {
        AppLogger.warning('pomodoro_screen', 'operation failed');
      }
      try {
        await _beep.dispose();
      } catch (_) {
        AppLogger.warning('pomodoro_screen', 'operation failed');
      }
    });
    _beepQueue = cleanup.catchError((_) {});
    unawaited(cleanup);
    _setAwake(false);
    super.dispose();
  }

  // ── تنظیمات ذخیره‌شده ──────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        if (p.getString('pomodoro_mode') == 'countdown') {
          _mode = PomodoroMode.countdown;
        }
        _cdMinutes = p.getInt('pomodoro_cd_min') ?? 2;
        _cdSeconds = p.getInt('pomodoro_cd_sec') ?? 0;
        _cdRounds = (p.getInt('pomodoro_cd_rounds') ?? 1).clamp(1, 10);
        _cdStartBeep = p.getBool('pomodoro_cd_beep') ?? true;
        _cdKeepAwake = p.getBool('pomodoro_cd_awake') ?? true;
        _beepVolume =
            (p.getDouble('sound_alert_volume') ?? 1.0).clamp(0.0, 1.0);
        final savedType = p.getString('pomodoro_focus_type');
        if (savedType != null && focusTypes.contains(savedType)) {
          _focusType = savedType;
        }
        // Classic durations live in pomodoroSettingsProvider, but they must
        // already be in place here — otherwise a paused 30-minute phase
        // would be rejected against the 25-minute default below.
        _focusMinutes = p.getInt('pomodoro_focus') ?? _focusMinutes;
        _shortBreakMinutes = p.getInt('pomodoro_short') ?? _shortBreakMinutes;
        _longBreakMinutes = p.getInt('pomodoro_long') ?? _longBreakMinutes;
        _sessionsBeforeLongBreak =
            p.getInt('pomodoro_sessions') ?? _sessionsBeforeLongBreak;

        // Restore the interrupted cycle: phase/counters survive an app kill.
        _phase = PomodoroPhase.values
                .asNameMap()[p.getString('pomodoro_phase') ?? ''] ??
            PomodoroPhase.focus;
        _completedSessions =
            p.getInt('pomodoro_completed') ?? _completedSessions;
        _sessionsInCycle = p.getInt('pomodoro_cycle') ?? _sessionsInCycle;
        _cdRound = (p.getInt('pomodoro_cd_round') ?? 1).clamp(1, _cdRounds);

        _remaining =
            _mode == PomodoroMode.countdown ? _cdTotal : _phaseDuration;
        _ring.value = 1.0;
        final paused = p.getInt('pomodoro_paused_s');
        final total = _totalSeconds;
        if (paused != null && paused > 0 && total > 0 && paused <= total) {
          _remaining = Duration(seconds: paused);
          _ring.value = paused / total;
          _runStateRestored = true;
        }
      });
      // A deadline written by a previous (killed) run resumes or finishes.
      await _resumeFromPrefs(p);
    } catch (_) {
      AppLogger.warning('pomodoro_screen', 'operation failed');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pomodoro_mode', _mode.name);
      await p.setInt('pomodoro_cd_min', _cdMinutes);
      await p.setInt('pomodoro_cd_sec', _cdSeconds);
      await p.setInt('pomodoro_cd_rounds', _cdRounds);
      await p.setBool('pomodoro_cd_beep', _cdStartBeep);
      await p.setBool('pomodoro_cd_awake', _cdKeepAwake);
      await p.setString('pomodoro_focus_type', _focusType);
    } catch (e) {
      // Called only from settings changes (five sites), never from the tick,
      // so one message per change cannot spam. Without it the reader adjusts
      // the timer, sees the new numbers, and finds the old ones tomorrow.
      AppLogger.warning('pomodoro_screen', 'settings save failed: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'تنظیمات پومودورو ذخیره نشد.',
        onRetry: _savePrefs,
      );
    }
  }

  // ── ازسرگیری تایمر پس از بسته شدن اپ ─────────────────────────────
  /// Persists enough state to survive an app kill: the absolute phase
  /// deadline while running (wall-clock based, so the countdown stays
  /// correct), the remaining seconds while paused, plus the cycle counters.
  Future<void> _persistRunState({required bool running}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (running) {
        // Prefer the live wall-clock anchor; the recomputation on resume and
        // on throttled ticks both depend on it staying absolute.
        final deadline = _deadline ?? DateTime.now().add(_remaining);
        await p.setInt('pomodoro_deadline_ms', deadline.millisecondsSinceEpoch);
        await p.remove('pomodoro_paused_s');
      } else {
        await p.remove('pomodoro_deadline_ms');
        if (_remaining.inSeconds > 0) {
          await p.setInt('pomodoro_paused_s', _remaining.inSeconds);
        } else {
          await p.remove('pomodoro_paused_s');
        }
      }
      await p.setString('pomodoro_phase', _phase.name);
      await p.setInt('pomodoro_completed', _completedSessions);
      await p.setInt('pomodoro_cycle', _sessionsInCycle);
      await p.setInt('pomodoro_cd_round', _cdRound);
    } catch (_) {
      AppLogger.warning('pomodoro_screen', 'operation failed');
    }
  }

  /// Drops the persisted run state (reset / mode switch) so the next launch
  /// starts fresh. Cycle counters are kept — they are re-persisted on the
  /// next run anyway.
  Future<void> _clearRunState() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('pomodoro_deadline_ms');
      await p.remove('pomodoro_paused_s');
    } catch (_) {
      AppLogger.warning('pomodoro_screen', 'operation failed');
    }
  }

  /// Called once from [_loadPrefs] with the freshly loaded prefs. A future
  /// deadline resumes the countdown in place; a deadline that already
  /// passed finishes the phase/round so the elapsed time is not lost
  /// (the focus session is recorded exactly as if it had run in-app).
  Future<void> _resumeFromPrefs(SharedPreferences p) async {
    final deadlineMs = p.getInt('pomodoro_deadline_ms') ?? 0;
    if (deadlineMs <= 0) return;
    await p.remove('pomodoro_deadline_ms');
    if (!mounted) return;

    final left = DateTime.fromMillisecondsSinceEpoch(deadlineMs)
        .difference(DateTime.now());
    if (left.inSeconds > 0) {
      final total = _totalSeconds;
      setState(() {
        _remaining = left;
        _deadline = DateTime.now().add(left);
        _ring.value =
            total > 0 ? (left.inSeconds / total).clamp(0.0, 1.0) : 0.0;
        _running = true;
        _cdReady = false;
      });
      _runStateRestored = true;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _setAwake(true);
      _scheduleCompletionNotif();
      // Re-arm the deadline for a second kill while still running.
      unawaited(_persistRunState(running: true));
    } else {
      // Expired while away → complete the phase/round after the first
      // frame (the completion handlers need a mounted widget tree).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_mode == PomodoroMode.countdown) {
          _onCountdownRoundComplete();
        } else {
          _onPhaseComplete();
        }
      });
    }
  }

  // ── محاسبات ────────────────────────────────────────────────────────
  Duration get _phaseDuration => switch (_phase) {
        PomodoroPhase.focus => Duration(minutes: _focusMinutes),
        PomodoroPhase.shortBreak => Duration(minutes: _shortBreakMinutes),
        PomodoroPhase.longBreak => Duration(minutes: _longBreakMinutes),
      };

  Duration get _cdTotal {
    final secs = _cdMinutes * 60 + _cdSeconds;
    return Duration(seconds: secs < 1 ? 1 : secs);
  }

  int get _totalSeconds => _mode == PomodoroMode.countdown
      ? _cdTotal.inSeconds
      : _phaseDuration.inSeconds;

  Color get _accent => _mode == PomodoroMode.countdown
      ? countdownAccent
      : (_phase == PomodoroPhase.focus
          ? pomodoroAccent
          : Colors.green.shade600);

  // ── صدا و روشن ماندن صفحه ──────────────────────────────────────────
  Future<void> _enqueueBeep(Future<void> Function() action) {
    final next = _beepQueue.then<void>((_) async {
      if (_disposed) return;
      await action();
    });
    _beepQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _playBeep() {
    return _enqueueBeep(() async {
      try {
        await _beep.stop();
        await _beep.setVolume(_beepVolume.clamp(0.0, 1.0));
        await _beep.play(AssetSource(SoundRegistry.reminder.asset));
      } catch (_) {
        AppLogger.warning('pomodoro_screen', 'operation failed');
      }
    });
  }

  /// Special double-beep used when a countdown (race) round starts,
  /// instead of the generic notification beep.
  Future<void> _playRaceStartBeep() {
    return _enqueueBeep(() async {
      try {
        await _beep.stop();
        await _beep.setVolume(_beepVolume.clamp(0.0, 1.0));
        await _beep.play(AssetSource(SoundRegistry.raceStart.asset));
      } catch (_) {
        AppLogger.warning('pomodoro_screen', 'operation failed');
      }
    });
  }

  /// Whether a *currently running* session is allowed to hold the screen on.
  /// Only an explicit countdown run that opted in may acquire.
  bool get _awakePolicy => _mode == PomodoroMode.countdown && _cdKeepAwake;

  /// Acquire is policy-gated; **release is never gated.**
  ///
  /// A release behind the same policy that granted it stops running the moment
  /// the policy flips — switching the mode (line `_setMode` sets `_mode` before
  /// releasing), or leaving the screen while a non-countdown mode is active.
  /// Every one of those paths was a real leak: the shared wakelock (and with it
  /// the screen) stayed held until the process died. A release nobody can
  /// silently skip is the only safe shape.
  Future<void> _setAwake(bool on) async {
    if (on && !_awakePolicy) return;
    try {
      if (on) {
        await AppWakelock.acquire('pomodoro');
      } else {
        await AppWakelock.release('pomodoro');
      }
    } catch (_) {
      AppLogger.warning(
          'pomodoro_screen', on ? 'wakelock acquire failed' : 'wakelock release failed');
    }
  }

  static const _pomodoroNotifId = 7843;
  static const _pomodoroChannelId = 'pomodoro_timer';

  Future<void> _scheduleCompletionNotif() async {
    try {
      // Use the shared initialized plugin (correct tz.local + permissions),
      // never a fresh instance: a fresh plugin + bare initializeTimeZones
      // leaves tz.local at UTC and fires at the wrong wall-clock hour.
      final service = NotificationService();
      await service.cancel(_pomodoroNotifId);
      await service.plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _pomodoroChannelId,
            'پومودورو',
            description: 'پایان تمرکز و استراحت',
            importance: Importance.high,
          ));
      final when = tz.TZDateTime.now(tz.local).add(_remaining);
      final title = _mode == PomodoroMode.countdown
          ? 'پایان دور $_cdRound'
          : (_phase == PomodoroPhase.focus ? 'پایان تمرکز' : 'پایان استراحت');
      await service.scheduleExactReminder(
        id: _pomodoroNotifId,
        title: title,
        body: 'زمان به پایان رسید',
        scheduledTime: when,
        details: const AndroidNotificationDetails(
            _pomodoroChannelId, 'پومودورو',
            importance: Importance.high, priority: Priority.high),
      );
    } catch (_) {
      AppLogger.warning('pomodoro_screen', 'operation failed');
    }
  }

  Future<void> _cancelPomodoroNotif() async {
    try {
      await NotificationService().cancel(_pomodoroNotifId);
    } catch (_) {
      AppLogger.warning('pomodoro_screen', 'operation failed');
    }
  }

  // ── کنترل‌ها ───────────────────────────────────────────────────────
  void _start() {
    HapticFeedback.mediumImpact();
    // A countdown round with the start beep begins with a 3-2-1 «آماده‌باش».
    final startReady = _mode == PomodoroMode.countdown &&
        _cdStartBeep &&
        !_cdReady &&
        _remaining == _cdTotal;
    setState(() {
      _running = true;
      if (startReady) {
        _cdReady = true;
        _readyLeft = 3;
      } else {
        _cdReady = false;
        _deadline = DateTime.now().add(_remaining);
      }
    });
    if (startReady) {
      _playRaceStartBeep();
      // The completion alert is armed when the 3-2-1 ends (see [_tick]) —
      // scheduling it now would fire ~3s before the round actually starts.
    } else {
      _scheduleCompletionNotif();
      unawaited(_persistRunState(running: true));
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _setAwake(true);
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _ticker?.cancel();
    _cancelPomodoroNotif();
    setState(() {
      _running = false;
      _cdReady = false;
      _deadline = null;
    });
    _setAwake(false);
    unawaited(_persistRunState(running: false));
  }

  void _reset() {
    _ticker?.cancel();
    _cancelPomodoroNotif();
    setState(() {
      _running = false;
      _cdReady = false;
      _cdRound = 1;
      _deadline = null;
      _remaining = _mode == PomodoroMode.countdown ? _cdTotal : _phaseDuration;
      _ring.value = 1.0;
    });
    _setAwake(false);
    unawaited(_clearRunState());
  }

  /// «شروع سیکل تازه» — ends the running cycle without touching the tally.
  ///
  /// The long break is a rule of four *back-to-back* sessions. A reader who
  /// stopped after the second one and came back after lunch, or the next
  /// morning, does not want a 15-minute break at the third; this rewinds the
  /// cycle to its first focus session and stops the clock. The completed-session
  /// count is a record of work done, so it stays.
  Future<void> _startFreshCycle() async {
    if (_mode != PomodoroMode.classic) return;
    _ticker?.cancel();
    _cancelPomodoroNotif();
    setState(() {
      _sessionsInCycle = 0;
      _phase = PomodoroPhase.focus;
      _remaining = _phaseDuration;
      _deadline = null;
      _running = false;
      _ring.value = 1.0;
    });
    _setAwake(false);
    unawaited(_persistRunState(running: false));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'سیکل تازه آغاز شد؛ جلسهٔ بعدی نخستین جلسهٔ چرخه است.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: pomodoroAccent,
      ));
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (_cdReady) {
        _readyLeft--;
        _playBeep();
        if (_readyLeft <= 0) {
          _cdReady = false;
          _remaining = _cdTotal;
          _deadline = DateTime.now().add(_cdTotal);
          _ring.value = 1.0;
          // The countdown itself starts here — arm the completion alert now so
          // it fires at the true end of the round, not ~3s early.
          _scheduleCompletionNotif();
          unawaited(_persistRunState(running: true));
        }
        return;
      }
      _remaining = _remaining - const Duration(seconds: 1);
      // Wall-clock clamp: a throttled/backgrounded ticker loses display
      // frames, not real seconds — the absolute deadline wins whenever it
      // is further along than the tick count. (widget_test pump() advances
      // timers but not DateTime.now(), so the tick stays authoritative
      // there and completions still fire.)
      final dl = _deadline ??= DateTime.now().add(_remaining);
      final wall = dl.difference(DateTime.now());
      if (wall < _remaining) _remaining = wall;
      final total = _totalSeconds;
      _ring.value = total > 0 ? (_remaining.inSeconds / total).clamp(0, 1) : 0;
      if (_remaining.inSeconds <= 0) {
        if (_mode == PomodoroMode.countdown) {
          _onCountdownRoundComplete();
        } else {
          _onPhaseComplete();
        }
      }
    });
  }

  void _onPhaseComplete() {
    _ticker?.cancel();
    _cancelPomodoroNotif();
    HapticFeedback.heavyImpact();
    if (_phase == PomodoroPhase.focus) {
      _completedSessions++;
      _sessionsInCycle++;
      unawaited(_recordSession(mode: 'classic'));
      _phase = _sessionsInCycle >= _sessionsBeforeLongBreak
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
      if (_sessionsInCycle >= _sessionsBeforeLongBreak) _sessionsInCycle = 0;
    } else {
      _phase = PomodoroPhase.focus;
    }
    _remaining = _phaseDuration;
    _deadline = null;
    _ring.value = 1.0;
    _running = false;
    unawaited(_persistRunState(running: false));
  }

  void _onCountdownRoundComplete() {
    _ticker?.cancel();
    _cancelPomodoroNotif();
    HapticFeedback.heavyImpact();
    _playBeep();
    _setAwake(false);
    unawaited(_recordSession(mode: 'countdown'));
    if (_cdRounds > 1 && _cdRound < _cdRounds) {
      setState(() {
        _cdRound++;
        _remaining = _cdTotal;
        _deadline = null;
        _ring.value = 1.0;
        _running = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'دور $_cdRound از $_cdRounds آماده است',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: countdownAccent,
        ));
    } else {
      setState(() {
        _remaining = _cdTotal;
        _deadline = null;
        _ring.value = 1.0;
        _running = false;
      });
      _showFinishDialog();
    }
    unawaited(_persistRunState(running: false));
  }

  Future<void> _confirmClearHistory() async {
    final t = TimeThemeKit.of(context).palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('پاک کردن تاریخچه'),
        content: const Text('همهٔ جلسات ثبت‌شده حذف می‌شوند. ادامه می‌دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pomodoroAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(pomodoroSessionDaoProvider).clearAll();
    await _loadHistory();
  }

  Future<void> _showFinishDialog() async {
    final t = TimeThemeKit.of(context).palette;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 مسابقه تمام شد'),
        content: const Text('زمان به پایان رسید. آمادهٔ دور بعدی هستید؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reset();
            },
            child: const Text('دوباره'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: countdownAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _cdRound = 1);
              _start();
            },
            child: const Text('شروع دوباره'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final t = TimeThemeKit.of(context).palette;
    _pause();
    final result = await showModalBottomSheet<TimerSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TimerSettingsSheet(
        focus: _focusMinutes,
        shortBreak: _shortBreakMinutes,
        longBreak: _longBreakMinutes,
        sessions: _sessionsBeforeLongBreak,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _focusMinutes = result.focus;
      _shortBreakMinutes = result.shortBreak;
      _longBreakMinutes = result.longBreak;
      _sessionsBeforeLongBreak = result.sessions;
      if (!_running) {
        _remaining = _phaseDuration;
        _ring.value = 1.0;
      }
    });
    // Persist classic durations to the single source of truth (the provider
    // also notifies the initState listener, which re-applies them).
    unawaited(ref.read(pomodoroSettingsProvider.notifier).update(
          PomodoroSettings(
            focusMinutes: result.focus,
            shortBreakMinutes: result.shortBreak,
            longBreakMinutes: result.longBreak,
            sessionsBeforeLong: result.sessions,
          ),
        ));
    // Durations may have changed while paused → refresh the saved remainder.
    unawaited(_persistRunState(running: false));
  }

  void _switchMode(PomodoroMode m) {
    if (m == _mode) return;
    _ticker?.cancel();
    // The old mode's completion alert is no longer meaningful here.
    _cancelPomodoroNotif();
    HapticFeedback.lightImpact();
    setState(() {
      _mode = m;
      _running = false;
      _cdReady = false;
      _cdRound = 1;
      _deadline = null;
      _remaining = m == PomodoroMode.countdown ? _cdTotal : _phaseDuration;
      _ring.value = 1.0;
    });
    _setAwake(false);
    _savePrefs();
    unawaited(_clearRunState());
  }

  String get _phaseLabel => switch (_phase) {
        PomodoroPhase.focus => 'تمرکز',
        PomodoroPhase.shortBreak => 'استراحت کوتاه',
        PomodoroPhase.longBreak => 'استراحت طولانی',
      };

  String get _mmss {
    final total = _cdReady ? _readyLeft : _remaining.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _applyCdTime({int? minutes, int? seconds}) {
    setState(() {
      if (minutes != null) _cdMinutes = minutes;
      if (seconds != null) _cdSeconds = seconds;
      _cdRound = 1;
      _remaining = _cdTotal;
      // Re-anchor mid-run so the new duration starts from *now*.
      _deadline = _running && !_cdReady ? DateTime.now().add(_cdTotal) : null;
      _ring.value = 1.0;
    });
    _savePrefs();
  }

  String get _statusLabel {
    if (_cdReady) return 'آماده…';
    return _running ? 'در حال اجرا…' : 'آماده';
  }

  String get _caption {
    if (_mode == PomodoroMode.countdown) {
      final m = _cdMinutes;
      final s = _cdSeconds;
      final time = s > 0 ? '$m′ $s″' : '$m دقیقه';
      return 'مدت: $time · دورها: $_cdRounds';
    }
    return 'چرخه: $_focusMinutes′ تمرکز · $_shortBreakMinutes′ استراحت · $_longBreakMinutes′ بعد از $_sessionsBeforeLongBreak جلسه';
  }

  @override
  Widget build(BuildContext context) {
    // Classic durations live in pomodoroSettingsProvider (single source of
    // truth); sync them when the provider finishes its async load or
    // whenever settings are saved (restart no longer loses custom 25/5/15).
    // (Subscriptions made in build are closed on rebuild/dispose by Riverpod.)
    ref.listen<PomodoroSettings>(pomodoroSettingsProvider, (_, next) {
      if (!mounted) return;
      setState(() {
        _focusMinutes = next.focusMinutes;
        _shortBreakMinutes = next.shortBreakMinutes;
        _longBreakMinutes = next.longBreakMinutes;
        _sessionsBeforeLongBreak = next.sessionsBeforeLong;
        if (_mode != PomodoroMode.countdown) {
          if (!_running && !_runStateRestored) {
            _remaining = _phaseDuration;
            _ring.value = 1.0;
          } else if (_totalSeconds > 0) {
            // Keep the ring honest when durations changed under a restored
            // (paused/running) timer instead of wiping the restored value.
            _ring.value =
                (_remaining.inSeconds / _totalSeconds).clamp(0.0, 1.0);
          }
        }
      });
    });
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = t.textMuted;
    final accent = _accent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'پومودور',
        actions: [
          if (_mode == PomodoroMode.classic)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'تنظیمات تایمر',
              onPressed: _openSettings,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // حالت‌ها
              SegmentedButton<PomodoroMode>(
                segments: const [
                  ButtonSegment(
                    value: PomodoroMode.classic,
                    label: Text('پومودور'),
                    icon: Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment(
                    value: PomodoroMode.countdown,
                    label: Text('شمارش معکوس'),
                    icon: Icon(Icons.hourglass_bottom),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStatePropertyAll(accent),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? accent.withValues(alpha: isDark ? 0.26 : 0.14)
                        : null,
                  ),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
                    ),
                  ),
                ),
                onSelectionChanged: (s) => _switchMode(s.first),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_mode == PomodoroMode.classic)
                        ClassicTimerHeader(
                          phaseLabel: _phaseLabel,
                          phase: _phase,
                          focusType: _focusType,
                          running: _running,
                          completedSessions: _completedSessions,
                          sessionsInCycle: _sessionsInCycle,
                          sessionsBeforeLongBreak: _sessionsBeforeLongBreak,
                          onFocusTypeChanged: (type) {
                            setState(() => _focusType = type);
                            _savePrefs();
                          },
                          onFreshCycle: () => unawaited(_startFreshCycle()),
                        )
                      else
                        CountdownTimerHeader(
                          running: _running,
                          cdMinutes: _cdMinutes,
                          cdSeconds: _cdSeconds,
                          cdRounds: _cdRounds,
                          cdStartBeep: _cdStartBeep,
                          cdKeepAwake: _cdKeepAwake,
                          onPresetSelected: (mins) => setState(() {
                            _cdMinutes = mins;
                            _cdSeconds = 0;
                            _cdRound = 1;
                            _remaining = _cdTotal;
                            _deadline = null;
                            _ring.value = 1.0;
                          }),
                          onMinutesChanged: (v) => _applyCdTime(minutes: v),
                          onSecondsChanged: (v) => _applyCdTime(seconds: v),
                          onRoundsChanged: (v) => setState(() {
                            _cdRounds = v.clamp(1, 10);
                            if (_cdRound > _cdRounds) _cdRound = _cdRounds;
                          }),
                          onStartBeepChanged: (v) {
                            setState(() => _cdStartBeep = v);
                            _savePrefs();
                          },
                          onKeepAwakeChanged: (v) {
                            setState(() => _cdKeepAwake = v);
                            if (!v) _setAwake(false);
                            _savePrefs();
                          },
                        ),
                      const SizedBox(height: 18),
                      // حلقهٔ شمارش
                      TimerRing(
                        progress: _ring.value,
                        timeText: _mmss,
                        statusLabel: _statusLabel,
                        accent: accent,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      if (_mode == PomodoroMode.countdown && _cdRounds > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: countdownAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: countdownAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag_outlined,
                                  size: 14, color: countdownAccent),
                              const SizedBox(width: 6),
                              Text(
                                'دور $_cdRound از $_cdRounds',
                                style: TextStyle(
                                  color: countdownAccent,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      // کنترل‌ها
                      TimerControls(
                        running: _running,
                        accent: accent,
                        onPlayPause: () => _running ? _pause() : _start(),
                        onReset: _reset,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _caption,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 12)),
                      ),
                      const SizedBox(height: 24),
                      SessionHistorySection(
                        todayMinutes: _todayMinutes,
                        history: _history,
                        weekTotals: _weekTotals,
                        loading: _historyLoading,
                        error: _historyError,
                        onRetry: _retryHistory,
                        onClearHistory: _confirmClearHistory,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
