import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';

void main() {
  testWidgets('LoadingOverlay shows spinner and optional message',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingOverlay(message: 'لطفاً صبر کنید...'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('لطفاً صبر کنید...'), findsOneWidget);
  });

  testWidgets('LoadingOverlay shows child behind overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingOverlay(
            message: 'در حال ذخیره...',
            child: Text('محتوای پشت'),
          ),
        ),
      ),
    );
    expect(find.text('در حال ذخیره...'), findsOneWidget);
    expect(find.text('محتوای پشت'), findsOneWidget);
  });

  testWidgets('LoadingOverlay hides message when not provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingOverlay(),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
