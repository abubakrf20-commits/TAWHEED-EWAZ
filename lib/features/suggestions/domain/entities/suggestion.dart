import 'package:cloud_firestore/cloud_firestore.dart';

/// دسته‌بندی پیام‌های «ارسال پیشنهاد».
///
/// هر دسته یک [code] پایدار دارد که در Firestore ذخیره می‌شود؛ تغییر برچسب
/// فارسی در نسخه‌های بعدی روی داده‌های ذخیره‌شده اثری ندارد.
enum SuggestionCategory {
  suggestion('suggestion', 'پیشنهاد'),
  complaint('complaint', 'انتقاد'),
  bug('bug', 'گزارش مشکل'),
  other('other', 'سایر');

  const SuggestionCategory(this.code, this.persian);

  final String code;
  final String persian;

  static SuggestionCategory fromCode(String? code) {
    if (code == null || code.isEmpty) return SuggestionCategory.other;
    return SuggestionCategory.values.firstWhere(
      (c) => c.code == code,
      orElse: () => SuggestionCategory.other,
    );
  }
}

/// یک پیشنهاد/انتقاد ارسال‌شده توسط کاربر.
class Suggestion {
  final String id;
  final String text;
  final SuggestionCategory category;
  final String deviceTag;
  final DateTime createdAt;

  /// نام اختیاری فرستنده. کاربر می‌تواند بدون نام هم پیام بفرستد.
  final String name;

  /// پاسخ مدیر؛ خالی یعنی هنوز پاسخی داده نشده است.
  final String reply;

  final DateTime? repliedAt;

  /// آیا این پیشنهاد به‌صورت عمومی منتشر شده است؟
  final bool isPublic;

  const Suggestion({
    required this.id,
    required this.text,
    required this.category,
    required this.deviceTag,
    required this.createdAt,
    this.name = '',
    this.reply = '',
    this.repliedAt,
    this.isPublic = false,
  });

  bool get hasReply => reply.trim().isNotEmpty;

  /// نام نمایشی فرستنده؛ وقتی نامی نداده، دستگاه نشان داده می‌شود.
  String get senderLabel =>
      name.trim().isNotEmpty ? name.trim() : 'کاربر $_shortTag';

  String get _shortTag => deviceTag.isEmpty
      ? '—'
      : deviceTag.substring(0, deviceTag.length.clamp(0, 4));

  factory Suggestion.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    final repliedAt = map['repliedAt'];
    return Suggestion(
      id: id,
      text: (map['text'] as String?)?.trim() ?? '',
      category: SuggestionCategory.fromCode(map['category'] as String?),
      deviceTag: (map['deviceTag'] as String?) ?? '',
      createdAt: createdAt is DateTime
          ? createdAt
          : (createdAt is Timestamp ? createdAt.toDate() : DateTime.now()),
      name: (map['name'] as String?)?.trim() ?? '',
      reply: (map['reply'] as String?)?.trim() ?? '',
      repliedAt: repliedAt is DateTime
          ? repliedAt
          : (repliedAt is Timestamp ? repliedAt.toDate() : null),
      isPublic: map['isPublic'] as bool? ?? false,
    );
  }
}
