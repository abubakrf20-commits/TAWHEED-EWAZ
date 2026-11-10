import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RTL RichText child placement (bounded width)', (tester) async {
    final keys = [GlobalKey(), GlobalKey()];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 200,
            child: RichText(
              text: TextSpan(
                children: [
                  WidgetSpan(
                      child: SizedBox(key: keys[0], width: 40, height: 40)),
                  WidgetSpan(
                      child: SizedBox(key: keys[1], width: 40, height: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final box0 = keys[0].currentContext!.findRenderObject()! as RenderBox;
    final box1 = keys[1].currentContext!.findRenderObject()! as RenderBox;
    final left0 = box0.localToGlobal(Offset.zero).dx;
    final left1 = box1.localToGlobal(Offset.zero).dx;
    // ignore: avoid_print
    print('bounded: child0 left=$left0, child1 left=$left1');

    // RTL: first child anchors to the RIGHT edge of the 200px box.
    // The SizedBox starts at x=300 (Center on 800px screen), ends at 500.
    expect(left1, 460, reason: 'second child sits left of the right edge');
    expect(left0, 420, reason: 'first child is right of the second child');
  });
}
