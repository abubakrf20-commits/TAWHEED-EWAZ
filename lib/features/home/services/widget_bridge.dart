import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';

class WidgetBridge {
  static const _channel = MethodChannel('com.tawheeed/widgets');

  Future<void> syncSnapshot(WidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod('syncWidget', snapshot.toMethodChannel());
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'syncWidget failed: $e');
    }
  }

  /// Lightweight tasbih-only update (zikr selection + count + target).
  Future<void> updateTasbihWidget({
    required String dhikr,
    required int count,
    required int target,
    required bool isActive,
    int? zikrIndex,
    String? zikrId,
  }) async {
    try {
      await _channel.invokeMethod('updateTasbihWidget', {
        'dhikr': dhikr,
        'count': count,
        'target': target,
        'isActive': isActive,
        if (zikrIndex != null) 'zikrIndex': zikrIndex,
        // Audit 8.15: index-based sync mis-targets after a reorder; the id
        // stays stable so the widget keeps binding to the right zikr.
        if (zikrId != null) 'zikrId': zikrId,
      });
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'updateTasbihWidget failed: $e');
    }
  }

  Future<Map<String, dynamic>> getTasbihData() async {
    try {
      final value =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getTasbihData');
      if (value == null) return <String, dynamic>{};
      return value.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      AppLogger.warning('widget_bridge', 'error: $e');
      return <String, dynamic>{};
    }
  }

  Future<bool> requestPinWidget({String widgetType = 'prayer'}) async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
      });
      return result ?? false;
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'requestPinWidget failed: $e');
      return false;
    }
  }

  /// Persists one widget's theme (palette id + opacity step) natively and
  /// re-renders every widget. `paletteId` may be `auto` (خودکار). [widget]
  /// selects the target (`prayer` / `tasbih`): per-widget keys only — the
  /// shared legacy keys stay untouched as the adoption source for widgets
  /// that have never saved their own choice.
  Future<void> setWidgetTheme({
    required String paletteId,
    required int opacityStep,
    required String widget,
  }) async {
    try {
      await _channel.invokeMethod('setWidgetTheme', {
        'paletteId': paletteId,
        'opacityStep': opacityStep,
        'widget': widget,
      });
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'setWidgetTheme failed: $e');
    }
  }

  /// Reads the natively persisted theme. Top-level `paletteId`/`opacityStep`
  /// are the shared keys (`paletteId` null / step -1 before the first save);
  /// the nested `prayer` / `tasbih` maps carry each widget's own keys in the
  /// same shape (-1 = not persisted).
  Future<Map<String, dynamic>> getWidgetTheme() async {
    try {
      final value =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getWidgetTheme');
      if (value == null) return <String, dynamic>{};
      return value.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'getWidgetTheme failed: $e');
      return <String, dynamic>{};
    }
  }

  /// Acks the widget's pending tasbih tap events up to [appliedSeq] — the
  /// native side prunes everything at or below it. The app persists its own
  /// applied seq first, so re-draining after a crash stays idempotent.
  Future<void> drainTasbihEvents(int appliedSeq) async {
    try {
      await _channel
          .invokeMethod('drainTasbihEvents', {'appliedSeq': appliedSeq});
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'drainTasbihEvents failed: $e');
    }
  }

  /// The «خواندم» taps the user made on the home-screen prayer widget:
  /// `{date: 'YYYY-MM-DD', indices: [0..4], clearedDate: 'YYYY-MM-DD',
  /// cleared: [0..4]}`. Empty when nothing was tapped.
  ///
  /// [indices] are ticks the user ADDED; [cleared] are ticks the user took
  /// BACK on the card. They carry their own date so a clear from yesterday can
  /// never reset a prayer on a day it does not belong to.
  Future<Map<String, dynamic>> getPrayerMarks() async {
    try {
      final value =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getPrayerMarks');
      if (value == null) return <String, dynamic>{};
      return value.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'getPrayerMarks failed: $e');
      return <String, dynamic>{};
    }
  }

  /// Acks [indices] for [date] so the widget stops re-reporting them. Only the
  /// indices the app actually wrote are sent — a tap landing between the read
  /// and this ack is left in place for the next pass.
  Future<void> drainPrayerMarks({
    required String date,
    required List<int> indices,
  }) async {
    if (date.isEmpty || indices.isEmpty) return;
    try {
      await _channel.invokeMethod('drainPrayerMarks', {
        'date': date,
        'indices': indices,
      });
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'drainPrayerMarks failed: $e');
    }
  }

  /// Acks the ticks the user took BACK on the card, once the tracker rows have
  /// been reset. Same contract as [drainPrayerMarks].
  Future<void> drainPrayerCleared({
    required String date,
    required List<int> indices,
  }) async {
    if (date.isEmpty || indices.isEmpty) return;
    try {
      await _channel.invokeMethod('drainPrayerCleared', {
        'date': date,
        'indices': indices,
      });
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'drainPrayerCleared failed: $e');
    }
  }

  /// Clears the home-screen widgets' mirrored worship state (today's tasbih
  /// daily total, per-zikr counts and the prayer «خواندم» marks) so an
  /// evaluation reset is not re-imported by the next widget→app sync. No-op if
  /// the channel is unavailable. See [WidgetSync.clearEvaluationState].
  Future<void> clearEvaluationState() async {
    try {
      await _channel.invokeMethod('clearEvaluationState');
    } catch (e) {
      AppLogger.warning('WidgetBridge', 'clearEvaluationState failed: $e');
    }
  }
}
