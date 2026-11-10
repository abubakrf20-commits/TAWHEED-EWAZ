import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// Route-extra key the settings search uses when it pushes a destination page:
/// `context.push(route, extra: {kSettingsHighlightExtra: rowKey})` (see
/// `_openEntry` in `settings_screen.dart`).
const String kSettingsHighlightExtra = 'settingsHighlight';

/// Shared section wrapper that flashes the search-landing tint for 900ms.
///
/// The main page and every destination page (prayer, notifications, widgets,
/// font, about) use ONE implementation. A page only ever sets [flashKey]
/// while it owns an in-flight highlight — so under reduce-motion nothing
/// flashes, and a section never tints itself without a scroll landing on it.
class SettingsFlashSection extends StatelessWidget {
  const SettingsFlashSection({
    super.key,
    required this.rowKey,
    required this.flashKey,
    required this.child,
  });

  final String rowKey;
  final String? flashKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flash = flashKey == rowKey;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: flash
            ? SettingsTokens.selectedTint.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

/// Route-driven scroll-to-row for the settings sub-pages.
///
/// The main settings search pushes a page with
/// `extra: {kSettingsHighlightExtra: rowKey}`. A page that mixes this in:
///
/// * keeps a [highlightAnchors] map (rowKey → [GlobalKey]) with one key per
///   search-target section — always on a widget INSIDE the page's scrollable
///   (its [SectionHeader], block or row);
/// * calls [bindSettingsHighlight] from `didChangeDependencies`;
/// * passes [highlightFlashKey] to [SettingsFlashSection] around every
///   targetable section;
/// * calls [disposeSettingsHighlight] from `dispose`.
///
/// Destination pages call [bindSettingsHighlight] from
/// `didChangeDependencies`, pass [highlightFlashKey] to
/// [SettingsFlashSection] around every targetable section, attach
/// [highlightScrollController] to their scroll view, and call
/// [disposeSettingsHighlight] from `dispose`.
///
/// The scroll view can stay lazy: [SettingsHighlight] first walks the list
/// down a viewport at a time until the target row's key attaches (a lazy
/// sliver never builds a row below the fold, so `Scrollable.ensureVisible`
/// cannot reach it directly) and only then animates to it.
mixin SettingsHighlight<T extends StatefulWidget> on State<T> {
  /// rowKey → GlobalKey of that row/section (subclass-provided).
  Map<String, GlobalKey> get highlightAnchors;

  /// The rowKey currently flashing, if any.
  String? get highlightFlashKey => _highlightFlashKey;

  /// Scroll controller the page must attach to its scroll view.
  ScrollController get highlightScrollController => _highlightScrollController;

  final ScrollController _highlightScrollController = ScrollController();

  String? _highlightFlashKey;
  String? _pendingHighlight;
  Timer? _highlightTimer;

  /// Reads the route extra once per key and scrolls to the row after the
  /// first frame, then flashes its section for 900ms — the same timing and
  /// alignment as the main page's own in-page scroll.
  void bindSettingsHighlight() {
    final key = _routeHighlightKey();
    if (key == null || key == _pendingHighlight) return;
    _pendingHighlight = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToHighlight(key);
    });
  }

  String? _routeHighlightKey() {
    try {
      // Pages are also pumped without a GoRouter in widget tests, where
      // GoRouterState.of throws — there is no extra then, so the highlight
      // is a no-op.
      final extra = GoRouterState.of(context).extra;
      return extra is Map ? extra[kSettingsHighlightExtra] as String? : null;
    } on Object {
      return null;
    }
  }

  Future<void> _scrollToHighlight(String key) async {
    final anchor = highlightAnchors[key];
    if (anchor == null || !mounted) return;
    await _materializeAnchor(anchor);
    if (!mounted) return;
    final target = anchor.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    setState(() => _highlightFlashKey = key);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _highlightFlashKey = null);
    });
  }

  /// Walks the lazy scroll view down a viewport at a time until [anchor] is
  /// attached to the tree. Each jump forces the sliver to lay out the next
  /// region; the extent estimate refines as it goes, so the walk naturally
  /// stops once the row exists (a couple of frames on these short pages).
  Future<void> _materializeAnchor(GlobalKey anchor) async {
    final controller = _highlightScrollController;
    // A page whose body waits on a read renders a placeholder first, so the
    // scroll view can attach several frames after the route lands. Giving up
    // on `!hasClients` at that moment lost the highlight entirely on every
    // async page; wait for the attachment instead (bounded, so a page that
    // never scrolls cannot spin here).
    var waited = 0;
    while (mounted && !controller.hasClients && waited++ < 60) {
      await WidgetsBinding.instance.endOfFrame;
    }
    var guard = 0;
    while (mounted && anchor.currentContext == null && guard++ < 40) {
      if (!controller.hasClients) return;
      final position = controller.position;
      if (position.pixels >= position.maxScrollExtent - 1) return;
      controller.jumpTo(math.min(
        position.pixels + position.viewportDimension * 0.8,
        position.maxScrollExtent,
      ));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Cancels the flash timer and releases the scroll controller; call from
  /// `dispose`.
  void disposeSettingsHighlight() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _highlightScrollController.dispose();
  }
}