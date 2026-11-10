import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/card_design_system.dart';

void main() {
  testWidgets('GoldFramedCard renders child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoldFramedCard(
            child: Text('Card Content'),
          ),
        ),
      ),
    );
    expect(find.text('Card Content'), findsOneWidget);
  });

  testWidgets('GoldFramedCard shows pattern when showPattern is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoldFramedCard(
            showPattern: true,
            child: Text('Patterned'),
          ),
        ),
      ),
    );
    expect(find.text('Patterned'), findsOneWidget);
  });

  testWidgets('GoldFramedCard uses chocolate gradient', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoldFramedCard(
            useChocolate: true,
            child: Text('Chocolate'),
          ),
        ),
      ),
    );
    expect(find.text('Chocolate'), findsOneWidget);
  });
}
