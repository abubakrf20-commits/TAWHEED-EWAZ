import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/education/presentation/screens/study_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget app() {
    return const ProviderScope(
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: StudyScreen(),
        ),
      ),
    );
  }

  testWidgets('compact header shows today progress + stats and books section',
      (tester) async {
    setTallViewport(tester);
    SharedPreferences.setMockInitialValues({
      'plan_enabled': true,
      'plan_dailyTarget': 20,
      'plan_study_books': jsonEncode([
        {
          'id': 'b1',
          'name': 'روایت فتح',
          'dailyTarget': 10,
          'currentPage': 120,
          'totalPages': 200,
          'partInfo': 'بخش 1',
          'isActive': true,
        },
        {
          'id': 'b2',
          'name': 'رجال و رجال',
          'dailyTarget': 10,
          'currentPage': 50,
          'totalPages': 100,
          'partInfo': '',
          'isActive': true,
        },
      ]),
    });

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Header card: date row + progress + mini stats.
    expect(find.text('مطالعه آزاد'), findsOneWidget);
    expect(find.text('20 صفحه باقی‌مانده'), findsOneWidget);
    expect(find.text('کتاب فعال'), findsOneWidget);
    expect(find.text('صفحه امروز'), findsOneWidget);
    // Books section.
    expect(find.text('کتاب‌های من'), findsOneWidget);
    expect(find.text('روایت فتح'), findsOneWidget);
    expect(find.text('رجال و رجال'), findsOneWidget);
  });

  testWidgets('empty plan still renders the compact header and empty state',
      (tester) async {
    setTallViewport(tester);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('مطالعه آزاد'), findsOneWidget);
    expect(find.text('همه کتاب‌ها تمام شدند'), findsOneWidget);
    expect(find.textContaining('با افزودن کتاب'), findsOneWidget);
  });
}
