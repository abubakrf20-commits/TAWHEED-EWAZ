import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/services/azan_playback_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tawheeed/azan');
  final invoked = <MethodCall>[];

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    invoked.clear();
  });

  group('playAzan with foreground service available', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isPlaying') return true;
        invoked.add(call);
        return null;
      });
    });

    test('plays the bundled asset without a Flutter asset path', () async {
      const settings = AppSettings(azanSound: 'kamel', azanVolume: 0.7);
      await AzanPlaybackService().playAzan(settings);
      final call = invoked.single;
      expect(call.method, 'playAzan');
      // The MP3s ship only as res/raw now; the native side resolves the sound
      // name, so no `source` path is sent for bundled adhans.
      expect(call.arguments.containsKey('source'), isFalse);
      expect(call.arguments['isAsset'], true);
      expect(call.arguments['sound'], 'kamel');
      expect(call.arguments['volume'], 0.7);
    });

    test('uses custom path with isAsset false', () async {
      const settings = AppSettings(
          azanSound: 'custom', customAzanPath: '/sdcard/azan/me.mp3');
      await AzanPlaybackService().playAzan(settings);
      final call = invoked.single;
      expect(call.arguments['source'], '/sdcard/azan/me.mp3');
      expect(call.arguments['isAsset'], false);
    });

    test('forwards unknown sound names; native falls back to kamel', () async {
      const settings = AppSettings(azanSound: 'nonsense');
      await AzanPlaybackService().playAzan(settings);
      final args = invoked.single.arguments as Map;
      expect(args['sound'], 'nonsense');
      expect(args['isAsset'], true);
      expect(args.containsKey('source'), isFalse);
    });
  });

  group('playAzan without foreground service', () {
    test('does not throw when the platform channel is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });
      const settings = AppSettings();
      await AzanPlaybackService().playAzan(settings); // must not throw
      expect(invoked, isEmpty);
    });
  });

  test('stop invokes the platform channel and does not throw', () async {
    var stopped = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stopAzan') {
        stopped = true;
        return null;
      }
      throw PlatformException(code: 'unavailable');
    });
    await AzanPlaybackService().stop();
    expect(stopped, isTrue);
  });
}
