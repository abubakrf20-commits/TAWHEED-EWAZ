import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState renders icon and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.search_off,
            message: 'نتیجه‌ای یافت نشد',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.text('نتیجه‌ای یافت نشد'), findsOneWidget);
  });

  testWidgets('AppEmptyState renders subtitle when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.note,
            message: 'یادداشتی وجود ندارد',
            subtitle: 'روی دکمه + کلیک کنید',
          ),
        ),
      ),
    );
    expect(find.text('یادداشتی وجود ندارد'), findsOneWidget);
    expect(find.text('روی دکمه + کلیک کنید'), findsOneWidget);
  });

  testWidgets('AppEmptyState renders action widget when provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.book,
            message: 'کتابی وجود ندارد',
            action: ElevatedButton(
              onPressed: () {},
              child: const Text('افزودن کتاب'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('افزودن کتاب'), findsOneWidget);
  });
}
