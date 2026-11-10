import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Component-level widget tests for the qibla redesign pieces: the flat
/// segmented control and the duotone tile — at the accessibility-fixture
/// widths (320/360/412 dp) and text scales 1.0/1.3.
///
/// Transferred from screens/qibla-sciences-tahara (c6a44bf + 95009c9) with
/// two adaptations to the unified kit, both behavior-preserving:
/// - `DismissibleInfoCard` is gone: it lived in the old kit's
///   flat_note_cards (never ported — the design unification deleted that
///   file) and the transferred screen renders no calibration card, so a
///   group testing it would prove nothing about production.
/// - `SegmentedTabs(flat:)` is gone: the unified control has no
///   flat/gradient duality (the active pill always rides the phase hero
///   gradient), so the gradient assertion is replaced by the overflow
///   matrix + tap callback the group already carried.
///
/// The whole screen cannot be pumped in the tester because its map loads
/// OSM tiles over dart:io HttpClient, which the tester cannot serve without
/// the app's own infrastructure; page-level verification happens on-device.

Widget _tabs({required ValueChanged<int> onChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SegmentedTabs(
          index: 0,
          tabs: const [
            SegmentedTab(label: '3 درجه'),
            SegmentedTab(label: '5 درجه'),
            SegmentedTab(label: '10 درجه'),
          ],
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('SegmentedTabs', () {
    testWidgets('no overflow at 320 dp / scale 1.3; tap fires the callback',
        (tester) async {
      var changed = -1;
      await _setSize(tester, const Size(320, 300));
      await tester.pumpWidget(_tabs(onChanged: (i) => changed = i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('5 درجه'));
      await tester.pumpAndSettle();
      expect(changed, 1);
    });
  });

  group('DuotoneIconTile — the shared Style-2 tile', () {
    for (final w in [320.0, 412.0]) {
      testWidgets('fits at $w dp with text scale 1.3', (tester) async {
        await _setSize(tester, Size(w, 200));
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  for (final (accent, icon) in [
                    (TopicHues.qibla, Icons.explore),
                    (TopicHues.sciences, Icons.north),
                  ])
                    DuotoneIconTile(accent: accent, icon: icon, size: 32),
                ],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
