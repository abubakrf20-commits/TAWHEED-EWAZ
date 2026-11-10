import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/shell_nav.dart';

/// A request to open the Quran reader at a page WITHOUT touching the reader's
/// idea of "where the user is".
///
/// This is the `ReaderLaunchOptions(page, previewOnly: true)` the brief asks
/// for, expressed as a thin layer over the app's existing nav channel rather
/// than a second reader route: the mushaf is a shell tab, not a route, so
/// duplicating it for a preview would mean a second reader instance and a
/// second set of caches on a low-end phone.
///
/// The guarantee, and what a test pins:
///  • opening a preview never writes `quran_last_page`;
///  • the value the reader starts with is whatever the user's own last page was;
///  • leaving the reader leaves that value untouched.
class MushafPreviewLauncher {
  MushafPreviewLauncher(this._navRequests);

  final ValueNotifier<QuranNavRequest?> _navRequests;

  /// Requests the given page as a preview and switches to the Quran tab.
  ///
  /// [openQuranTab] is passed in rather than read from a provider so this stays
  /// usable from a plain callback and trivially testable.
  void open({
    required int page,
    required VoidCallback openQuranTab,
    int? lineStart,
    int? lineEnd,
  }) {
    final clamped = page.clamp(1, 604);
    _navRequests.value = QuranNavRequest(clamped, previewOnly: true);
    openQuranTab();
  }

  /// Ends a preview without moving. Used by the teacher sheet's «بستن».
  ///
  /// Re-requesting the user's own page with previewOnly false is what clears
  /// the flag in the reader (see `QuranMushafView.goToPage`).
  void exit({required int userPage}) {
    _navRequests.value = QuranNavRequest(userPage.clamp(1, 604));
    // Clearing immediately after is intentional: the tab consumes the request
    // and nulls it, and a request left pending would re-fire on the next open.
    _navRequests.value = null;
  }
}

final mushafPreviewLauncherProvider = Provider<MushafPreviewLauncher>(
  (ref) => MushafPreviewLauncher(ref.read(quranNavRequestProvider)),
);

/// Reads the page the user's own reading is saved at, for the exit path.
///
/// Kept next to the launcher so there is one place that knows the preference
/// key — `quran_last_page` is also read by the mushaf itself.
const String quranLastPagePrefKey = 'quran_last_page';
