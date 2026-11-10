import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';

void main() {
  testWidgets('AmbientBackground renders child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AmbientBackground(
            child: Text('Hello'),
          ),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('AmbientBackground hides glow when includeGlow is false',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AmbientBackground(
            includeGlow: false,
            child: Text('No Glow'),
          ),
        ),
      ),
    );
    expect(find.text('No Glow'), findsOneWidget);
  });
}
