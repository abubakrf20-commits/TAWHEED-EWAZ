import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show SettingsSwitch;
import '../../../../core/database/mock_daos.dart';

/// TimePickerTile is a consumer widget (it follows the 12/24-hour setting), so
/// every case needs a scope backed by the mock settings repository.
Widget wrap(Widget w) {
  final repo = MockSettingsRepository()..setMockSettings(const AppSettings());
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWith((ref) async => repo)],
    child: MaterialApp(home: Scaffold(body: w)),
  );
}

void main() {
  testWidgets('SettingsCard renders children', (tester) async {
    await tester
        .pumpWidget(wrap(const SettingsCard(children: [Text('Content')])));
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('SwitchTile renders title and value', (tester) async {
    await tester.pumpWidget(wrap(SwitchTile(
      title: 'WiFi',
      icon: Icons.wifi,
      value: true,
      onChanged: (_) {},
    )));
    expect(find.text('WiFi'), findsOneWidget);
  });

  testWidgets('SwitchTile calls onChanged on tap', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(SwitchTile(
      title: 'Test',
      icon: Icons.wifi,
      value: false,
      onChanged: (v) => result = v,
    )));
    await tester.tap(find.byType(SettingsSwitch).last);
    expect(result, isTrue);
  });

  testWidgets('SelectTile renders title and value', (tester) async {
    await tester.pumpWidget(wrap(SelectTile(
      title: 'Lang',
      subtitle: 'English',
      icon: Icons.language,
      options: const ['en', 'ar'],
      selected: 'en',
      labelBuilder: (s) => s == 'en' ? 'English' : 'Arabic',
      onChanged: (_) {},
    )));
    expect(find.text('Lang'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('SettingsDivider renders', (tester) async {
    await tester.pumpWidget(wrap(const SettingsDivider()));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('TimePickerTile renders label and time', (tester) async {
    await tester.pumpWidget(wrap(TimePickerTile(
      label: 'Alarm',
      time: const TimeOfDay(hour: 6, minute: 30),
      onPicked: (_) {},
    )));
    expect(find.text('Alarm'), findsOneWidget);
  });

  testWidgets('CollapsibleSection expands and collapses', (tester) async {
    await tester.pumpWidget(wrap(const CollapsibleSection(
      title: 'Section',
      child: Text('Hidden'),
    )));
    await tester.tap(find.text('Section'));
    await tester.pump();
    expect(find.text('Hidden'), findsOneWidget);
  });
}
