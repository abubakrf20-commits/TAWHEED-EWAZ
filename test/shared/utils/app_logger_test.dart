import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheed_logger');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('buffers and flushes entries to tawheed_log.txt (no typo name)',
      () async {
    AppLogger.info('T', 'hello');
    AppLogger.warning('T', 'careful');
    await AppLogger.flush();
    final file = File('${tempDir.path}/tawheed_log.txt');
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('hello'));
    expect(content, contains('careful'));
    expect(await File('${tempDir.path}/trayheed_log.txt').exists(), isFalse);
  });

  test('scrubs emails and long digit runs', () async {
    AppLogger.info('T', 'contact me@example.com or 09123456789 now');
    await AppLogger.flush();
    final content =
        await File('${tempDir.path}/tawheed_log.txt').readAsString();
    expect(content, contains('[email]'));
    expect(content, contains('[digits]'));
    expect(content, isNot(contains('me@example.com')));
    expect(content, isNot(contains('09123456789')));
  });

  test('migrates the legacy typo log file once', () async {
    final legacy = File('${tempDir.path}/trayheed_log.txt');
    await legacy.writeAsString('[old] line\n', flush: true);
    AppLogger.info('T', 'new');
    await AppLogger.flush();
    expect(await legacy.exists(), isFalse);
    final content =
        await File('${tempDir.path}/tawheed_log.txt').readAsString();
    expect(content, contains('[old] line'));
    expect(content, contains('new'));
  });
}
