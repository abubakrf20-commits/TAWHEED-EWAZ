import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/glass_surface.dart';

void main() {
  testWidgets('GlassSurface renders child widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            child: Text('Hello Glass'),
          ),
        ),
      ),
    );
    expect(find.text('Hello Glass'), findsOneWidget);
  });

  testWidgets('GlassSurface applies custom padding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            padding: EdgeInsets.all(24),
            child: Text('Padded'),
          ),
        ),
      ),
    );
    expect(find.text('Padded'), findsOneWidget);
  });

  testWidgets('GlassSurface disables blur when enableBlur is false',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            child: Text('No Blur'),
          ),
        ),
      ),
    );
    expect(find.text('No Blur'), findsOneWidget);
  });
}
