import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';

void main() {
  group('BookPagination — نشانگر صفحه چاپی (N/M)', () {
    test('برش بر اساس (1/458) --- و شمارهگذاری صحیح', () {
      final content = [
        'کتاب نمونه — مقدمه',
        'متن صفحه ۱ (1/458) --- متن صفحه ۲',
        '(2/458) --- متن صفحه ۳',
        '(3/458) --- متن پایان',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.length, 4);
      expect(pages[0].printNo, isNull); // مقدمه
      expect(pages[1].printNo, 1);
      expect(pages[1].printTotal, 458);
      expect(pages[2].printNo, 2);
      expect(pages[3].printNo, 3);
      expect(pages[1].text.contains('متن صفحه ۲'), isTrue);
      expect(pages[3].text, contains('متن پایان'));
    });

    test('سربرگ «باب» از ابتدای صفحه تشخیص داده میشود', () {
      final content = [
        '(1/458) --- بابُ الطَّهَارَةِ: دربارهٔ وضو',
        '(2/458) --- ادامهٔ مطلب',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.first.heading, contains('باب'));
      expect(pages[1].heading, isNull);
      expect(pages.first.label, contains('بابُ الطَّهَارَةِ'));
    });

    test('سربرگهای فارسی «کتاب/فصل/مقدمة» نیز تشخیص داده میشوند', () {
      final content = [
        '(1/200) كتاب الطهارة مترجم',
        '(2/200) فصل في الوضوء',
        '(3/200) متن عادی بدون سربرگ',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages[0].heading, contains('كتاب'));
      expect(pages[1].heading, contains('فصل'));
      expect(pages[2].heading, isNull);
    });

    test('بدون نشانگر (N/M) به حالت کاراکتری برمیگردد', () {
      final content = [
        'سیب ' * 300,
        'پرتقال ' * 300,
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.length, greaterThanOrEqualTo(2));
      expect(pages.first.printNo, isNull);
      expect(pages.first.text, isNotEmpty);
    });

    test('محتوی خالی → خالی', () {
      expect(BookPagination.paginate(const []), isEmpty);
    });
  });

  group('BookPagination — مرز جلدها (انتخابگر جلد)', () {
    test('بازشماری نشانگر، مرز جلد را نشان می‌دهد', () {
      // نشانگر، پایانِ بلوک خودش است: وقتی X دوباره به ۱ برمی‌گردد، آن
      // نشانگر نخستین نشانگرِ جلد تازه است و chunk پیش از آن (ساخته‌شده با
      // نشانگرِ b-1) اولین صفحهٔ جلد تازه است.
      final content = [
        'پیش‌گفتار کتاب',
        '(1/600) --- یک',
        '(2/600) --- دو',
        '(1/620) --- سه',
        '(2/620) --- چهار',
      ];
      final pages = BookPagination.paginate(content, volumes: 2);
      expect(pages.length, 5);
      expect(BookPagination.volumeStartsOf(pages), [0, 2]);
      expect(pages[1].volume, 0);
      expect(pages[2].volume, 1);
    });

    test('پرش شمارهٔ صفحهٔ چاپی وقتی بازشماری نیست مرز جلد است', () {
      // اینجا X هرگز بازشماری نمی‌شود؛ نشانه، پرش شمارهٔ چاپی است:
      // ۴۰۰ و ۳۹۰ در جلد اول‌اند و ۴۰ یعنی شماره از نو شروع شده.
      final content = [
        'پیش‌گفتار 400',
        '(5/400) --- یک 390',
        '(6/400) --- دو 40',
        '(7/400) --- سه',
      ];
      final pages = BookPagination.paginate(content, volumes: 2);
      expect(BookPagination.volumeStartsOf(pages), [0, 2]);
      expect(pages.last.volume, 1);
    });

    test('نشانگرهای پرشیِ بی‌ربط به شمار جلدها نمی‌خورند → تقسیم متناسب', () {
      // دو بازشماری برای دو جلد کافی نیست (۲ ≠ ۱)؛ مرز قابل‌اتکا نیست، پس
      // صفحه‌ها متناسب تقسیم می‌شوند — بهتر از یک مرز دروغین.
      final content = [
        'پیش‌گفتار',
        '(2/100) --- یک',
        '(1/100) --- دو',
        '(2/100) --- سه',
        '(1/100) --- چهار',
      ];
      final pages = BookPagination.paginate(content, volumes: 2);
      expect(pages.length, 5);
      expect(BookPagination.volumeStartsOf(pages), [0, 3]);
    });

    test('کتابِ بدون نشانگر با جداکنندهٔ --- هم جلد می‌گیرد', () {
      final filler = 'سیاست ' * 120;
      final pages = BookPagination.paginate([
        filler,
        '---',
        filler,
        '---',
        filler,
        '---',
        filler,
      ], volumes: 2);
      expect(pages.length, 4);
      expect(BookPagination.volumeStartsOf(pages), [0, 2]);
      expect(pages.first.volume, 0);
      expect(pages.last.volume, 1);
    });

    test('تک‌جلدی برچسب جلد نمی‌گیرد', () {
      final pages = BookPagination.paginate(
        ['مقدمه', '(1/458) --- صفحهٔ نخست'],
      );
      expect(pages.every((p) => p.volume == 0), isTrue);
      expect(BookPagination.volumeStartsOf(pages), [0]);
    });

    test('جلدها شمارش می‌شوند نه متناسب‌سازی دوباره', () {
      final content = [
        'الف',
        '(1/10) --- ب',
        '(2/10) --- ج',
        '(1/10) --- د',
        '(2/10) --- ه',
        '(1/10) --- و',
      ];
      final pages = BookPagination.paginate(content, volumes: 3);
      // بازشماری‌ها در نشانگرهای ۳ و ۵ → دو مرز → سه جلد.
      expect(BookPagination.volumeStartsOf(pages).length, 3);
      expect(pages.last.volume, 2);
    });
  });

  group('BookPagination — پانوشت هر صفحه فقط پای خودش', () {
    test('بلوک پانوشت از تنِ صفحه بریده و همان‌جا می‌ماند', () {
      final content = [
        'متن صفحهٔ یک (1/100) --- متن صفحهٔ دو (1) __________ (1) - پانوشتِ صفحهٔ دو. (2) - پانوشت دومِ صفحهٔ دو.',
        '(2/100) --- متن صفحهٔ سه',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.length, 3);
      final page = pages[1];
      expect(page.printNo, 1);
      expect(page.notes, {
        '1': 'پانوشتِ صفحهٔ دو.',
        '2': 'پانوشت دومِ صفحهٔ دو.',
      });
      // بلوک در تنِ صفحه نمانده — وگرنه خواننده آن را در پای صفحه می‌دید.
      expect(page.text, isNot(contains('پانوشتِ صفحهٔ دو.')));
      expect(page.text, isNot(contains('____')));
      // نشانگر ارجاعِ خودِ تن می‌ماند تا با پانوشت جفت شود.
      expect(page.text, contains('(1)'));
    });

    test('صفحهٔ دیگر همان پانوشت را چاپ نمی‌کند', () {
      // دقیقاً همان گزارش کاربر: پانوشتِ صفحهٔ اول در بقیهٔ صفحه‌ها تکرار
      // می‌شد. پانوشت‌ها اکنون سهمیه‌بندی‌شده‌اند، نه یک نگاشتِ کل‌جلدی.
      final content = [
        '(1/100) --- متن پایه (1) __________ (1) - پانوشتِ یکم.',
        '(2/100) --- متن دوم (1)',
        '(3/100) --- متن سوم (1)',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.map((p) => p.printNo), [1, 2, 3]);
      expect(pages[0].notes.keys, ['1']);
      expect(pages[1].notes, isEmpty);
      expect(pages[2].notes, isEmpty);
    });

    test('ارجاعِ چاپی N/M در متن، صفحه نمی‌سازد', () {
      // منابع حدیثی در پانوشت به `(2/592)` ارجاع می‌دهند — همان شکلِ
      // نشانگرِ صفحه. پیش‌تر هر کدام صفحه‌ای تکه‌تکه می‌ساخت.
      final content = [
        '(1/100) --- متن با ارجاع (2/592) و ادامه',
        '(2/100) --- متن دوم',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.length, 2);
      expect(pages.map((p) => p.printNo), [1, 2]);
      expect(pages[0].text, contains('(2/592)'));
    });

    test('بدون هیچ جداکننده‌ای همهٔ نشانگرها مرز می‌مانند', () {
      // سبکِ بدون `---` نباید از دست برود: اگر پالایش را بدون این بازگشت
      // اجرا کنیم، کتاب به تقسیم کاراکتری می‌افتد.
      final content = [
        '(1/200) كتاب الطهارة',
        '(2/200) فصل في الوضوء',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages.length, 2);
      expect(pages[0].printNo, 1);
      expect(pages[1].printNo, 2);
    });

    test('نگاشتِ کل‌جلدی فقط برای شناسهٔ بی‌ابهام به کار می‌رود', () {
      final content = [
        '(1/9) --- متن یک (7) ',
        '(2/9) --- متن دو (8) ',
        '(3/9) --- متن سه (7) ',
      ];
      final pages = BookPagination.paginate(
        content,
        legacyNotes: {'7': 'پانوشت هفت', '8': 'پانوشت هشت'},
      );
      // ۸ فقط در یک صفحه آمده → همان‌جا چاپ می‌شود.
      expect(pages[1].notes, {'8': 'پانوشت هشت'});
      // ۷ در دو صفحه آمده → حدس زدنش پانوشتِ اشتباه است.
      expect(pages[0].notes, isEmpty);
      expect(pages[2].notes, isEmpty);
    });

    test('نگاشتِ کل‌جلدی شناسه‌ای را که در متن نیست نمی‌چسباند', () {
      final pages = BookPagination.paginate(
        ['متن بدون ارجاع'],
        legacyNotes: {'5': 'پانوشت پنج'},
      );
      expect(pages.single.notes, isEmpty);
    });

    test('بلوکِ قلابی هم پانوشت است', () {
      // نسخه‌هایی پانوشت را در قلاب می‌نویسند: `____ [1] متن [2] متن`.
      final content = [
        '(1/100) --- متن پایه [1] __________ [1] پانوشت قلابی یک. [2] پانوشت قلابی دو.',
        '(2/100) --- متن دوم [1]',
      ];
      final pages = BookPagination.paginate(content);
      expect(pages[0].notes, {
        '1': 'پانوشت قلابی یک.',
        '2': 'پانوشت قلابی دو.',
      });
      expect(pages[1].notes, isEmpty);
    });

    test('خطِ جداکنندهٔ تهی به خواننده نشان داده نمی‌شود', () {
      final pages = BookPagination.paginate(
        ['(1/100) --- متن یک __________ (2/100) --- متن دو'],
      );
      // نشانگرهای صفحه هر دو از فیلترِ راستین رد شده‌اند (جداکننده ندارند)؛
      // مهم اینکه هیچ صفحه‌ای خطِ زیر را چاپ نکند.
      for (final page in pages) {
        expect(page.text, isNot(contains('___')));
      }
    });

    test('صفحه‌ای که تنها پانوشت داشت حذف و ایندکس‌ها بازشماری می‌شوند', () {
      final content = [
        '(1/100) --- متن یک',
        '(2/100) --- __________ (1) - تنها پانوشت این صفحه.',
        '(3/100) --- متن سه',
      ];
      final pages = BookPagination.paginate(content);
      // صفحهٔ دوم پس از برش تهی می‌شد؛ به‌جای برگِ سفید کنار گذاشته شد.
      expect(pages.map((p) => p.printNo), [1, 3]);
      expect(pages.map((p) => p.index), [0, 1]);
    });
  });

  group('BookPagination — نقشهٔ ایندکسِ قدیم', () {
    test('شماره‌های چاپیِ چیدمانِ پیش از پالایش را می‌دهد', () {
      final content = [
        'مقدمه',
        '(1/100) --- یک',
        '(5/9) دروغین --- دو',
        '(2/100) --- سه',
      ];
      // مقدمه، سپس هر نشانگر (حتی ساختگی) یک صفحه.
      expect(BookPagination.legacyPrintNos(content), [null, 1, 5, 2]);
      // چیدمانِ تازه همان نشانگر ساختگی را دور می‌ریزد.
      final pages = BookPagination.paginate(content);
      expect(pages.map((p) => p.printNo), [null, 1, 2]);
    });
  });
}
