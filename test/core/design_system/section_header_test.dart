import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

void main() {
  // The two header squeeze bugs, both guarded at a narrow width with a
  // trailing widget present — the configuration that rendered the home
  // headers empty (2026-10-12).
  Future<Size> pumpHeader(WidgetTester tester, String title,
      {String? count, Widget? trailing}) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: SectionHeader(title: title, count: count, trailing: trailing),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.getSize(find.text(title));
  }

  testWidgets('title keeps its intrinsic width with a trailing widget',
      (tester) async {
    final size = await pumpHeader(
      tester,
      'خلاصه امروز',
      trailing: const Text('۲ روز پیاپی'),
    );
    // A bare Flexible next to a Spacer capped the title at its flex share
    // (~2dp). It must render at its full text width instead.
    expect(size.width, greaterThan(60));
  });

  testWidgets('an oversized count chip scales down instead of overflowing',
      (tester) async {
    // Wider than the whole row: the FittedBox group must absorb it with
    // zero layout exceptions.
    await pumpHeader(
      tester,
      'اوقات شرعی',
      count: 'اشراق و صبح',
      trailing: const Text('2/5'),
    );
    expect(tester.takeException(), isNull);
  });
}
