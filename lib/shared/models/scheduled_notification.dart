class ScheduledNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String? payload;

  const ScheduledNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
  });
}
