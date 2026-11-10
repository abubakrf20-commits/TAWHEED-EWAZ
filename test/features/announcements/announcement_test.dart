import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/announcements/domain/entities/announcement.dart';

void main() {
  group('Announcement.fromMap', () {
    test('فیلدهای کامل', () {
      final time = DateTime.utc(2026, 3, 4, 11);
      final a = Announcement.fromMap('a1', {
        'title': '  بروزرسانی نسخهٔ ۱.۷  ',
        'body': 'چند مورد جدید اضافه شد.',
        'createdAt': Timestamp.fromDate(time),
        'isPinned': true,
      });
      expect(a.id, 'a1');
      expect(a.title, 'بروزرسانی نسخهٔ ۱.۷');
      expect(a.body, 'چند مورد جدید اضافه شد.');
      expect(a.createdAt.toUtc(), time);
      expect(a.isPinned, isTrue);
    });

    test('createdAt از نوع DateTime هم پذیرفته می‌شود', () {
      final time = DateTime.utc(2026, 1, 2);
      final a = Announcement.fromMap('a2', {
        'title': 'عنوان',
        'body': 'متن',
        'createdAt': time,
      });
      expect(a.createdAt.toUtc(), time);
    });

    test('فیلدهای جاافتاده کوئل نمی‌دهند و پیش‌فرض می‌گیرند', () {
      final a = Announcement.fromMap('a3', {'title': 'فقط عنوان'});
      expect(a.id, 'a3');
      expect(a.title, 'فقط عنوان');
      expect(a.body, '');
      expect(a.isPinned, isFalse);
      expect(a.createdAt, isA<DateTime>());
    });

    test('سند کاملاً خالی هم ساخته می‌شود', () {
      final a = Announcement.fromMap('a4', {});
      expect(a.title, '');
      expect(a.body, '');
      expect(a.isPinned, isFalse);
    });

    test('مقادیر پیش‌فرض روی خود entity', () {
      final a = Announcement(
        id: 'x',
        title: 'عنوان',
        body: 'متن',
        createdAt: DateTime(2026),
      );
      expect(a.isPinned, isFalse);
    });
  });
}
