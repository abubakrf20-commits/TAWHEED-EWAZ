import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the post-launch jank fix (the app scrolled like sludge for ~20 s).
///
/// The cause was not Dart: a launch reschedule issued a few hundred per-id
/// `setAlarmClock` calls, each an awaited method-channel round trip whose
/// Kotlin handler ran on the Android MAIN thread, so binder + prefs work
/// happened inline while the user was already scrolling. The five remedies are
/// (1) one batched `applyReminderOps` per pass answered on a worker thread,
/// (2) an arm that is skipped when the stored spec already matches, (3) boot
/// emitters coalesced into a single Dart pass, (4) the "nothing changed" branch
/// throttled, (5) no `needs_reschedule` stamp while the app is on screen.
///
/// Dart tests never compile Kotlin and `Platform.isAndroid` is false under
/// `flutter test` on Windows, so the native half and the op queue are pinned by
/// source scan (the repo's style for native invariants — see
/// android_manifest_queries_test.dart). The behavioural proofs are the JVM
/// ExactReminderOpsTest and the Dart coalescing/throttle unit tests.
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

int _countOf(String source, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(source).length;

void main() {
  group('R1 the reminder storm is one batch on a worker thread', () {
    late String service;
    late String main;

    setUpAll(() async {
      service = await readSource('lib/shared/services/notification_service.dart');
      main = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/MainActivity.kt');
    });

    test('dart collects ops and flushes them in one call', () {
      expect(service.contains('Future<T> batchNativeReminders<T>(Future<T> Function() body) async {'),
          isTrue,
          reason: 'a pass must open a batch');
      expect(service.contains('_nativeOpBatchDepth++'), isTrue);
      expect(service.contains('if (--_nativeOpBatchDepth == 0) {'), isTrue,
          reason: 'only the outermost exit may flush, so a nested caller cannot '
              'send a partial batch');
      expect(service.contains('await _flushNativeOps();'), isTrue);
      expect(service.contains("'applyReminderOps',"), isTrue,
          reason: 'the whole queue must travel as ONE method call');
      expect(service.contains("{'opsJson': jsonEncode(ops)},"), isTrue);
    });

    test('a non-android platform never queues into a channel with no handler',
        () {
      expect(service.contains('Future<void> _enqueueNativeOp(Map<String, Object?> op) async {'),
          isTrue);
      expect(
          service.contains(
              'Future<void> _enqueueNativeOp(Map<String, Object?> op) async {\n'
              '    if (!Platform.isAndroid) return;'),
          isTrue,
          reason: 'iOS has no native alarm: a call would only throw '
              'MissingPluginException');
      expect(service.contains('_nativeOps.add(op);'), isTrue);
    });

    test('a failed batch retries every op on its own', () {
      expect(service.contains('for (final op in ops) {'), isTrue,
          reason: 'the batch is all-or-nothing; losing it silently would leave '
              'a disabled reminder ringing');
      expect(service.contains('await _invokeNativeOp(op);'), isTrue);
      expect(service.contains("case 'arm':"), isTrue,
          reason: 'the fallback must speak the legacy single-op method names');
      expect(
          service.contains(
              "await _exactReminders.invokeMethod('scheduleReminder', {"),
          isTrue);
      expect(service.contains("'triggerTimeMillis': op['timeMillis'],"), isTrue);
      expect(service.contains("case 'cancel':"), isTrue);
      expect(service.contains("case 'cancelRange':"), isTrue);
    });

    test('the exact-alarm grant is queried once per batch', () {
      expect(service.contains('if (batching && _modeQueriedInBatch) return;'),
          isTrue,
          reason: 'each query is another awaited platform-thread round trip and '
              'the answer cannot change while a pass runs');
      expect(service.contains('_modeQueriedInBatch = batching;'), isTrue);
    });

    test('kotlin answers the reminders channel off the main thread', () {
      expect(main.contains('HandlerThread("reminder-alarms")'), isTrue);
      expect(
          main.contains(
              'private fun replyAsync(result: MethodChannel.Result, work: (Context) -> Any?) {'),
          isTrue);
      expect(main.contains('reminders().post {'), isTrue);
      expect(main.contains('runOnUiThread {'), isTrue,
          reason: 'MethodChannel.Result must be called on the platform thread');
      expect(main.contains('call.argument<String>("opsJson")'), isTrue);
      expect(main.contains('reminderThread?.quitSafely()'), isTrue,
          reason: 'the worker must not outlive the engine');
    });

    test('nothing on the reminders channel is answered inline', () {
      final start = main.indexOf('REMINDERS_CHANNEL).setMethodCallHandler');
      final end = main.indexOf('// ── WIDGETS CHANNEL ──');
      expect(start, greaterThan(0), reason: 'the reminders channel exists');
      expect(end, greaterThan(start), reason: 'and its block is delimited');
      final channel = main.substring(start, end);
      expect(channel.contains('result.success('), isFalse,
          reason: 'an inline success reply means the binder work ran on the '
              'UI thread — the exact defect this fix removes');
      expect(_countOf(channel, '-> replyAsync(result)'), 7,
          reason: 'all seven methods — batched and legacy alike — go through '
              'the worker; a new method must too');
    });

    test('the scheduling pass runs inside the batch', () async {
      final scheduler = await readSource(
          'lib/shared/services/daily_notification_scheduler.dart');
      expect(
          scheduler.contains(
              'await NotificationService().batchNativeReminders('),
          isTrue,
          reason: 'without this the ops are still one round trip per id');
    });
  });

  group('R2 an alarm that is already current is not re-armed', () {
    late String sched;

    setUpAll(() async {
      sched = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/core/ExactReminderScheduler.kt');
    });

    test('the batch arms with force = false', () {
      expect(
          sched.contains('fun applyOps(context: Context, opsJson: String?): Map<String, Int>'),
          isTrue);
      expect(sched.contains('arm(context, op.request, force = false)'), isTrue,
          reason: 'setAlarmClock replaces whatever the id holds, so a repeat '
              'arm is pure main-thread waste');
      expect(sched.contains('if (!force) {'), isTrue);
      expect(
          sched.contains(
              'isArmCurrent(stored, request, now, bootTimeMillis(now))'),
          isTrue,
          reason: 'the comparison is field-by-field, never by toString()');
      expect(sched.contains('"unchanged" to unchanged'), isTrue);
    });

    test('the self-heal entries still force', () {
      expect(sched.contains('force = true,'), isTrue,
          reason: 'rescheduleAllAfterBoot and the single-op legacy path must '
              'never skip');
      expect(_countOf(sched, 'force = true,'), greaterThanOrEqualTo(1));
    });

    test('a failed arm purges the spec it just wrote', () {
      expect(sched.contains('if (failure != null) {'), isTrue);
      final failureBlock = sched.substring(sched.indexOf('if (failure != null) {'));
      expect(
          failureBlock.substring(0, 400).contains('cancel(context, request.id)'),
          isTrue,
          reason: 'left alone, the stored spec would read as current while '
              'nothing is armed — a reminder that never fires');
      expect(sched.contains('return ArmResult.Failed'), isTrue);
      expect(sched.contains('"failed" to failed'), isTrue);
    });

    test('the stamp is boot-relative and freshness-bounded', () {
      expect(sched.contains('private fun bootTimeMillis(now: Long): Long'), isTrue,
          reason: 'Android clears every alarm on reboot, so a stamp from '
              'before this boot proves nothing');
      expect(sched.contains('ARM_FRESH_MS'), isTrue);
      expect(sched.contains('val (ops, dropped) = decodeOps(opsJson)'), isTrue,
          reason: 'a malformed entry is dropped, never thrown — one bad op '
              'must not abort the batch');
    });
  });

  group('R3 the boot emitters collapse into one pass', () {
    late String scheduler;

    setUpAll(() async {
      scheduler = await readSource(
          'lib/shared/services/daily_notification_scheduler.dart');
    });

    test('both entry points go through the coalescer', () {
      expect(scheduler.contains('static const Duration coalesceWindow'), isTrue);
      expect(_countOf(scheduler, '_request('), greaterThanOrEqualTo(3),
          reason: 'scheduleIfNeeded and forceReschedule both delegate here');
      expect(scheduler.contains('        force: false,'), isTrue,
          reason: 'scheduleIfNeeded must not force');
      expect(scheduler.contains('        force: true,'), isTrue,
          reason: 'forceReschedule must route here with force');
    });

    test('the newest settings win, and a queued force is not lost', () {
      expect(scheduler.contains('_pendingSettings = settings;'), isTrue,
          reason: 'a trailing window, not leading: a boot path that reads '
              'settings a moment later must not be dropped');
      expect(scheduler.contains('_pendingForce = _pendingForce || force;'), isTrue);
      expect(scheduler.contains('_coalesceTimer = Timer(coalesceWindow, () {'),
          isTrue);
      expect(scheduler.contains('_coalesceTimer?.cancel();'), isTrue,
          reason: 'every request restarts the window so the last one defines it');
    });

    test('a force runs at once', () {
      expect(scheduler.contains('if (force) {'), isTrue);
      expect(scheduler.contains('unawaited(_runPendingPass());'), isTrue,
          reason: 'the user is looking at the change; it cannot wait behind '
              'the window');
      expect(_countOf(scheduler, 'unawaited(_runPendingPass());'), 2);
    });

    test('every caller keeps its own future and gets the pass error', () {
      expect(scheduler.contains('final List<Completer<void>> _pendingWaiters = [];'),
          isTrue);
      expect(scheduler.contains('if (!w.isCompleted) w.complete();'), isTrue);
      expect(scheduler.contains('if (!w.isCompleted) w.completeError(e, st);'),
          isTrue,
          reason: 'the call sites\' existing catchError/try-catch must keep '
              'describing what happens');
    });
  });

  group('R4 the "nothing changed" branch is throttled', () {
    late String scheduler;

    setUpAll(() async {
      scheduler = await readSource(
          'lib/shared/services/daily_notification_scheduler.dart');
    });

    test('a reconcile that just ran is skipped', () {
      expect(scheduler.contains('if (!_reconcileIsDue(fp)) {'), isTrue);
      expect(scheduler.contains('static const Duration reconcileInterval = Duration(minutes: 2);'),
          isTrue);
      expect(scheduler.contains("static const String _reconciledAtKey = 'lastReconciledAtMillis';"),
          isTrue);
      expect(_countOf(scheduler, 'await _markReconciled(fp);'), 2,
          reason: 'both the throttled branch and the full rebuild stamp the '
              'reconcile — otherwise every pass after a date rollover would '
              'redo the whole queue');
    });

    test('the throttle is keyed to the fingerprint, so a change is never late',
        () {
      expect(
          scheduler.contains(
              'if (stamp.substring(sep + 1) != fingerprint) return true;'),
          isTrue);
      expect(scheduler.contains('return age < 0 || age >= reconcileInterval.inMilliseconds;'),
          isTrue,
          reason: 'a stamp in the future (a clock correction) counts as due');
      expect(scheduler.contains('_scheduleFingerprint(AppSettings s)'), isTrue);
      expect(scheduler.contains('_todayKey(s.timezone),'), isTrue,
          reason: 'the calendar date is inside the fingerprint, so the first '
              'pass of every day always rebuilds no matter what the stamp says');
      expect(scheduler.contains('s.highLatitudeRule.index,'), isTrue,
          reason: 'a prayer-time input must flip the fingerprint (Phase-6 '
              'invariant) — that is what makes skipping the reconcile safe');
      expect(scheduler.contains('s.elevationCorrection,'), isTrue);
      expect(scheduler.contains('s.iqamahOffsetDhuhr,'), isTrue);
    });
  });

  group('R5 a foreground app is not asked to rebuild twice', () {
    test('the marker exists and the activity writes it', () async {
      final liveness =
          await readSource('android/app/src/main/kotlin/com/islamic/tawheeed/core/AppLiveness.kt');
      expect(liveness.contains('fun markForeground(context: Context)'), isTrue);
      expect(liveness.contains('fun markBackground(context: Context)'), isTrue);
      expect(liveness.contains('fun isForegroundNow(context: Context'), isTrue);
      expect(liveness.contains('const val LIVENESS_MS = 4_000L'), isTrue,
          reason: 'a hard kill leaves the stamp behind, so it must expire on '
              'its own');

      final main = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/MainActivity.kt');
      expect(main.contains('AppLiveness.markForeground(applicationContext)'), isTrue);
      expect(main.contains('AppLiveness.markBackground(applicationContext)'), isTrue);
      expect(
          main.contains(
              'override fun onResume() {\n        super.onResume()\n        AppLiveness.markForeground(applicationContext)'),
          isTrue);
      expect(
          main.contains('override fun onStop() {\n        AppLiveness.markBackground(applicationContext)'),
          isTrue,
          reason: 'onStop, not onPause: a dialog keeps the app visible and its '
              'scheduler live');
    });

    test('the receivers stop stamping but keep re-arming', () async {
      final boot = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/core/BootReceiver.kt');
      expect(boot.contains('if (bootOnly && AppLiveness.isForegroundNow(context)) {'),
          isTrue,
          reason: 'only the plain boot-ish actions are suppressed — a clock or '
              'timezone correction genuinely moves every prayer time');
      expect(boot.contains('val bootOnly = action == Intent.ACTION_BOOT_COMPLETED'), isTrue);
      final bootOnlyChunk =
          boot.substring(boot.indexOf('val bootOnly = action'), boot.indexOf('if (bootOnly'));
      expect(bootOnlyChunk.contains('ACTION_TIMEZONE_CHANGED'), isFalse);
      expect(bootOnlyChunk.contains('ACTION_TIME_CHANGED'), isFalse);
      expect(bootOnlyChunk.contains('SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED'), isFalse);
      expect(boot.contains('putBoolean("needs_reschedule", true)'), isTrue,
          reason: 'the background case must stamp exactly as before');

      for (final src in [
        boot,
        await readSource(
            'android/app/src/main/kotlin/com/islamic/tawheeed/core/RolloverReceiver.kt')
      ]) {
        expect(src.contains('ExactAlarmHelper.rescheduleAllAfterBoot(context)'), isTrue,
            reason: 'nothing is unscheduled by this remedy');
        expect(src.contains('ExactReminderScheduler.rescheduleAllAfterBoot(context)'), isTrue);
        expect(src.contains('PrayerAlarmScheduler.scheduleDailyRollover('), isTrue);
      }

      final roll = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/core/RolloverReceiver.kt');
      expect(roll.contains('if (AppLiveness.isForegroundNow(context)) {'), isTrue);
      expect(roll.contains('putBoolean("needs_reschedule", true)'), isTrue);
    });
  });
}
