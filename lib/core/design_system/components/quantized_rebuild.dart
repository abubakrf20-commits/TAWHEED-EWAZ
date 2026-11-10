import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// QuantizedRebuild — a tick gate for home cards on [ClockTicker].minute.
///
/// A plain ValueListenableBuilder on the minute notifier rebuilds its
/// whole subtree every minute even when nothing visible changed — the
/// home page's six gates cost 437 rebuilds / ~110 ms per tick (the
/// phase-2 measurement). This widget listens to the same listenable but
/// rebuilds only when [keyOf] maps the new instant to a DIFFERENT key:
/// the key captures exactly the now-derived content the builder shows
/// (period labels, row states, visible reminder ids…), so a tick that
/// changes no visible state is dropped.
///
/// Rules that keep it honest:
/// - Provider-driven content must NOT be in the key: a provider change
///   rebuilds the PARENT, and a parent rebuild re-runs [builder] with
///   fresh closures regardless of the key. Only tick-driven rebuilds
///   are gated.
/// - [keyOf] must be pure over its captured values: no `ref.watch`
///   (listeners cannot watch) — hoist every watch to the outer build
///   and capture the results. `ref.read` is allowed.
/// - A List inside the key compares by identity, never use one —
///   flatten to scalars or a String.
/// - The latest instant is kept even when the key is unchanged, so a
///   parent rebuild reads the same "now" a bare VLB would pass.
/// - The first build always renders (goldens and pinned-now tests need
///   no special case); a pinned `nowOverride` folded into BOTH [keyOf]
///   and [builder] makes the key constant, so live ticks never rebuild
///   the gated subtree.
/// - [didUpdateWidget] re-evaluates even when the listenable is
///   unchanged: a new closure means the parent rebuilt, and a key flip
///   there costs one extra setState at most.
/// ═══════════════════════════════════════════════════════════════
class QuantizedRebuild<K> extends StatefulWidget {
  const QuantizedRebuild({
    super.key,
    required this.listenable,
    required this.keyOf,
    required this.builder,
  });

  final ValueListenable<DateTime> listenable;
  final K Function(DateTime now) keyOf;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<QuantizedRebuild<K>> createState() => _QuantizedRebuildState<K>();
}

class _QuantizedRebuildState<K> extends State<QuantizedRebuild<K>> {
  late DateTime _now;
  late K _key;

  @override
  void initState() {
    super.initState();
    _now = widget.listenable.value;
    _key = widget.keyOf(_now);
    widget.listenable.addListener(_onTick);
  }

  @override
  void didUpdateWidget(QuantizedRebuild<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_onTick);
      widget.listenable.addListener(_onTick);
    }
    _now = widget.listenable.value;
    _key = widget.keyOf(_now);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    _now = widget.listenable.value;
    final k = widget.keyOf(_now);
    if (k != _key) {
      setState(() => _key = k);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
