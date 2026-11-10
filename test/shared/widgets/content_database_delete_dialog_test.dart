import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

void main() {
  Future<bool?> openAndTap(WidgetTester tester, String button) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await confirmContentDatabaseDelete(context,
                      name: 'ریاض الصالحین');
                },
                child: const Text('باز کن'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('باز کن'));
    await tester.pumpAndSettle();
    expect(find.text('حذف «ریاض الصالحین»؟'), findsOneWidget);
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('confirming reports true', (tester) async {
    expect(await openAndTap(tester, 'حذف'), isTrue);
  });

  testWidgets('cancelling reports false', (tester) async {
    expect(await openAndTap(tester, 'انصراف'), isFalse);
  });
}
