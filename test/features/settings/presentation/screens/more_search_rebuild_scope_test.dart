import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/search/services/more_content_search.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// The hero strip attaches the shared ClockTicker; a real one would leave a
/// recurring timer pending at teardown. The idle variant never schedules.
final _idleTicker = clockTickerProvider.overrideWith((ref) {
  final ticker = ClockTicker.idle();
  ref.onDispose(ticker.dispose);
  return ticker;
});

ProviderScope _wrap(Widget child) {
  SharedPreferences.setMockInitialValues({});
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      _idleTicker,
    ],
    child: child,
  );
}

/// «چرت» lives only in a guide's prose, so the deep layer answers with text
/// the test wrote — and «وضو» matches both a tile and that prose, which is
/// exactly the two-layer keystroke the rebuild scope must hold.
const guideBody = 'اگر چرت بزنانید وضو باطل می‌شود';

List<MoreContentSource> guideLayer() => [
      _FakeSource('purification', const [
        ContentPiece('بطلان وضو', guideBody),
      ]),
    ];

class _FakeSource extends MoreContentSource {
  _FakeSource(super.itemId, this.owned);

  final List<ContentPiece> owned;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) => Future.value(owned);
}

Future<void> open(
  WidgetTester tester, {
  List<MoreContentSource>? sources,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(MaterialApp(
    theme: AppTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MoreScreen(contentSources: sources),
    ),
  )));
  await tester.pumpAndSettle();
}

/// The purification tile's element. With a matching query on screen the
/// label «وضو و طهارت» appears twice — the tile and the hit row's owning-
/// section caption — so every match is walked and the one sitting under a
/// tile is returned.
Element _worshipTileElement(WidgetTester tester) {
  for (final textElement in find.text('وضو و طهارت').evaluate()) {
    Element? tile;
    textElement.visitAncestorElements((e) {
      if (e.widget.runtimeType.toString() == '_Style2Tile') {
        tile = e;
        return false;
      }
      return true;
    });
    if (tile != null) return tile!;
  }
  throw StateError('no وضو tile on the page');
}

/// The phase-2 contract: a search keystroke repaints the RESULTS — never the
/// page chrome, and never a group block whose membership did not change.
/// Measured against HEAD, which rebuilt the whole screen (296 elements,
/// 263,313 µs) on every debounced keystroke.
void main() {
  testWidgets('a keystroke repaints the results, not the page', (tester) async {
    await open(tester, sources: guideLayer());

    final perElement = <Element, int>{};
    var total = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      total++;
      perElement[element] = (perElement[element] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.enterText(find.byType(TextField), 'وضو');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // Capture AFTER the keystroke: the membership change (14 tiles → 1)
    // legitimately rebuilds the block once, and the keyless grid may swap
    // elements while shrinking — the identity contract starts from the
    // settled grid.
    final tile = _worshipTileElement(tester);

    // Split the total by subtree: the field's own EditableText machinery
    // rebuilds on every keystroke (any text field does), and the field's
    // selection-handle/toolbar entries live in the root Overlay — OUTSIDE
    // the TextField element — so they classify as chrome by construction.
    // The contract is the results budget plus the chrome TYPES (the shell,
    // the strip and the field wrapper must never appear), not a count.
    final fieldEl = tester.element(find.byType(TextField));
    final areaEl = tester.element(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_SearchResultsArea'));
    bool under(Element e, Element root) {
      var hit = false;
      e.visitAncestorElements((a) {
        if (identical(a, root)) {
          hit = true;
          return false;
        }
        return true;
      });
      return hit;
    }

    var fieldBuilds = 0, areaBuilds = 0, chromeBuilds = 0;
    perElement.forEach((e, builds) {
      if (!e.mounted) {
        return;
      } else if (under(e, fieldEl)) {
        fieldBuilds += builds;
      } else if (under(e, areaEl)) {
        areaBuilds += builds;
      } else {
        chromeBuilds += builds;
      }
    });

    bool built(String type) => perElement.keys
        .any((e) => e.mounted && e.widget.runtimeType.toString() == type);
    debugPrint('keystroke rebuild: total=$total '
        'shell=${built('SectionShell')} strip=${built('_MorePrayerStrip')} '
        'field=${built('_SearchField')} tile=${perElement[tile] ?? 0} '
        '| fieldSubtree=$fieldBuilds results=$areaBuilds '
        'chrome=$chromeBuilds');

    // Both layers answered: the matching tiles and the text found inside the
    // sections (the guide row carries the owning section's title).
    expect(find.text('در متن بخش‌ها'), findsOneWidget);
    expect(find.text('وضو و طهارت'), findsNWidgets(2));

    // The scope: the page chrome never rebuilt for the keystroke.
    expect(built('SectionShell'), isFalse,
        reason: 'the page shell rebuilt for a keystroke');
    expect(built('_MorePrayerStrip'), isFalse,
        reason: 'the hero strip rebuilt for a keystroke');
    expect(built('_SearchField'), isFalse,
        reason: 'the search field wrapper rebuilt for a keystroke');

    // The surviving tile: built exactly once across the whole keystroke
    // window (debounce + both waves coalesce into one frame — the waves
    // change hits, not group membership), never re-inflated.
    expect(tile.mounted, isTrue,
        reason: 'the وضو tile element was re-inflated instead of updated');
    expect(perElement[tile], 1,
        reason: 'the وضو tile rebuilt ${perElement[tile] ?? 0} times for '
            'one keystroke window');

    expect(areaBuilds, lessThan(150),
        reason: 'the results subtree rebuilt $areaBuilds elements for one '
            'keystroke — HEAD rebuilt the whole screen (296 elements, '
            '263,313 µs) per keystroke');
  });

  testWidgets('a refine with the same query skips the surviving tiles',
      (tester) async {
    await open(tester, sources: guideLayer());

    await tester.enterText(find.byType(TextField), 'وضو');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('در متن بخش‌ها'), findsOneWidget);

    // Capture from the settled grid (the keystroke may have swapped grid
    // elements), then arm the hook for the refine.
    final tile = _worshipTileElement(tester);

    var tileBuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (identical(element, tile)) tileBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    // A trailing space: the normalized query is unchanged, so the group
    // membership is identical. The content engine still re-runs (fresh hit
    // instances repaint the rows) — but the tiles must not rebuild.
    await tester.enterText(find.byType(TextField), 'وضو ');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('در متن بخش‌ها'), findsOneWidget);
    expect(find.text('وضو و طهارت'), findsNWidgets(2));
    expect(tile.mounted, isTrue,
        reason: 'the وضو tile element was re-inflated by a refine');
    expect(tileBuilds, 0,
        reason: 'the refine rebuilt the وضو tile although its group '
            'membership was unchanged (HEAD rebuilt it on every keystroke)');
  });
}
