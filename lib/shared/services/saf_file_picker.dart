import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class SAFFile {
  final String name;
  final List<int> bytes;
  const SAFFile({required this.name, required this.bytes});
}

class SAFFilePicker {
  static const _channel = MethodChannel('com.tawheeed/azan');

  static Future<SAFFile?> pickBackupFile() async {
    try {
      final result = await _channel.invokeMethod<Map>('pickBackupFile');
      if (result == null) return null;
      final name = result['name'] as String;
      final bytes = result['bytes'] as List<int>;
      return SAFFile(name: name, bytes: bytes);
    } on PlatformException catch (e) {
      AppLogger.warning('SAFFilePicker', 'Platform error: ${e.message}');
      rethrow;
    }
  }
}
