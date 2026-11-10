import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/personal2/shared/mushaf_preview.dart';

/// The brief's reader requirement, tested at the seam that actually enforces
/// it: a preview request must never move the user's saved reading position.
///
/// The reader itself writes `quran_last_page` through a debounced timer, and
/// the suppression lives in `QuranMushafView._flushLastPageSave`. What this
/// file pins is the contract the teacher tool depends on — that the nav
/// request carries `previewOnly`, and that the launcher never itself touches
/// the stored page. The reader-side latching is covered by
/// `mushaf_preview_reader_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'quran_last_page': 77});
  });

  group('QuranNavRequest', () {
    test('previewOnly defaults to false, so every existing caller is unchanged',
        () {
      const request = QuranNavRequest(10);
      expect(request.previewOnly, isFalse);
    });

    test('previewOnly is part of equality', () {
      const normal = QuranNavRequest(10);
      const preview = QuranNavRequest(10, previewOnly: true);
      expect(normal, isNot(preview));
      // A ValueNotifier suppresses equal values; two identical preview requests
      // must therefore be recognised as the same request, not re-fired.
      expect(preview, const QuranNavRequest(10, previewOnly: true));
    });
  });

  group('MushafPreviewLauncher', () {
    test('open() sends a preview request for the clamped page', () {
      final notifier = ValueNotifier<QuranNavRequest?>(null);
      var switchedTab = false;
      final launcher = MushafPreviewLauncher(notifier);

      launcher.open(
        page: 300,
        openQuranTab: () => switchedTab = true,
      );

      expect(switchedTab, isTrue);
      expect(notifier.value, isNotNull);
      expect(notifier.value!.page, 300);
      expect(notifier.value!.previewOnly, isTrue);
    });

    test('open() clamps an out-of-range page into 1..604', () {
      final notifier = ValueNotifier<QuranNavRequest?>(null);
      final launcher = MushafPreviewLauncher(notifier);

      launcher.open(page: 900, openQuranTab: () {});
      expect(notifier.value!.page, 604);

      launcher.open(page: -5, openQuranTab: () {});
      expect(notifier.value!.page, 1);
    });

    test('opening a preview never writes quran_last_page', () async {
      final notifier = ValueNotifier<QuranNavRequest?>(null);
      final launcher = MushafPreviewLauncher(notifier);

      launcher.open(page: 300, openQuranTab: () {});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(quranLastPagePrefKey), 77);
    });

    test('exit() clears the preview flag and leaves the page where it was',
        () async {
      final notifier = ValueNotifier<QuranNavRequest?>(null);
      final launcher = MushafPreviewLauncher(notifier);

      launcher.open(page: 300, openQuranTab: () {});
      launcher.exit(userPage: 77);

      // A non-preview request is what tells the reader the preview is over.
      // exit() nulls the notifier straight after, so the request is consumed —
      // assert the null rather than a stale preview marker.
      expect(notifier.value, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(quranLastPagePrefKey), 77);
    });

    test('the provider wires the launcher to the app nav channel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final launcher = container.read(mushafPreviewLauncherProvider);
      final notifier = container.read(quranNavRequestProvider);

      launcher.open(page: 42, openQuranTab: () {});
      expect(notifier.value!.page, 42);
      expect(notifier.value!.previewOnly, isTrue);
    });
  });
}
