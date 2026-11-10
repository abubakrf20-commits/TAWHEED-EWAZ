import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// A [DefaultTabController] that opens on the tab this reader left last time.
///
/// WHY this exists: nine section pages have between three and ten tabs, and
/// every single entry started on tab 1 — so a reader who lives in «محاسبه» had
/// to walk past «یادگیری» on every visit, and a traveller following the rites
/// was thrown back to the top of the guide each time the app was reopened.
///
/// The remembered index is written whenever the selection changes and read once
/// on mount. A stored index that no longer fits (the tab strip was shortened)
/// is clamped, never trusted blindly.
///
/// The controller is created on the first frame with index 0 and re-created
/// once the stored value arrives — a frame or two later, while the route
/// transition is still running. That is deliberate: waiting for the read before
/// painting would put back the blank first frame this same audit removed from
/// the ritual guide.
class RememberedTabs extends StatefulWidget {
  const RememberedTabs({
    super.key,
    required this.id,
    required this.length,
    required this.child,
  });

  /// Storage namespace, one per section — e.g. `'hajj'`, `'zakat'`.
  final String id;

  /// Number of tabs. The stored index is clamped to `0 .. length - 1`.
  final int length;

  final Widget child;

  /// The pref key for a section. Exposed so tests can seed a starting tab.
  static String keyFor(String id) => 'section_tab_$id';

  @override
  State<RememberedTabs> createState() => _RememberedTabsState();
}

class _RememberedTabsState extends State<RememberedTabs> {
  /// Where the tab strip should open. 0 until the stored value is known.
  int _index = 0;

  /// Bumped whenever [_index] is applied, so [DefaultTabController] is rebuilt
  /// with the new `initialIndex` — the widget ignores later changes to it.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(RememberedTabs.keyFor(widget.id));
      if (!mounted || stored == null) return;
      final clamped = stored.clamp(0, widget.length - 1);
      if (clamped == _index) return;
      setState(() {
        _index = clamped;
        _generation++;
      });
    } catch (e) {
      // A section that cannot read its last tab is a cosmetic loss, not a
      // reason to fail the page — but it should not vanish silently either.
      AppLogger.warning(
          'RememberedTabs', 'tab restore failed for ${widget.id}: $e');
    }
  }

  Future<void> _persist(int index) async {
    if (index == _index) return;
    _index = index;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(RememberedTabs.keyFor(widget.id), index);
    } catch (e) {
      AppLogger.warning(
          'RememberedTabs', 'tab persist failed for ${widget.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // A new key is what makes `initialIndex` take effect a second time.
      key: ValueKey('${widget.id}#$_generation'),
      length: widget.length,
      initialIndex: _index,
      child: _TabWatcher(onChanged: _persist, child: widget.child),
    );
  }
}

/// Reports every selection change made by the controller below it.
///
/// It has to live under [DefaultTabController] to reach the controller through
/// the inherited widget — [FlatTabs] does not take one, and neither does
/// [TabBarView] at most call sites.
class _TabWatcher extends StatefulWidget {
  const _TabWatcher({required this.onChanged, required this.child});

  final ValueChanged<int> onChanged;
  final Widget child;

  @override
  State<_TabWatcher> createState() => _TabWatcherState();
}

class _TabWatcherState extends State<_TabWatcher> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (identical(next, _controller)) return;
    _controller?.removeListener(_onTick);
    _controller = next..addListener(_onTick);
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) return;
    widget.onChanged(controller.index);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
