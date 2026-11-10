import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_title_page.dart';

/// صفحهٔ عنوان — برگِ نخستِ هر کتاب چاپی: نام کتاب، گردآورنده، موضوع و
/// شمار جلدها. نباید شمارهٔ صفحه داشته باشد (نشانگی نیست) و برگ سفیدِ
/// پشتش هم باید بی‌نقش بماند.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    int volumes = 0,
    String title = 'اللؤلؤ والمرجان',
    String author = 'جمع: صالح أحمد الشامي',
    String category = 'حدیث',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BookTitlePage(
          title: title,
          author: author,
          category: category,
          ink: const Color(0xFF2C2C2C),
          fontFamily: 'Vazirmatn',
          volumes: volumes,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('the title page prints name, compiler and subject',
      (tester) async {
    await pump(tester);
    expect(find.text('اللؤلؤ والمرجان'), findsOneWidget);
    expect(find.text('جمع: صالح أحمد الشامي'), findsOneWidget);
    expect(find.text('حدیث'), findsOneWidget);
    // A display sheet carries no folio — it must not read as a numbered page.
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('جلد'), findsNothing);
  });

  testWidgets('a multi-volume edition says how many volumes it has',
      (tester) async {
    await pump(tester, volumes: 3);
    expect(find.textContaining('جلد'), findsOneWidget);
  });

  testWidgets('the blank leaf carries nothing but paper', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BookBlankSheet()));
    expect(find.byType(BookBlankSheet), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}