import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';

void main() {
  group('SuggestionCategory — نگاشت کد/برچسب', () {
    test('کدهای پشتیبان پایدار هستند', () {
      expect(SuggestionCategory.suggestion.code, 'suggestion');
      expect(SuggestionCategory.complaint.code, 'complaint');
      expect(SuggestionCategory.bug.code, 'bug');
      expect(SuggestionCategory.other.code, 'other');
    });

    test('برچسب فارسی دسته‌ها', () {
      expect(SuggestionCategory.suggestion.persian, 'پیشنهاد');
      expect(SuggestionCategory.complaint.persian, 'انتقاد');
      expect(SuggestionCategory.bug.persian, 'گزارش مشکل');
      expect(SuggestionCategory.other.persian, 'سایر');
    });

    test('fromCode مقدار ناشناخته را به «سایر» می‌برد', () {
      expect(SuggestionCategory.fromCode('suggestion'),
          SuggestionCategory.suggestion);
      expect(SuggestionCategory.fromCode(null), SuggestionCategory.other);
      expect(SuggestionCategory.fromCode('nonsense'), SuggestionCategory.other);
      expect(SuggestionCategory.fromCode(''), SuggestionCategory.other);
    });
  });

  group('Suggestion.fromMap', () {
    test('فیلدهای کامل', () {
      final time = DateTime.utc(2026, 1, 5, 12, 30);
      final s = Suggestion.fromMap('doc1', {
        'text': '  افزودن قفل  ',
        'category': 'bug',
        'deviceTag': 'aabbccdd',
        'createdAt': Timestamp.fromDate(time),
      });
      expect(s.id, 'doc1');
      expect(s.text, 'افزودن قفل');
      expect(s.category, SuggestionCategory.bug);
      expect(s.deviceTag, 'aabbccdd');
      expect(s.createdAt.toUtc(), time);
    });

    test('فیلدهای جاافتاده کوئل نمی‌دهند', () {
      final s = Suggestion.fromMap('doc2', {'text': 'سلام'});
      expect(s.id, 'doc2');
      expect(s.text, 'سلام');
      expect(s.category, SuggestionCategory.other);
      expect(s.deviceTag, '');
      expect(s.createdAt, isA<DateTime>());
      expect(s.name, '');
      expect(s.reply, '');
      expect(s.repliedAt, isNull);
      expect(s.isPublic, isFalse);
      expect(s.hasReply, isFalse);
    });
  });

  group('Suggestion — نام، پاسخ و انتشار عمومی', () {
    test('نام و پاسخ و پرچم عمومی خوانده می‌شوند', () {
      final time = DateTime.utc(2026, 2, 3, 9);
      final replyTime = DateTime.utc(2026, 2, 4, 10);
      final s = Suggestion.fromMap('doc3', {
        'text': 'افزودن ترجمه',
        'name': '  ابوبکر  ',
        'reply': '  انجام شد  ',
        'repliedAt': Timestamp.fromDate(replyTime),
        'createdAt': Timestamp.fromDate(time),
        'isPublic': true,
      });
      expect(s.name, 'ابوبکر');
      expect(s.reply, 'انجام شد');
      expect(s.hasReply, isTrue);
      expect(s.repliedAt!.toUtc(), replyTime);
      expect(s.isPublic, isTrue);
      expect(s.senderLabel, 'ابوبکر');
    });

    test('senderLabel بدون نام، برچسب دستگاه می‌سازد', () {
      final s = Suggestion.fromMap('doc4', {
        'text': 'بی‌نام',
        'deviceTag': 'aabbccdd11223344',
      });
      expect(s.senderLabel, 'کاربر aabb');
    });

    test('دستگاه خالی: برچسب عمومی می‌دهد و خطا نمی‌دهد', () {
      final s = Suggestion.fromMap('doc5', {'text': 'بدون دستگاه'});
      expect(s.senderLabel, 'کاربر —');
    });

    test('پاسخ فقط با فاصله، «بدون پاسخ» شمرده می‌شود', () {
      final s = Suggestion.fromMap('doc6', {'text': 'x', 'reply': '   '});
      expect(s.reply, '');
      expect(s.hasReply, isFalse);
    });

    test('مقادیر پیش‌فرض روی خود entity', () {
      final s = Suggestion(
        id: 'x',
        text: 'متن',
        category: SuggestionCategory.other,
        deviceTag: 'tag',
        createdAt: DateTime(2026),
      );
      expect(s.name, '');
      expect(s.reply, '');
      expect(s.isPublic, isFalse);
      expect(s.repliedAt, isNull);
    });
  });
}
