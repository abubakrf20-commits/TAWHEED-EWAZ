import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/adhkar/presentation/screens/azkar_tasbih_tab.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart'
    show SwitchTile;
import '../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      return true;
    },
  );

  Future<void> openSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDao = MockTasbihDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tasbihDaoProvider.overrideWithValue(mockDao)],
        child: const MaterialApp(home: AzkarTasbihTab()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('تنظیمات اذکار و تسبیح'));
    await tester.pumpAndSettle();
  }

  testWidgets('settings sheet wears the home design rows', (tester) async {
    await openSheet(tester);
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    for (final title in [
      'لرزش هنگام کلیک',
      'صدای کلیک',
      'تسبیح سریع',
      'ریست خودکار روزانه',
      'چرخش خودکار ذکر',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
    // One kit switch row per setting (IconTile + SettingsSwitch).
    expect(
      find.descendant(of: sheet, matching: find.byType(SwitchTile)),
      findsNWidgets(5),
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(SettingsSwitch)),
      findsNWidgets(5),
    );
    // No bespoke duotone tiles or raw material switches anymore.
    expect(
      find.descendant(of: sheet, matching: find.byType(DuotoneIconTile)),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(Switch)),
      findsNothing,
    );
    // Shared section header, not a bare title.
    expect(
      find.descendant(
          of: sheet, matching: find.byType(SectionHeader)),
      findsOneWidget,
    );
  });
}
