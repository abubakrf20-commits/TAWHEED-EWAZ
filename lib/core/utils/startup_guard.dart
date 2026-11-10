import 'package:tawheeed/shared/utils/app_logger.dart';

/// Runs one cold-start init stage so an exception can never escape before
/// `runApp`.
///
/// Phase-1 audit fix: `NotificationService().init()` used to be awaited
/// unguarded outside `runZonedGuarded` — a plugin/tz/channel failure there
/// produced a permanent black screen. Every startup stage (Firebase,
/// notifications, Quran data) now goes through this helper: a failure logs
/// with its phase-specific message and degrades that feature only, sibling
/// stages in the same `Future.wait` keep running, and the next cold start
/// retries. The contract is locked by test/core/utils/startup_guard_test.dart
/// and test/main_startup_guard_test.dart.
Future<void> runStartupPhase(
  String failureMessage,
  Future<void> Function() body,
) async {
  try {
    await body();
  } catch (e, st) {
    AppLogger.error('Startup', '$failureMessage: $e', st);
  }
}
