import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A-01: the native channel manager re-created reminder channels that the Dart
/// side had renamed or dropped, so Android settings showed two entries per
/// topic (`daily_reminders` next to `daily_reminders_v3`) and the user could
/// silence the wrong one. Only the two channels native code actually posts on
/// may be created; every retired ID must be deleted instead.
void main() {
  final kotlin = File(
      'android/app/src/main/kotlin/com/islamic/tawheeed/core/NotificationChannelManager.kt');
  final dart = File('lib/shared/services/notification_service.dart');

  String read(File f) {
    expect(f.existsSync(), isTrue,
        reason: 'run from the project root so ${f.path} resolves');
    return f.readAsStringSync();
  }

  String stripKotlinComments(String src) {
    final noBlocks = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    return noBlocks
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'//.*'), ''))
        .join('\n');
  }

  const createdNative = ['adhan_playback', 'general'];
  const retiredNative = ['prayer_reminders', 'daily_azkar', 'silent_mode'];
  const retiredByDart = [
    'daily_reminders',
    'quran_reminder',
    'custom_reminders',
    'azkar_reminder',
    'azkar_reminder_v2',
    'islamic_events',
    'islamic_events_v2',
    'daily_reminders_v2',
    'quran_reminder_v2',
    'khatm_reminder',
    'khatm_reminder_v2',
    'friday_reminder',
    'friday_reminder_v2',
    'prayer_times',
  ];

  test('native manager creates only the channels native code posts on', () {
    final src = stripKotlinComments(read(kotlin));

    final start = src.indexOf('val channels = listOf(');
    final end = src.indexOf('channels.forEach');
    expect(start, isNonNegative, reason: 'channel list block must still exist');
    expect(end, greaterThan(start));
    final block = src.substring(start, end);

    final constants = <String, String>{
      for (final m in RegExp(r'const val (CH_[A-Z_]+) = "([a-z0-9_]+)"')
          .allMatches(src))
        m.group(1)!: m.group(2)!,
    };
    final ids = RegExp(r'NotificationChannel\(\s*(CH_[A-Z_]+)')
        .allMatches(block)
        .map((m) => constants[m.group(1)!]!)
        .toSet();
    expect(ids, unorderedEquals(createdNative),
        reason: 'creating any other channel resurrects a dead entry in the '
            'Android notification settings');

    for (final id in [...retiredNative, ...retiredByDart]) {
      expect(ids, isNot(contains(id)),
          reason: '$id must be deleted, never re-created');
    }
  });

  test('native manager deletes every retired channel id', () {
    final src = stripKotlinComments(read(kotlin));

    final start = src.indexOf('LEGACY_CHANNEL_IDS = listOf(');
    expect(start, isNonNegative);
    final end = src.indexOf(')', src.indexOf('"prayer_times"', start));
    final block = src.substring(start, end);

    for (final id in retiredNative) {
      expect(block, contains('"$id"'),
          reason: 'the native manager must clean up $id from old installs');
    }
    for (final id in retiredByDart) {
      expect(block, contains('"$id"'));
    }
  });

  test('Dart deletes the retired native channels too', () {
    final src = read(dart);

    final start = src.indexOf('const legacy = <String>[');
    expect(start, isNonNegative, reason: 'Dart legacy deletion list exists');
    final end = src.indexOf('];', start);
    final block = src.substring(start, end);

    for (final id in retiredNative) {
      expect(block, contains("'$id'"),
          reason: 'Dart must also clean up $id (double cover with native)');
    }
    expect(src, contains('deleteNotificationChannel(channelId: id)'),
        reason: 'the legacy list is only useful while it is actually applied');
  });

  test('no channel id is both created and deleted by Dart', () {
    final src = read(dart);

    final channelsStart = src.indexOf('const channels = [');
    final channelsEnd = src.indexOf('];', channelsStart);
    final channelsBlock = src.substring(channelsStart, channelsEnd);
    final legacyStart = src.indexOf('const legacy = <String>[');
    final legacyEnd = src.indexOf('];', legacyStart);
    final legacyBlock = src.substring(legacyStart, legacyEnd);

    final created = RegExp(r"AndroidNotificationChannel\(\s*'([a-z0-9_]+)'")
        .allMatches(channelsBlock)
        .map((m) => m.group(1)!)
        .toSet();
    final legacyIds = RegExp(r"'([a-z0-9_]+)'")
        .allMatches(legacyBlock)
        .map((m) => m.group(1)!)
        .toSet();
    expect(created.intersection(legacyIds), isEmpty,
        reason: 'a channel that is deleted and created in the same pass fights '
            'itself and the deletion wins only by luck');
  });
}
