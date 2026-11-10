import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/adhkar/presentation/widgets/azkar_list_widget.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      if (methodCall.method == 'setValue') {
        return true;
      }
      return null;
    },
  );

  testWidgets('AzkarListWidget renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AzkarListWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AzkarListWidget), findsOneWidget);
  });
}
