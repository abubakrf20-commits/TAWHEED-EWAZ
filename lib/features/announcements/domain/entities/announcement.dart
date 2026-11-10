import 'package:cloud_firestore/cloud_firestore.dart';

/// یک پیام اطلاع‌رسانی که مدیر برای همهٔ کاربران برنامه منتشر می‌کند.
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// پیام سنجاق‌شده بالای فهرست می‌ماند.
  final bool isPinned;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isPinned = false,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    return Announcement(
      id: id,
      title: (map['title'] as String?)?.trim() ?? '',
      body: (map['body'] as String?)?.trim() ?? '',
      createdAt: createdAt is DateTime
          ? createdAt
          : (createdAt is Timestamp ? createdAt.toDate() : DateTime.now()),
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }
}
