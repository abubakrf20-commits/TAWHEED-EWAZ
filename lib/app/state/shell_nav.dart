import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shell_nav.g.dart';

/// A request to navigate the Quran tab to a specific page (and optionally
/// highlight a verse). Used by the global search to jump from any tab to a
/// verse match.
class QuranNavRequest {
  final int page;
  final int? surah;
  final int? verse;

  /// When true the reader opens at [page] WITHOUT recording it as the user's
  /// own position: `quran_last_page` is neither written by the page changes
  /// this navigation causes nor left pointing at a preview page when the
  /// reader is closed.
  ///
  /// Added for «دفتر مربی قرآن», which opens a page to show a student's
  /// assignment. A teacher who taps «باز کردن در مصحف» to check page 300 must
  /// find their own reading saved where it was, not at the student's page.
  final bool previewOnly;

  const QuranNavRequest(
    this.page, {
    this.surah,
    this.verse,
    this.previewOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      other is QuranNavRequest &&
      other.page == page &&
      other.surah == surah &&
      other.verse == verse &&
      other.previewOnly == previewOnly;

  @override
  int get hashCode => Object.hash(page, surah, verse, previewOnly);
}

/// Transient channel: [ValueNotifier] so external code (global search) can push
/// a navigation request that [QuranTab] consumes without a build_runner pass.
final quranNavRequestProvider =
    Provider<ValueNotifier<QuranNavRequest?>>((ref) => ValueNotifier(null));

/// Whether the Quran image-mushaf reader is in full-screen immersive mode.
///
/// While true the shell hides its bottom navigation so the mushaf page fills
/// the whole screen; tapping the page brings the chrome back. Written by
/// [QuranTab] — plain [NotifierProvider] so no build_runner pass is needed.
class QuranImmersive extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final quranImmersiveProvider =
    NotifierProvider<QuranImmersive, bool>(QuranImmersive.new);

/// Canonical shell navigation state.
///
/// Provider-based shell navigation: any widget (including legacy tabs) can
/// switch the active shell tab imperatively via
/// `ProviderScope.containerOf(context).read(shellTabIndexProvider.notifier)`
/// without coupling to the shell widget tree.
///
/// `MainShellState.of(context)` (app_router/main_shell.dart) is NOT replaced by
/// this — it remains the InheritedWidget read/write path for widgets that live
/// inside the shell subtree.

@Riverpod(keepAlive: true)
class ShellTabIndex extends _$ShellTabIndex {
  @override
  int build() {
    _restore();
    return 0;
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    // A pending widget shortcut will set the tab itself; don't race it.
    final shortcut = p.getString('widget_shortcut');
    if (shortcut != null && shortcut.isNotEmpty) return;
    final saved = p.getInt('shellTabIndex');
    if (saved != null && saved >= 0) state = saved;
  }

  void setIndex(int index) {
    // No-op on an unchanged value: repeated taps on the same nav item must
    // not notify (rebuild) or rewrite the preference.
    if (state == index) return;
    state = index;
    SharedPreferences.getInstance()
        .then((p) => p.setInt('shellTabIndex', index));
  }
}

@Riverpod(keepAlive: true)
class ShellSubTab extends _$ShellSubTab {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state == index) return;
    state = index;
    SharedPreferences.getInstance().then((p) => p.setInt('shellSubTab', index));
  }
}
