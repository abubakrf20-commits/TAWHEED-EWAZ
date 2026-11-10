import 'package:tawheeed/features/home/services/widget_bridge.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Central widget synchronization service over the native method channel.
/// Widget appearance lives natively (palette + opacity via [setWidgetTheme]);
/// this class only moves data.
class WidgetSync {
  final WidgetBridge _bridge = WidgetBridge();

  Future<void> syncSnapshot(WidgetSnapshot snapshot) async {
    try {
      await _bridge.syncSnapshot(snapshot);
    } catch (e) {
      AppLogger.warning('WidgetSync', 'syncSnapshot failed: $e');
    }
  }

  /// Lightweight tasbih-only push to native widgets (no full snapshot):
  /// keeps the home-screen widget in lock-step with the app when the user
  /// switches the active zikr or counts inside the app.
  Future<void> updateTasbihWidget({
    required String dhikr,
    required int count,
    required int target,
    required bool isActive,
    int? zikrIndex,
    String? zikrId,
  }) async {
    try {
      await _bridge.updateTasbihWidget(
        dhikr: dhikr,
        count: count,
        target: target,
        isActive: isActive,
        zikrIndex: zikrIndex,
        zikrId: zikrId,
      );
    } catch (e) {
      AppLogger.warning('WidgetSync', 'updateTasbihWidget failed: $e');
    }
  }

  Future<Map<String, dynamic>> getTasbihData() async {
    try {
      return await _bridge.getTasbihData();
    } catch (e) {
      AppLogger.warning('WidgetSync', 'getTasbihData failed: $e');
      return {'dhikr': '', 'count': 0, 'target': 100};
    }
  }

  /// Persists one widget's theme (palette + opacity) natively and re-renders
  /// every widget. `paletteId` may be `auto` (خودکار); `widget` selects the
  /// target (`prayer` / `tasbih`) — per-widget keys only.
  Future<void> setWidgetTheme({
    required String paletteId,
    required int opacityStep,
    required String widget,
  }) async {
    try {
      await _bridge.setWidgetTheme(
        paletteId: paletteId,
        opacityStep: opacityStep,
        widget: widget,
      );
    } catch (e) {
      AppLogger.warning('WidgetSync', 'setWidgetTheme failed: $e');
    }
  }

  /// Reads the natively persisted theme (empty map before the first save).
  Future<Map<String, dynamic>> getWidgetTheme() async {
    try {
      return await _bridge.getWidgetTheme();
    } catch (e) {
      AppLogger.warning('WidgetSync', 'getWidgetTheme failed: $e');
      return <String, dynamic>{};
    }
  }

  /// Acks the widget's pending tasbih tap events up to [appliedSeq].
  Future<void> drainTasbihEvents(int appliedSeq) async {
    try {
      await _bridge.drainTasbihEvents(appliedSeq);
    } catch (e) {
      AppLogger.warning('WidgetSync', 'drainTasbihEvents failed: $e');
    }
  }

  /// The «خواندم» taps recorded on the prayer widget, `{date, indices}`.
  Future<Map<String, dynamic>> getPrayerMarks() => _bridge.getPrayerMarks();

  /// Acks the prayer-widget marks the app has already applied.
  Future<void> drainPrayerMarks({
    required String date,
    required List<int> indices,
  }) =>
      _bridge.drainPrayerMarks(date: date, indices: indices);

  /// Acks the ticks the user took back on the card, once the tracker rows have
  /// been reset.
  Future<void> drainPrayerCleared({
    required String date,
    required List<int> indices,
  }) =>
      _bridge.drainPrayerCleared(date: date, indices: indices);

  /// Clears the widgets' mirrored evaluation state after a reset so the next
  /// sync cannot re-import today's tasbih total, per-zikr counts or prayer
  /// marks. The native side drops the stale mirror; post-reset widget taps
  /// then accumulate from zero. No-op if the channel is unavailable.
  Future<void> clearEvaluationState() => _bridge.clearEvaluationState();
}
