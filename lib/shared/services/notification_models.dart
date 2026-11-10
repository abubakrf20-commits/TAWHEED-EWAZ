part of 'notification_service.dart';

/// One natively armed reminder as reported by
/// [NotificationService.armedReminders].
class NativeReminderInfo {
  const NativeReminderInfo({
    required this.id,
    required this.fireInMinutes,
    this.repeatDaily = false,
    this.title = '',
    this.channelId = '',
    this.payload = '',
  });

  final int id;

  /// Whole minutes until this arming's current occurrence fires (native
  /// repeating reminders carry the *next* occurrence in `trigger`).
  final int fireInMinutes;
  final bool repeatDaily;
  final String title;
  final String channelId;
  final String payload;

  factory NativeReminderInfo.fromJson(Map<String, dynamic> json) =>
      NativeReminderInfo(
        id: (json['id'] as num).toInt(),
        fireInMinutes: (json['fireInMinutes'] as num?)?.toInt() ?? 0,
        repeatDaily: ((json['repeatDaily'] as num?)?.toInt() ?? -1) > 0,
        title: json['title'] as String? ?? '',
        channelId: json['channel'] as String? ?? '',
        payload: json['payload'] as String? ?? '',
      );
}

/// A single day's daily content (آیه/حدیث/دعا): the main Arabic/Persian text,
/// its translation and its source. Produces both the plain in-app body and the
/// styled HTML notification body.
class _DailyContent {
  const _DailyContent({
    required this.text,
    required this.trans,
    required this.ref,
  });

  final String text;
  final String trans;
  final String ref;

  String get plainBody => dailyContentBody(text: text, ref: ref, trans: trans);

  String get htmlBody =>
      dailyNotificationHtml(text: text, ref: ref, trans: trans);
}
