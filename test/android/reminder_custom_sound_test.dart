import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the custom-sound plumbing for reminders and the adhan bake.
///
/// A picked audio file used to never sound at fire time: the native reminder
/// alarm always played the channel's fixed sound, the plugin path handed the
/// system a `file://` URI it cannot read, and an unusable custom azan baked
/// into an alarm silently degraded to the bundled default. Dart tests never
/// compile Kotlin, so the native half is pinned by source scan (the repo's
/// style for native invariants — see android_manifest_queries_test.dart).
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

void main() {
  group('reminder custom sound reaches the native alarm', () {
    test('the sound name is threaded to the native scheduler', () async {
      final service = await readSource(
          'lib/shared/services/notification_service.dart');
      expect(service.contains('String? nativeSound,'), isTrue,
          reason: 'scheduleExactReminder must accept the reminder sound');
      expect(service.contains('nativeSound: nativeSound'), isTrue,
          reason: 'the sound must travel into _scheduleNotification');
      expect(service.contains('String? soundOverride,'), isTrue,
          reason: '_scheduleNativeExactReminder must accept the override');
      expect(
          service.contains(
              "'sound': soundOverride ?? _nativeSoundForChannel(channelId)"),
          isTrue,
          reason: 'the native alarm must carry the override when present');
    });

    test('reminders forward custom files and phone tones to the native alarm',
        () async {
      final provider = await readSource(
          'lib/features/reminders/presentation/providers/reminder_provider.dart');
      expect(provider.contains('nativeSound: _nativeSound(r.soundName)'),
          isTrue,
          reason: 'every reminder schedule must forward its sound');
      expect(provider.contains("if (soundName.startsWith('custom:'))"),
          isTrue, reason: 'a custom file still travels as custom:<path>');
      expect(provider.contains('if (SoundChoice.isSystem(soundName))'),
          isTrue, reason: 'a phone tone must reach the native in-process player');
      expect(provider.contains('UriAndroidNotificationSound(Uri.file'), isFalse,
          reason: 'a file:// URI can never sound from the system process');
      expect(provider.contains('UriAndroidNotificationSound(systemUri)'), isTrue,
          reason: 'a system tone URI can be a notification sound');
    });

    test('phone tones are parsed into the native sound format', () async {
      final choice =
          await readSource('lib/shared/services/sound_choice.dart');
      expect(choice.contains('static String system(String kind, String uri)'),
          isTrue);
      expect(choice.contains("'system:\$kind:\$uri'"), isTrue,
          reason: 'the native receiver parses exactly this prefix');
    });

    test('the native receiver plays custom files in-process', () async {
      final receiver = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/core/ReminderReceiver.kt');
      expect(receiver.contains('customReminderFileOrNull'), isTrue,
          reason: 'custom sounds must resolve inside custom_sounds/');
      expect(receiver.contains('setSilent(true)'), isTrue,
          reason: 'the notification stays silent while the file plays');
      expect(receiver.contains('USAGE_NOTIFICATION'), isTrue,
          reason: 'the file honours the notification volume, not the alarm pin');
      expect(receiver.contains('private fun playCustomFile'), isTrue,
          reason: 'the in-process MediaPlayer path must exist');
      expect(receiver.contains('isSystemSound(soundName)'), isTrue,
          reason: 'phone tones take the same in-process path');
      expect(receiver.contains('ACTION_STOP_SOUND'), isTrue,
          reason: 'the notification offers a stop action for long sounds');
    });

    test('the resolver honours the reminder sounds directory', () async {
      final resolver = await readSource(
          'android/app/src/main/kotlin/com/islamic/tawheeed/core/AzanAudioResolver.kt');
      expect(resolver.contains('customReminderFileOrNull'), isTrue,
          reason: 'reminders need the same direct-child policy as the adhan');
      expect(resolver.contains('"custom_sounds"'), isTrue,
          reason: 'the reminder copy target must be the accepted directory');
    });
  });

  group('unusable custom azan never bakes silently', () {
    test('the bake resolves to an explicit kamel fallback', () async {
      final service = await readSource(
          'lib/shared/services/native_prayer_alarm_service.dart');
      expect(service.contains('bakeAlarmSound('), isTrue,
          reason: 'alarms must bake through the validating resolver');
      expect(service.contains("return (sound: 'kamel', customPath: '')"), isTrue,
          reason: 'a bad custom path must degrade to kamel explicitly');
    });
  });
}
