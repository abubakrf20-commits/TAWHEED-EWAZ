import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Device facts Dart cannot read by itself: the free bytes of the volume the
/// app lives on, and whether the active connection is Wi-Fi/ethernet.
///
/// Both answers are nullable and every failure degrades to `null` — callers
/// treat an unknown connection as "do not block" and an unknown free-space
/// reading as "do not print a number". A download must never be refused
/// because a platform call failed.
class DeviceStatusService {
  static const _channel = MethodChannel('com.tawheeed/storage');

  static Future<double?> freeSpaceMb() async {
    try {
      final mb = await _channel.invokeMethod<int>('freeSpaceMb');
      return mb?.toDouble();
    } catch (e) {
      AppLogger.warning('DeviceStatusService', 'free space unavailable: $e');
      return null;
    }
  }

  /// `true` on Wi-Fi/ethernet, `false` on mobile data, `null` when the current
  /// transport cannot be determined (no network, VPN, a failed channel).
  static Future<bool?> isOnWifi() async {
    try {
      return await _channel.invokeMethod<bool>('isOnWifi');
    } catch (e) {
      AppLogger.warning('DeviceStatusService', 'network state unavailable: $e');
      return null;
    }
  }
}
