import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/flat_tabs.dart';
import 'package:tawheeed/core/design_system/components/remembered_tabs.dart';

/// The widget under test, wrapped in the same chrome a section page uses.
Widget _page({int length = 3}) => MaterialApp(
      home: RememberedTabs(
        id: 'probe',
        length: length,
        child: Scaffold(
          appBar: AppBar(
            bottom: FlatTabs(tabs: [for (var i = 0; i < length; i++) 'تب $i']),
          ),
          body: TabBarView(
            children: [for (var i = 0; i < length; i++) Text('بدنه $i')],
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on tab 1 when nothing is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.text('بدنه 0'), findsOneWidget);
    expect(find.text('بدنه 1'), findsNothing);
  });

  testWidgets('reopens on the tab the reader left', (tester) async {
    SharedPreferences.setMockInitialValues({'section_tab_probe': 2});
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.text('بدنه 2'), findsOneWidget);
    expect(find.text('بدنه 0'), findsNothing);
  });

  testWidgets('writes the tab it is moved to', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('تب 1'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(RememberedTabs.keyFor('probe')), 1);
  });

  testWidgets('a stored tab that no longer exists is clamped, not trusted',
      (tester) async {
    // The strip was shortened since the last visit — index 5 of 3.
    SharedPreferences.setMockInitialValues({'section_tab_probe': 5});
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.text('بدنه 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each section keeps its own tab', (tester) async {
    SharedPreferences.setMockInitialValues({'section_tab_other': 2});
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    // Another section's stored index must not leak into this one.
    expect(find.text('بدنه 0'), findsOneWidget);
  });
}
