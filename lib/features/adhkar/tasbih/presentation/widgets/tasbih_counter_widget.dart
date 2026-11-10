import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_stats_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_dhikr_sheet.dart';
import 'package:tawheeed/features/adhkar/tasbih/tasbih.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/shared/services/click_sound_player.dart';
import 'package:tawheeed/shared/services/sound_registry.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

class TasbihCounterWidget extends ConsumerStatefulWidget {
  const TasbihCounterWidget({super.key});

  @override
  ConsumerState<TasbihCounterWidget> createState() =>
      _TasbihCounterWidgetState();
}

class _TasbihCounterWidgetState extends ConsumerState<TasbihCounterWidget>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  /// One [GlobalKey] per chip **position**, so the strip can scroll the active
  /// chip into view (e.g. after auto-rotate on target completion).
  ///
  /// The keys stay per-index rather than one shared key on the active chip: in
  /// a single rebuild pass the ListView would hand that key to the new chip
  /// before the old one releases it, and GlobalKey asserts
  /// «Duplicate GlobalKey detected in widget tree» on exactly that.
  final Map<int, GlobalKey> _chipKeys = {};

  /// User pressed «ادامه» after passing the target: the completion/overshoot
  /// visuals are dismissed and counting continues normally (gold accent).
  bool _continuePastTarget = false;

  /// SoundPool (lowLatency) with timed recycle — <15 ms latency and safe
  /// overlapping playback for burst taps.
  final ClickSoundPlayer _clickPlayer =
      ClickSoundPlayer(SoundRegistry.tick.asset);

  /// Quick-mode repeat timer (hold to count continuously).
  Timer? _quickTimer;

  // Fundamental lag fix: batch rapid taps locally and flush to DB every 180ms.
  // This keeps UI at 60fps while persisting correctly.
  final Map<String, int> _pendingDeltas = {};
  Timer? _syncTimer;
  int _lastTapAt = 0;
  bool _rotateScheduled = false;

  /// Display count updated on every tap for immediate UI feedback.
  /// The counter card watches this ValueNotifier — only it rebuilds on taps,
  /// not the entire parent widget (eliminates ~5.5 parent rebuilds/sec).
  final ValueNotifier<int> _displayCountNotifier = ValueNotifier<int>(0);

  /// True while the counter surface is held down — drives the small press
  /// scale animation on the inner button.
  final ValueNotifier<bool> _pressed = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_clickPlayer.warmUp());
    // The list owns both the dhikr and its count, so the dial follows every
    // change to it — a reset, a target edit, an added or deleted dhikr, and a
    // batch drained from the home-screen widget. `build()` must not do this:
    // mutating state while building wrote the same values on every frame.
    // The subscription is closed by the widget itself on unmount, and
    // `listenManual` is the initState-legal variant (`ref.listen` asserts that
    // it runs during build and drops its subscription on every rebuild).
    ref.listenManual(
      tasbihProvider,
      (previous, next) => _syncActiveTasbih(next.value),
      fireImmediately: true,
    );
  }

  /// Points the dial at the dhikr the index selects and prints its live count
  /// plus the taps still queued in [_pendingDeltas]. Runs from the provider
  /// listener and from the two places that move the index by hand.
  void _syncActiveTasbih(List<TasbihModel>? tasbihs) {
    if (tasbihs == null || tasbihs.isEmpty) return;
    final ci = _currentIndex.clamp(0, tasbihs.length - 1);
    _currentIndex = ci;
    final current = tasbihs[ci];
    _displayCountNotifier.value =
        current.currentCount + (_pendingDeltas[current.id] ?? 0);
  }

  /// The last moment `ref` is safe to use. Flutter unmounts the element
  /// **before** calling `State.dispose()`, so the old `dispose()`-time flush
  /// threw `Using "ref" when a widget is about to or has been unmounted is
  /// unsafe` out of the first `ref.read` and the rest of teardown — the
  /// notifiers and the sound pool — never ran. `deactivate()` still has a live
  /// element, so the queued burst is handed over here instead.
  @override
  void deactivate() {
    if (_pendingDeltas.isNotEmpty) unawaited(_flushPendingSync());
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _stopQuickCount();
    _displayCountNotifier.dispose();
    _pressed.dispose();
    unawaited(_clickPlayer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App leaving the foreground: stop the hold-to-count timer so it cannot
    // keep incrementing while backgrounded, and flush batched taps NOW.
    // dispose() may never run (or finish) if the OS kills the process, which
    // would lose up to 180ms of taps; onPause/inactive fire first.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopQuickCount();
      if (_pendingDeltas.isNotEmpty) unawaited(_flushPendingSync());
    }
  }

  /// Writes every queued tap and then re-syncs the home-screen widget.
  /// Awaited, so a reset can be sequenced *after* it instead of racing it.
  Future<void> _flushPendingSync() async {
    if (_pendingDeltas.isEmpty) return;
    // Cancelling here matters: the 180 ms timer can fire between this call and
    // the writes, which would flush a queue a second time and double-count.
    _syncTimer?.cancel();
    final toFlush = Map<String, int>.from(_pendingDeltas);
    _pendingDeltas.clear();
    // Every `ref` read sits before the first await — the flush is also started
    // from deactivate(), where `ref` is only reachable synchronously.
    final notifier = ref.read(tasbihProvider.notifier);
    await Future.wait([
      for (final entry in toFlush.entries)
        entry.value == 1
            ? notifier.increment(entry.key)
            : notifier.addCount(entry.key, entry.value),
    ]);
    // بعد از نوشتن در DB، شمارندهٔ ویجت خانه را هم با آخرین حالت هماهنگ کن —
    // بدون بلوکه‌کردن و با fire-and-forget تا حرکات لمس همچنان روان باشد.
    _syncWidgetAfterFlush();
  }

  /// ویجت تسبیح (خانه) را با ذکر فعال و شمارش واقعی (شامل همین دسته) به‌روز
  /// می‌کند تا بین اپ و ویجت همیشه یک‌سان باشند.
  void _syncWidgetAfterFlush() {
    // Runs after an await, so the tab may already be torn down. `State.context`
    // THROWS once the element is gone (it asserts `_element != null`), so it
    // cannot be used as the probe here; `mounted` reads the same element
    // without asserting.
    if (!mounted) return;
    final tasbihs = ref.read(tasbihProvider).value ?? const [];
    if (tasbihs.isEmpty) return;
    final ci = _currentIndex.clamp(0, tasbihs.length - 1);
    final t = tasbihs[ci];
    try {
      ref.read(widgetSyncProvider).updateTasbihWidget(
            dhikr: t.targetDhikr,
            count: t.currentCount,
            target: t.targetCount,
            isActive: t.currentCount > 0,
            zikrIndex: ci,
            zikrId: t.id,
          );
    } catch (e) {
      // ویجت بریج در دسترس نیست (مثلاً تست‌ها) — شمارش فقط داخل اپ می‌ماند،
      // پس باید قابل تشخیص باشد تا یک‌بار سکوتِ کامل نشود.
      AppLogger.warning('tasbih_counter', 'widget sync skipped: $e');
    }
  }

  void _queueIncrement(String id) {
    _pendingDeltas[id] = (_pendingDeltas[id] ?? 0) + 1;
    _syncTimer?.cancel();
    // Aggressive batching for rapid taps: flush every 180ms
    _syncTimer = Timer(const Duration(milliseconds: 180), _flushPendingSync);
  }

  int _hapticCounter = 0;
  Future<void> _increment(
      TasbihModel current, AzkarSettingsData settings) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isRapid = nowMs - _lastTapAt < 80;
    _lastTapAt = nowMs;

    // Throttle haptics on rapid taps: every 2nd tap only, to avoid vibrator
    // lag. The counter counts EVERY tap, not only the throttled branch — the
    // old `++` lived inside `if (hapticEnabled && !isRapid)`, so with haptics
    // off (or outside a burst) the parity never advanced and the throttle
    // state drifted from the taps it was meant to thin out.
    _hapticCounter++;
    if (settings.hapticEnabled && (!isRapid || _hapticCounter.isOdd)) {
      HapticFeedback.lightImpact();
    }

    // Batch DB writes — immediate UI via local pending, flush every 180ms
    _queueIncrement(current.id);
    final displayCount = ++_displayCountNotifier.value;

    // Low-latency SoundPool click: timed recycle handles overlap, no
    // MediaPlayer/AudioFocus lag. Fire-and-forget so counting stays 60 fps.
    if (settings.soundEnabled) {
      unawaited(_clickPlayer.play(settings.tasbihVolume));
    }

    // Auto-rotate on CROSSING the target (>=, not ==): a 180 ms-batched tap
    // can step the display straight over the target, which the old exact
    // equality silently skipped. A guard keeps the delayed cycle from
    // double-firing during bursts.
    //
    // The value read is the notifier the UI just moved, not
    // `current.currentCount + _pendingDeltas[id]`: `current` is the model
    // captured when this frame's build ran, so a reset or a drained widget
    // batch landing mid-burst made the stale copy re-derive a count the dial
    // no longer shows.
    if (settings.autoRotate &&
        current.targetCount > 0 &&
        displayCount >= current.targetCount &&
        displayCount - 1 < current.targetCount &&
        !_rotateScheduled) {
      _rotateScheduled = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        _rotateScheduled = false;
        if (mounted) _cycle(1);
      });
    }
  }

  /// Quick tasbih: hold the counter and it keeps counting.
  void _startQuickCount(TasbihModel current, AzkarSettingsData settings) {
    _stopQuickCount();
    // Count once immediately on hold, then keep repeating.
    _increment(current, settings);
    _quickTimer = Timer.periodic(settings.quickSpeed.interval, (_) {
      if (!mounted) {
        _stopQuickCount();
        return;
      }
      final t = ref.read(tasbihProvider).value ?? [];
      if (t.isEmpty) {
        _stopQuickCount();
        return;
      }
      final idx = _currentIndex.clamp(0, t.length - 1);
      // No explicit pulse here — during a hold the bead ring advancing every
      // tick is plenty of feedback; an extra 220ms scale animation per tick
      // only wastes frames on weak phones.
      _increment(t[idx], settings);
    });
  }

  void _stopQuickCount() {
    _quickTimer?.cancel();
    _quickTimer = null;
  }

  void _cycle(int direction) {
    final tasbihs = ref.read(tasbihProvider).value ?? [];
    if (tasbihs.isEmpty) return;
    final newIndex = (_currentIndex + direction) % tasbihs.length;
    final ci = newIndex < 0 ? tasbihs.length - 1 : newIndex;
    setState(() {
      _currentIndex = ci;
      _continuePastTarget = false;
    });
    // build() no longer writes state, so every place that moves the index by
    // hand re-points the dial itself — otherwise the counter would keep
    // printing the previous dhikr's count until the next provider change.
    _syncActiveTasbih(tasbihs);
    _pushSelectionToWidget(tasbihs[ci], ci);
    _revealActiveChip();
  }

  /// Scrolls the dhikr-selector strip so the active chip is visible. Runs after
  /// the frame so the chip for the new index exists in the tree.
  void _revealActiveChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _chipKeys[_currentIndex]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Pushes one zikr to the native widget prefs so the home-screen widget
  /// follows the app's selection (index + count + target), not just the counts.
  ///
  /// The [index] is a parameter rather than a `_currentIndex` read: the caller
  /// passes the position it just switched to, and `_currentIndex` is only
  /// clamped inside `_syncActiveTasbih`, so a push racing that clamp could
  /// stamp the widget with the dhikr it no longer names.
  void _pushSelectionToWidget(TasbihModel tasbih, int index) {
    try {
      ref.read(widgetSyncProvider).updateTasbihWidget(
            dhikr: tasbih.targetDhikr,
            count: tasbih.currentCount,
            target: tasbih.targetCount,
            isActive: tasbih.currentCount > 0,
            zikrIndex: index,
            zikrId: tasbih.id,
          );
    } catch (e) {
      // Widget bridge unavailable (e.g. tests) — selection stays app-only.
      // Logged, so a real bridge failure is never indistinguishable from a
      // world with no widget installed.
      AppLogger.warning('tasbih_counter', 'widget selection push skipped: $e');
    }
  }

  /// Long-press on a chip: that dhikr's own numbers, and its rename door.
  ///
  /// [showTasbihDhikrSheet] mutates only through the provider, so what is owed
  /// here after it closes is the home-screen widget. The launcher shows ONE
  /// dhikr's text, and its per-dhikr map is keyed by that text — a rename of
  /// the dhikr it is showing has to be pushed, or the launcher keeps the old
  /// wording until the next full snapshot. Renaming any other dhikr waits for
  /// that snapshot on purpose: pushing it would also publish this index's
  /// count over a dhikr the widget is not showing.
  ///
  /// The sheet is re-read from the provider rather than taking a result value,
  /// so a rename that lands while the sheet is dismissed is still picked up.
  Future<void> _openDhikrSheet(TasbihModel tasbih) async {
    final before = tasbih.targetDhikr;
    await showTasbihDhikrSheet(context, tasbih: tasbih);
    if (!mounted) return;
    final live = ref.read(tasbihProvider).value ?? const <TasbihModel>[];
    final idx = live.indexWhere((t) => t.id == tasbih.id);
    if (idx < 0 || live[idx].targetDhikr == before) return;
    if (idx != _currentIndex.clamp(0, live.length - 1)) return;
    _syncActiveTasbih(live);
    _pushSelectionToWidget(live[idx], idx);
  }

  void _changeTarget(TasbihModel current) {
    final ctrl = TextEditingController(text: current.targetCount.toString());
    bool hasError = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تغییر هدف'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.rtl,
            autocorrect: false,
            inputFormatters: const [LatinGroupingFormatter(allowDecimal: false)],
            decoration: InputDecoration(
              labelText: 'تعداد جدید',
              border: const OutlineInputBorder(),
              errorText: hasError ? 'عدد معتبر وارد کنید' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final text = _normalizeDigits(ctrl.text.trim());
                final t = int.tryParse(text);
                if (t != null && t > 0) {
                  ref.read(tasbihProvider.notifier).updateTarget(current.id, t);
                  Navigator.pop(ctx);
                } else {
                  setDialogState(() => hasError = true);
                }
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  void _addManual(TasbihModel current) {
    final ctrl = TextEditingController();
    bool hasError = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('افزودن تعداد دستی'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.rtl,
            autocorrect: false,
            // NOTE: intentionally no `autofocus: true` — forcing the OS numeric
            // keyboard to appear simultaneously with the dialog entrance
            // animation causes visible jank on slower devices. The user taps
            // the field to type instead.
            inputFormatters: const [LatinGroupingFormatter(allowDecimal: false)],
            decoration: InputDecoration(
              labelText: 'تعداد مورد نظر (مثلاً 500)',
              border: const OutlineInputBorder(),
              errorText: hasError ? 'عدد معتبر وارد کنید' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final text = _normalizeDigits(ctrl.text.trim());
                final amount = int.tryParse(text);
                if (amount != null && amount > 0) {
                  ref
                      .read(tasbihProvider.notifier)
                      .addCount(current.id, amount);
                  Navigator.pop(ctx);
                } else {
                  setDialogState(() => hasError = true);
                }
              },
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  /// Folds typed digits AND drops the grouping the entry formatter
  /// inserts, so `int.tryParse` below reads a real number.
  String _normalizeDigits(String s) =>
      NumberFormat.normalizeDigits(s).replaceAll(',', '');

  /// Zeroes the counter only **after** the queued taps have landed.
  ///
  /// The dialog and the «ریست» button both used to call `reset()` while a
  /// burst was still sitting in [_pendingDeltas]; the 180 ms flush then wrote
  /// those taps on top of the freshly zeroed row, so a reset mid-counting
  /// silently came back as the burst count. The hold-to-count timer stops
  /// first for the same reason — one more queued tick after the flush is one
  /// tap the user just reset away.
  Future<void> _resetAfterFlush(String id) async {
    _stopQuickCount();
    await _flushPendingSync();
    // The flush is awaited, so the tab can be gone by now. Probe `mounted`, not
    // `context.mounted`: the `context` getter asserts once the element is null.
    if (!mounted) return;
    setState(() => _continuePastTarget = false);
    await ref.read(tasbihProvider.notifier).reset(id);
  }

  void _confirmReset(TasbihModel current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأیید ریست'),
        content: const Text('آیا از ریست کردن تسبیح جاری اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(_resetAfterFlush(current.id));
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('ریست'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasbihsAsync = ref.watch(tasbihProvider);
    final azkarSettings = ref.watch(azkarSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The tasbih section's fixed identity hue (the 2026 design's colored-pill
    // language) — the counter reads as «تسبیح» in every theme.
    const hue = SectionHues.tasbih;
    final dotHue = isDark
        ? (Color.lerp(hue, Colors.white, 0.42) ?? hue)
        : hue;
    final errorHue = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warnHue = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;

    return AsyncScreen<List<TasbihModel>>(
      asyncValue: tasbihsAsync,
      onRetry: () => ref.invalidate(tasbihProvider),
      data: (tasbihs) {
        if (tasbihs.isEmpty) {
          return const _EmptyState();
        }

        // Read-only clamp: build must not write state. The notifier is kept in
        // step by _syncActiveTasbih (the provider listener plus the two places
        // that move the index by hand), so a frame never re-assigns it.
        final ci = _currentIndex.clamp(0, tasbihs.length - 1);
        final current = tasbihs[ci];

        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.page, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Mini stats flanking the quick-tasbih toggle ──
                    // «هدف روزانه» (right) and «این هفته» (left) live here in
                    // two compact boxes, so the page below stays short enough
                    // to need no scrolling.
                    Row(
                      children: [
                        const Expanded(
                          child: _MiniStatBox(
                            label: 'هدف روزانه',
                            hue: AppPalette.emerald,
                            daily: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Center(
                          child: _QuickModePill(
                            active: azkarSettings.quickCount,
                            hue: hue,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(azkarSettingsProvider.notifier)
                                  .setQuickCount(!azkarSettings.quickCount);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          // The week box takes the app's *calendar* indigo — the
                          // hue days already wear — instead of a third amber: the
                          // «تسبیح سریع» pill between the two boxes owns the
                          // section hue, and three ambers in one row would blur
                          // which control does what.
                          child: _MiniStatBox(
                            label: 'این هفته',
                            hue: SectionHues.calendar,
                            daily: false,
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: azkarSettings.quickCount
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _SpeedSelector(
                                selected: azkarSettings.quickSpeed,
                                hue: hue,
                                onChanged: (speed) {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(azkarSettingsProvider.notifier)
                                      .setQuickSpeed(speed);
                                },
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: DsSpacing.gap),
                    _CounterCard(
                      current: current,
                      pressed: _pressed,
                      displayCountNotifier: _displayCountNotifier,
                      continuePastTarget: _continuePastTarget,
                      onContinuePastTarget: () =>
                          setState(() => _continuePastTarget = true),
                      onReset: () => _confirmReset(current),
                      onAddManual: () => _addManual(current),
                      onChangeTarget: () => _changeTarget(current),
                      onCycle: _cycle,
                      onTap: () {
                        _stopQuickCount();
                        _increment(current, azkarSettings);
                      },
                      onLongPressStart: (_) {
                        if (azkarSettings.quickCount) {
                          _startQuickCount(current, azkarSettings);
                        } else {
                          _confirmReset(current);
                        }
                      },
                      onLongPressEnd: (_) => _stopQuickCount(),
                      onLongPressCancel: _stopQuickCount,
                    ),
                    const SizedBox(height: 12),
                    // ── Dhikr selector chips ──
                    // A horizontally scrolled child gets UNBOUNDED width, so an
                    // `ellipsis` label there never truncates: it just grows the
                    // row and throws. chipLabelMax is the real bound — the page
                    // width minus the page padding, the chip's own horizontal
                    // padding (14 × 2) and the tick slot (13 + 4) when the
                    // dhikr is complete.
                    //
                    // The whole name renders inside that bound (no
                    // `substring(0, 15)` cutting a name the user chose). A tap
                    // selects the dhikr; a long-press opens its own sheet
                    // (numbers + rename) — the truncation tooltip this chip
                    // used to carry gave way to that gesture.
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tasbihs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final t = tasbihs[i];
                          final chipLabelMax = (constraints.maxWidth -
                                  2 * DsSpacing.page -
                                  45)
                              .clamp(48.0, double.infinity);
                          final isActive = i == ci;
                          // The selected chip wears the tab's OWN hue, not the
                          // app's emerald. Emerald means «انجام شد» everywhere
                          // on this screen (the ring, the completion badge, the
                          // tick in this very chip) — and it is also
                          // `SectionHues.quran`, so a teal selected chip on the
                          // tasbih tab read as another tab's colour carrying a
                          // third meaning. The fill is the readable variant of
                          // the hue so white/near-black ink clears 4.5:1 in both
                          // palettes; depth is only what legibility costs.
                          final activeFill = dsContentColor(context, hue);
                          final activeInk = dsOnAccent(context);
                          final ink = isActive
                              ? activeInk
                              : dsContentColor(context, hue);
                          return GestureDetector(
                            key: _chipKeys.putIfAbsent(i, GlobalKey.new),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _currentIndex = i;
                                _continuePastTarget = false;
                              });
                              _syncActiveTasbih(tasbihs);
                              _pushSelectionToWidget(t, i);
                              _revealActiveChip();
                            },
                            onLongPress: () {
                              HapticFeedback.selectionClick();
                              _openDhikrSheet(t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? activeFill : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isActive
                                        ? activeFill
                                        : hue.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (t.currentCount >= t.targetCount) ...[
                                    Icon(Icons.check, size: 13, color: ink),
                                    const SizedBox(width: 4),
                                  ],
                                  ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: chipLabelMax),
                                    child: Text(
                                      t.targetDhikr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 13),
                                          color: ink,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal),
                                    ),
                                  ),
                                  // Visible door to the dhikr sheet on the
                                  // active chip only: a long-press works on
                                  // any chip, but a gesture nobody can see is
                                  // not discoverable. Tapping the active chip
                                  // itself is already a no-op, so nothing is
                                  // taken away by this small target.
                                  if (isActive) ...[
                                    const SizedBox(width: 2),
                                    Tooltip(
                                      message: 'مدیریت ذکر',
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _openDhikrSheet(t);
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 3),
                                          child: Icon(Icons.more_horiz,
                                              size: 15, color: ink),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Actions ──
                    Row(
                      children: [
                        _ActionButton(
                            icon: Icons.chevron_left,
                            label: 'قبلی',
                            color: hue,
                            onTap: () => _cycle(-1)),
                        const SizedBox(width: 10),
                        _ActionButton(
                            icon: Icons.refresh,
                            label: 'ریست',
                            color: errorHue,
                            onTap: () => _confirmReset(current)),
                        const SizedBox(width: 10),
                        _ActionButton(
                            icon: Icons.edit_note,
                            label: 'افزودن',
                            color: AppPalette.emerald,
                            onTap: () => _addManual(current)),
                        const SizedBox(width: 10),
                        _ActionButton(
                            icon: Icons.track_changes,
                            label: 'تغییر هدف',
                            color: warnHue,
                            onTap: () => _changeTarget(current)),
                        const SizedBox(width: 10),
                        _ActionButton(
                            icon: Icons.chevron_right,
                            label: 'بعدی',
                            color: hue,
                            onTap: () => _cycle(1)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Page dots ──
                    // A Row lays every dot on ONE line, so with enough saved
                    // dhikrs the strip outran the page width and the tail dots
                    // (including the active one, once the user had cycled that
                    // far) were simply cut off. Wrap keeps them centred and
                    // starts a new run instead of clipping.
                    // Excluded: the dots only repeat the position the chip strip
                    // and the card's own label already announce.
                    ExcludeSemantics(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < tasbihs.length; i++)
                            Container(
                              width: i == ci ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == ci
                                    ? dotHue
                                    : dotHue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Empty state — palette-tokened circle + hint, matching the kit's surfaces.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final hue = dsContentColor(context, SectionHues.tasbih);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surfaceMuted,
              border: Border.all(color: t.outline),
            ),
            child: Icon(Icons.lens_blur,
                size: 48, color: hue.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          Text('تسبیحی وجود ندارد',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'برای افزودن ذکر، به زیربرگهٔ «اذکار» بروید و از دکمهٔ + استفاده کنید',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13), color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Counter card: the main counting UI (dhikr title, badge and the beaded
/// ring) with NO box or hero background — it sits directly on the page
/// surface. Extracted as a separate [ConsumerWidget] that watches
/// only the active [TasbihModel] via [select] — the list-level provider
/// rebuilds never touch this widget, and taps update via [ValueNotifier]
/// instead of [setState] on the parent.
///
/// Without the dark hero behind it every ink is theme-aware: the dhikr and
/// the count read [TimeThemeKit] primary / the section amber, and the amber
/// deepens on light surfaces.
class _CounterCard extends ConsumerWidget {
  final TasbihModel current;
  final ValueNotifier<bool> pressed;
  final ValueNotifier<int> displayCountNotifier;
  final bool continuePastTarget;
  final VoidCallback onContinuePastTarget;
  final VoidCallback onReset;
  final VoidCallback onAddManual;
  final VoidCallback onChangeTarget;
  final void Function(int) onCycle;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  const _CounterCard({
    required this.current,
    required this.pressed,
    required this.displayCountNotifier,
    required this.continuePastTarget,
    required this.onContinuePastTarget,
    required this.onReset,
    required this.onAddManual,
    required this.onChangeTarget,
    required this.onCycle,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only THIS active tasbih — when the provider flushes and
    // _patchState creates a new list, this select only triggers if the
    // active model actually changed (add/delete/target update).
    final active = ref.watch(tasbihProvider.select(
      (async) => async.value?.firstWhere(
        (t) => t.id == current.id,
        orElse: () => current,
      ),
    ));
    final effective = active ?? current;
    // The dhikr-title hairline follows the counter's amber now — it wore the
    // same pale hero gold the ring did.
    final hairline = dsContentColor(context, SectionHues.tasbih);

    // ── One labelled button for the whole counting surface ──
    // A bare GestureDetector publishes its OWN action node (SDK:
    // RawGestureDetector wraps the child in _GestureSemantics unless
    // excludeFromSemantics is set, and RenderSemanticsGestureHandler never
    // sets isMergingSemanticsOfDescendants), so a screen reader landed on a
    // nameless tap target and then re-read the dhikr, the count and «از N» as
    // separate stops. The detector's semantics is excluded and this node
    // carries the label, the live value and the tap action instead.
    // The «ادامه» pill inside the badge is deliberately NOT excluded — it is a
    // second control, not a duplicate of this one; dropping the whole subtree
    // (excludeSemantics: true) or merging it would have made it unreachable.
    // `child:` is built once outside the builder, so a tap only rewrites the
    // semantics config — the ValueNotifier-per-tap design of this card stays.
    return ValueListenableBuilder<int>(
      valueListenable: displayCountNotifier,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        onTapDown: (_) => pressed.value = true,
        onTapUp: (_) => pressed.value = false,
        onTapCancel: () => pressed.value = false,
        onLongPressStart: (details) {
          pressed.value = true;
          onLongPressStart?.call(details);
        },
        onLongPressEnd: (details) {
          pressed.value = false;
          onLongPressEnd?.call(details);
        },
        onLongPressCancel: () {
          pressed.value = false;
          onLongPressCancel?.call();
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          onCycle(details.primaryVelocity! > 0 ? -1 : 1);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Dhikr title — page ink, not hero cream ──
              // Long names live on TWO lines with no «بیشتر» toggle (user
              // decision, 2026-10-16) — the title grows instead of hiding the
              // rest behind an expander. The ellipsis is only a last-resort
              // guard for a custom name that outruns even two lines. Both
              // sizes sit on the shared type scale, so the reader's font
              // setting and text scale apply here too.
              // Excluded: this node's `label` is the same text, and a reader
              // would otherwise hear the dhikr twice.
              ExcludeSemantics(
                child: Text(
                  effective.targetDhikr,
                  key: ValueKey(effective.id),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(
                        context, effective.targetDhikr.length > 20 ? 17 : 23),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Amber hairline ──
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: hairline.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 6),
              // ── Completion badge + counter circle ──
              _CompletionBadge(
                displayCountNotifier: displayCountNotifier,
                current: effective,
                continuePastTarget: continuePastTarget,
                onContinuePastTarget: onContinuePastTarget,
              ),
              const SizedBox(height: 4),
              // ── Beaded counter ring ──
              // Excluded too: the count and the target are this node's `value`,
              // and the ring itself is decoration.
              ExcludeSemantics(
                child: _BeadCounterCircle(
                  displayCountNotifier: displayCountNotifier,
                  pressed: pressed,
                  current: effective,
                  continuePastTarget: continuePastTarget,
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, displayCount, surface) => Semantics(
        button: true,
        label: effective.targetDhikr,
        value:
            '${NumberFormat.formatPlain(displayCount.toDouble())} از '
            '${NumberFormat.formatPlain(effective.targetCount.toDouble())}',
        hint: 'برای افزودن یک ذکر ضربه بزنید',
        onTap: onTap,
        child: surface!,
      ),
    );
  }
}

/// Completion badge — sits in a FIXED-HEIGHT slot so the counter circle
/// below never shifts when the badge appears/disappears.
class _CompletionBadge extends StatelessWidget {
  final ValueNotifier<int> displayCountNotifier;
  final TasbihModel current;
  final bool continuePastTarget;
  final VoidCallback onContinuePastTarget;

  const _CompletionBadge({
    required this.displayCountNotifier,
    required this.current,
    required this.continuePastTarget,
    required this.onContinuePastTarget,
  });

  @override
  Widget build(BuildContext context) {
    final heroBottom = TimeThemeKit.of(context).palette.heroBottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The light face would otherwise draw the dark-theme amber on an open
    // light surface: 0xFFD4B05A on white is under 2:1, so the overshoot pill
    // was effectively unreadable in the light theme.
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    // The lifted emerald read well on the dark hero; on open light surfaces
    // the base emerald (slightly deepened) is the readable one.
    final emerald = isDark
        ? (Color.lerp(AppPalette.emerald, Colors.white, 0.45) ??
            AppPalette.emerald)
        : (Color.lerp(AppPalette.emerald, Colors.black, 0.12) ??
            AppPalette.emerald);

    return SizedBox(
      height: 44,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: displayCountNotifier,
          builder: (context, displayCount, _) {
            final targetReached = displayCount >= current.targetCount;
            final completed = targetReached && !continuePastTarget;
            final overshoot = targetReached &&
                displayCount > current.targetCount &&
                !continuePastTarget;

            // Simplest: instant switch, no scale/fade
            final child = overshoot
                ? FittedBox(
                    key: const ValueKey('overshoot'),
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: warn.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: warn.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up, color: warn, size: 17),
                              const SizedBox(width: 7),
                              Text(
                                '${NumberFormat.formatSigned(displayCount - current.targetCount)} فراتر از هدف',
                                style: TextStyle(
                                  color: warn,
                                  fontWeight: FontWeight.w800,
                                  fontSize: AppTheme.scaledFontSize(context, 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onContinuePastTarget,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppPalette.heroGold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow,
                                    color: heroBottom, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'ادامه',
                                  style: TextStyle(
                                    color: heroBottom,
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppTheme.scaledFontSize(context, 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : completed
                    ? Container(
                        key: const ValueKey('completed'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppPalette.emerald.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: emerald.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: emerald, size: 18),
                            const SizedBox(width: 8),
                            Text('تکمیل شده',
                                style: TextStyle(
                                    color: emerald,
                                    fontWeight: FontWeight.w700,
                                    // Without a size this pill kept the raw
                                    // Material body size, so it ignored the
                                    // reader's «اندازه فونت» setting while its
                                    // two sibling pills scaled — and jumped the
                                    // 44dp slot height at large scales.
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13))),
                          ],
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                        height: 30,
                      );
            return child;
          },
        ),
      ),
    );
  }
}

/// Beaded counter ring — 40 beads as the dotted track, the amber progress arc
/// with a leading bead on top, and the glowing inner button (radial gradient +
/// amber ring) holding the big count and «از N». The inner button scales
/// slightly while held.
class _BeadCounterCircle extends StatelessWidget {
  final ValueNotifier<int> displayCountNotifier;
  final ValueNotifier<bool> pressed;
  final TasbihModel current;
  final bool continuePastTarget;

  const _BeadCounterCircle({
    required this.displayCountNotifier,
    required this.pressed,
    required this.current,
    required this.continuePastTarget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      height: 224,
      child: ValueListenableBuilder<int>(
        valueListenable: displayCountNotifier,
        builder: (context, displayCount, _) {
          final targetReached = displayCount >= current.targetCount;
          final completed = targetReached && !continuePastTarget;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // The ring and the count wear the *tasbih section's* amber — the same
          // hue the «تسبیح سریع» pill and the section header use — instead of
          // the pale hero gold, which read as generic chrome beside the page's
          // colored pills. Completion keeps the app's shared emerald, so «done»
          // still speaks one language everywhere.
          const hue = SectionHues.tasbih;
          final accent = completed
              ? (isDark
                  ? mix(AppPalette.emerald, Colors.white, 0.45)
                  : mix(AppPalette.emerald, Colors.black, 0.12))
              : dsContentColor(context, hue);
          // The arc's tail, and the beads the count has not reached yet.
          final deep = mix(accent, Colors.black, isDark ? 0.30 : 0.20);
          final trail = accent.withValues(alpha: isDark ? 0.20 : 0.16);
          final progress = current.targetCount > 0
              ? (displayCount / current.targetCount).clamp(0.0, 1.0)
              : 0.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _BeadRingPainter(
                  progress: progress,
                  accent: accent,
                  deep: deep,
                  trail: trail,
                  completed: completed,
                ),
              ),
              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: pressed,
                  builder: (context, isPressed, child) => AnimatedScale(
                    scale: isPressed ? 0.95 : 1,
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    child: child,
                  ),
                  child: Container(
                    width: 176,
                    height: 176,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // The highlight sits off-centre so the button reads as a
                      // lit bead rather than a flat disc of tint.
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 1.0,
                        colors: [
                          accent.withValues(alpha: 0.32),
                          accent.withValues(alpha: 0.03),
                        ],
                      ),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.70), width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            NumberFormat.formatPlain(displayCount.toDouble()),
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 56),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              height: 1.0,
                              color: accent,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'از ${NumberFormat.formatPlain(current.targetCount.toDouble())}',
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w600,
                              // The same hue as the count, hushed — a cool grey
                              // beside the amber read like a different widget.
                              color: accent.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Paints the beaded track, the progress arc and its leading bead.
///
/// The track is two-tone: the beads the count has already reached are lit, the
/// rest stay a faint wash of the same hue, so the ring answers «how far» even
/// in the moment between two counts. The travelled arc warms from [deep] at its
/// tail to [accent] at its tip.
///
/// Repaints only when the geometry or one of the colors changes — quick mode
/// repaints this several times a second.
class _BeadRingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color deep;
  final Color trail;
  final bool completed;

  const _BeadRingPainter({
    required this.progress,
    required this.accent,
    required this.deep,
    required this.trail,
    required this.completed,
  });

  static const _beadCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final p = completed ? 1.0 : progress.clamp(0.0, 1.0);

    // `round`, so the bead under the arc's tip lights with it instead of a
    // whole bead late.
    final litCount = (p * _beadCount).round();
    final litPaint = Paint()..color = accent.withValues(alpha: 0.90);
    final restPaint = Paint()..color = trail;
    for (var i = 0; i < _beadCount; i++) {
      final a = -math.pi / 2 + (2 * math.pi * i) / _beadCount;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * radius,
        2.4,
        i < litCount ? litPaint : restPaint,
      );
    }

    if (p <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi * p,
          // A closed ring has to rejoin its own tail, or the seam at the top
          // shows a hard edge between the deep tone and the bright one.
          colors: p >= 1.0 ? [deep, accent, deep] : [deep, accent],
        ).createShader(rect),
    );

    // Leading bead riding the arc's tip.
    final end = -math.pi / 2 + 2 * math.pi * p;
    canvas.drawCircle(
      center + Offset(math.cos(end), math.sin(end)) * radius,
      4.6,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _BeadRingPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.deep != deep ||
      old.trail != trail ||
      old.completed != completed;
}

/// Compact toggle pill for «تسبیح سریع» (hold-to-count continuously).
class _QuickModePill extends StatelessWidget {
  final bool active;
  final Color hue;
  final VoidCallback onTap;

  const _QuickModePill({
    required this.active,
    required this.hue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink =
        active ? Colors.white : dsContentColor(context, hue);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? hue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? hue : hue.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: ink),
            const SizedBox(width: 5),
            Text(
              'تسبیح سریع',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Counting-speed selector for quick tasbih mode: آرام / عادی / سریع.
class _SpeedSelector extends StatelessWidget {
  final QuickCountSpeed selected;
  final Color hue;
  final ValueChanged<QuickCountSpeed> onChanged;

  const _SpeedSelector({
    required this.selected,
    required this.hue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in QuickCountSpeed.values) ...[
            if (speed != QuickCountSpeed.values.first) const SizedBox(width: 2),
            GestureDetector(
              onTap: () => onChanged(speed),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: speed == selected ? hue : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  speed.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: speed == selected
                        ? Colors.white
                        : dsContentColor(context, hue),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact stat pill flanking the quick-tasbih toggle — «هدف روزانه» on one
/// side, «این هفته» on the other. It wears the same fully-rounded, hue-tinted
/// recipe as that toggle, in its own hue. Watches the aggregated daily counters
/// itself so counting taps never rebuild the page (stats flush every 180 ms);
/// while the read is outstanding or has failed it prints a dash — an unknown
/// count is never dressed as a zero.
class _MiniStatBox extends ConsumerWidget {
  final String label;
  final Color hue;
  final bool daily;

  const _MiniStatBox({
    required this.label,
    required this.hue,
    required this.daily,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = ref.watch(tasbihStatsProvider);
    final data = stats.value;
    // The «تسبیح سریع» pill's recipe — fully rounded, hue-tinted fill, hue
    // border, hue ink — worn in this box's own hue, so the three controls of the
    // top row read as one family instead of a card flanked by two pills.
    final ink = dsContentColor(context, hue);
    final countStyle = TextStyle(
      fontSize: AppTheme.scaledFontSize(context, 15),
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hue.withValues(alpha: 0.40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: ink.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 2),
          if (data == null)
            // The old code read `.value ?? TasbihStatsData.empty`, so a failed
            // daily-total query printed «0» — indistinguishable from a day with
            // no counting. The dash says the number is unknown, and the reason
            // is spoken instead of the glyph.
            Semantics(
              label: stats.hasError
                  ? 'آمار تسبیح بارگیری نشد'
                  : 'آمار تسبیح هنوز بارگیری نشده است',
              excludeSemantics: true,
              child: Text('—', maxLines: 1, style: countStyle),
            )
          else if (daily)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: NumberFormat.formatPlain(data.todayTotal.toDouble()),
                    style: countStyle,
                  ),
                  TextSpan(
                    text:
                        ' از ${NumberFormat.formatPlain(data.sumTargets.toDouble())}',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            )
          else
            Text(
              NumberFormat.formatPlain(data.weekTotal.toDouble()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: countStyle,
            ),
        ],
      ),
    );
  }
}

/// Small action button row under the counter card.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = dsContentColor(context, color);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          // A FLOOR, not a fixed box: at the reader's largest font setting the
          // 12sp label plus the 18dp icon outran 52 dp and the text was clipped
          // by the border. minHeight keeps the row's rhythm at normal sizes and
          // lets a tall label grow instead of losing ink; alignment keeps the
          // content centred while the box is at its floor.
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink, size: 18),
              const SizedBox(height: 3),
              // Two lines, centred — never a `FittedBox(scaleDown)`: at 320 dp
              // with the reader's 1.3 text scale «تغییر هدف» cannot fit one
              // line, and shrinking it to an unreadable size is worse than
              // letting the box grow (the minHeight floor above already allows
              // that). A one-liner still renders on one line.
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
