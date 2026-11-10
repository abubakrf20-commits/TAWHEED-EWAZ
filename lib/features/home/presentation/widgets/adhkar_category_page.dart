import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart'
    as domain;
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_focus_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_list_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_timeline_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_view_selector.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/dhikr_view_prefs.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Arguments for the `/azkar/category` route: GoRouter carries them in
/// `extra` because a list of items cannot travel in the URL.
class AdhkarCategoryArgs {
  final String title;
  final PrayerPeriod period;
  final List<domain.ZikrItem> items;

  /// Set when the page is opened from a search: [highlightQuery] is the exact
  /// literal to paint and [focusId] the item whose card it lands on.
  final String highlightQuery;
  final String? focusId;

  const AdhkarCategoryArgs({
    required this.title,
    required this.period,
    required this.items,
    this.highlightQuery = '',
    this.focusId,
  });
}

/// One adhkar collection, in whichever of the three views the reader picked.
///
/// All ten sections share this page: it owns the session ([DhikrSessionController]),
/// the selector, «انتخاب همه», reset, and the appearance sheet. The three
/// views are pure renderings of the same controller, so switching modes — or
/// rotating, or changing the text size — never moves a count.
///
/// Completion and repetition counts stay in [azkarProvider] (the daily reset
/// policy lives there and is unchanged); this page only adds the session's
/// current item and its skipped set, stamped with the azkar day.
class AdhkarCategoryPage extends ConsumerStatefulWidget {
  final String title;
  final PrayerPeriod period;
  final List<domain.ZikrItem> items;
  final String highlightQuery;
  final String? focusId;

  const AdhkarCategoryPage({
    super.key,
    required this.title,
    required this.period,
    required this.items,
    this.highlightQuery = '',
    this.focusId,
  });

  @override
  ConsumerState<AdhkarCategoryPage> createState() => _AdhkarCategoryPageState();
}

class _AdhkarCategoryPageState extends ConsumerState<AdhkarCategoryPage>
    with WidgetsBindingObserver {
  late final DhikrSessionController _session;
  final _scroll = ScrollController();
  final _itemCtrl = ItemScrollController();

  /// Pending write of one item's state, so a rapid tap run is one provider
  /// call and not one DB row write per tap.
  Timer? _flush;
  final Set<String> _dirty = {};

  Timer? _advance;
  Timer? _sessionWrite;
  bool _seeded = false;
  bool _awake = false;

  static const String _wakelockOwner = 'adhkar_focus';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = DhikrSessionController(items: widget.items);
    _session.onItemChanged = _onItemChanged;
    _session.onBulkChanged = _onBulkChanged;
    unawaited(_seed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flush?.cancel();
    _advance?.cancel();
    _sessionWrite?.cancel();
    _session.dispose();
    _scroll.dispose();
    unawaited(_releaseAwake());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flushNow();
      _writeSessionNow();
    }
    if (state == AppLifecycleState.resumed) _syncAwake();
  }

  /// Reads what the app already knows about this collection and hands it to
  /// the session, including the stored current item and skipped set.
  Future<void> _seed() async {
    try {
      await ref.read(azkarProvider.future);
    } catch (e) {
      AppLogger.warning('adhkar_category_page', 'seed: $e');
    }
    if (!mounted) return;
    final notifier = ref.read(azkarProvider.notifier);
    final done = <String, bool>{};
    final counts = <String, int>{};
    for (final item in widget.items) {
      done[item.id] = notifier.isCompleted(item.id);
      final target = item.repeatCount < 1 ? 1 : item.repeatCount;
      counts[item.id] = notifier.getCount(item.id, target);
    }
    final stamp =
        await ref.read(dhikrViewPrefsProvider).readSession(widget.period.name);
    if (!mounted) return;

    var current = stamp?.current ?? 0;
    final focusId = widget.focusId;
    if (focusId != null) {
      final index = widget.items.indexWhere((e) => e.id == focusId);
      if (index >= 0) current = index;
    }
    _session.seed(
      done: done,
      counts: counts,
      skipped: stamp?.skipped ?? const {},
      current: current,
    );
    setState(() => _seeded = true);
    _syncAwake();
    if (widget.focusId != null) _scrollToCurrent();
  }

  void _onItemChanged(int index) {
    _dirty.add(widget.items[index].id);
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 250), _flushNow);
    _scheduleSessionWrite();
  }

  void _onBulkChanged() {
    _flush?.cancel();
    unawaited(_persistAll());
    _scheduleSessionWrite();
  }

  void _flushNow() {
    if (_dirty.isEmpty) return;
    final ids = _dirty.toList();
    _dirty.clear();
    unawaited(_persist(ids));
  }

  /// Writes the controller's state for [ids] through the adhkar provider, so
  /// the home page's progress card and the daily reset keep working.
  Future<void> _persist(List<String> ids) async {
    final notifier = ref.read(azkarProvider.notifier);
    try {
      for (final id in ids) {
        final index = widget.items.indexWhere((e) => e.id == id);
        if (index < 0) continue;
        final target = _session.targetAt(index);
        final entry = _session.entryAt(index);
        if (entry.done) {
          if (target > 1) {
            await notifier.completeCount(id, target);
          } else {
            await notifier.markCompleted(id);
          }
        } else {
          await notifier.setCount(id, entry.count, target);
        }
      }
    } catch (e) {
      AppLogger.warning('adhkar_category_page', 'persist: $e');
    }
  }

  Future<void> _persistAll() async {
    final notifier = ref.read(azkarProvider.notifier);
    try {
      final done = <String>[];
      for (var i = 0; i < _session.length; i++) {
        final item = widget.items[i];
        final entry = _session.entryAt(i);
        final target = _session.targetAt(i);
        if (entry.done) {
          done.add(item.id);
        } else {
          await notifier.setCount(item.id, entry.count, target);
        }
      }
      await notifier.markCompletedBatch(done);
    } catch (e) {
      AppLogger.warning('adhkar_category_page', 'bulk persist: $e');
    }
  }

  void _scheduleSessionWrite() {
    _sessionWrite?.cancel();
    _sessionWrite = Timer(const Duration(milliseconds: 250), _writeSessionNow);
  }

  void _writeSessionNow() {
    unawaited(
      ref.read(dhikrViewPrefsProvider).writeSession(
            widget.period.name,
            current: _session.currentIndex,
            skipped: {
              for (var i = 0; i < _session.length; i++)
                if (_session.isSkipped(i)) widget.items[i].id,
            },
          ),
    );
  }

  // ── focus mode services ──────────────────────────────────────────────────

  void _syncAwake() {
    final prefs = ref.read(dhikrViewPrefsProvider);
    final want = prefs.mode == DhikrViewMode.focus &&
        prefs.keepAwake &&
        mounted &&
        _seeded;
    if (want == _awake) return;
    _awake = want;
    if (want) {
      unawaited(AppWakelock.acquire(_wakelockOwner));
    } else {
      unawaited(_releaseAwake());
    }
  }

  Future<void> _releaseAwake() async {
    _awake = false;
    await AppWakelock.release(_wakelockOwner);
  }

  bool get _haptics =>
      ref.read(dhikrViewPrefsProvider).haptics &&
      ref.read(azkarSettingsProvider).hapticEnabled;

  /// The ONE cursor move, asked for by every mode when a dhikr just finished.
  ///
  /// The brief delay lets the completion state be seen before the card changes;
  /// with «رفتن خودکار» off the finished item simply waits for the reader's
  /// own «بعدی». No listener advances as well — two movers is how a dhikr got
  /// passed over without anyone tapping it.
  void _completeAdvance() {
    final prefs = ref.read(dhikrViewPrefsProvider);
    if (!prefs.autoAdvance) {
      setState(() {});
      return;
    }
    _advance?.cancel();
    _advance = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _session.advance();
      _writeSessionNow();
      _scrollToCurrent();
    });
  }

  void _tapRing() {
    final index = _session.currentIndex;
    final finished = _session.tap(index);
    if (finished) {
      _completeAdvance();
    } else if (_haptics) {
      // The view already played the light tick; nothing else to do.
    }
  }

  /// The one-tick registration: a dhikr of a hundred repetitions is said, not
  /// counted out. It completes through the controller, so the same single
  /// advance fires as when a tap run reaches its target.
  void _completeAll() {
    if (_session.complete(_session.currentIndex)) _completeAdvance();
  }

  /// «بعدی» while «رفتن خودکار» is off, and the focus view's forward swipe.
  void _stepNext() {
    _session.advance();
    _writeSessionNow();
  }

  /// The focus view's backward swipe and «قبلی» pill.
  void _stepBack() {
    final index = _session.currentIndex;
    if (index > 0) _session.goTo(index - 1);
  }

  void _scrollToCurrent({int? index}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetIndex = index ?? _session.currentIndex;
      if (_itemCtrl.isAttached) {
        _itemCtrl.jumpTo(index: targetIndex, alignment: 0.02);
        return;
      }
      if (!_scroll.hasClients) return;
      final ratio = _session.length <= 1
          ? 0.0
          : targetIndex / (_session.length - 1);
      final offset = (ratio * _scroll.position.maxScrollExtent)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _selectAll() async {
    final ok = await _confirm(
      'همهٔ اذکار این بخش انجام‌شده ثبت شوند؟',
      'همه را انجام‌شده کن',
    );
    if (ok != true) return;
    _session.markAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('همه اذکار این بخش انجام شد'),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () {
            _session.resetAll();
          },
        ),
      ));
  }

  Future<void> _clearProgress() async {
    final ok = await _confirm(
      'پیشرفت این مجموعه پاک شود؟',
      'پاک کردن',
    );
    if (ok != true) return;
    _session.resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('پیشرفت این مجموعه پاک شد'),
        duration: Duration(seconds: 1),
      ));
  }

  Future<bool?> _confirm(String message, String action) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(
          message,
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _share(domain.ZikrItem item) {
    context.push(RouteNames.azkarShare, extra: item);
  }

  Future<void> _openAppearance() async {
    final prefs = ref.read(dhikrViewPrefsProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _DhikrAppearanceSheet(prefs: prefs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = DhikrTone.of(context);
    final prefs = ref.watch(dhikrViewPrefsProvider);
    final mode = prefs.mode;
    final showArabic = ref.watch(showArabicTextProvider);
    final arabicSize =
        ref.watch(largeArabicFontProvider) || ref.watch(appFontSizeProvider) > 18
            ? 24.0
            : 18.0;

    // The wake lock follows the mode; its release must also run when the sheet
    // or the whole page goes away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAwake());

    final done = _session.doneCount;
    final total = _session.length;
    final allDone = total > 0 && done >= total;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 15)),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: allDone ? null : _selectAll,
            icon: Icon(
              Icons.select_all,
              size: 18,
              color: allDone ? AppColors.textMuted(context) : tone.gold,
            ),
            label: Text(
              allDone ? 'انجام شده' : 'انتخاب همه',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: allDone ? AppColors.textMuted(context) : tone.gold,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'بیشتر',
            onSelected: (value) {
              if (value == 'clear') unawaited(_clearProgress());
              if (value == 'look') unawaited(_openAppearance());
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'look', child: Text('ظاهر و ترتیب نمایش')),
              PopupMenuItem(
                value: 'clear',
                child: Text('پاک کردن پیشرفت این مجموعه'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          DhikrViewSelector(
            mode: mode,
            onChanged: (next) {
              unawaited(prefs.setMode(next));
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _syncAwake();
                _scrollToCurrent();
              });
            },
          ),
          Expanded(
            // The items are handed in by the caller, so the collection is
            // drawable on the first frame; seeding only adds what storage
            // remembers. No spinner, no flash, nothing to settle.
            child: switch (mode) {
                    DhikrViewMode.list => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: DhikrProgressCard(
                              tone: tone,
                              done: done,
                              total: total,
                              segments: [
                                for (var i = 0; i < _session.length; i++)
                                  _session.isDone(i)
                                      ? 2
                                      : (_session.isStarted(i) ? 1 : 0),
                              ],
                            ),
                          ),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _session,
                              builder: (context, _) => DhikrListView(
                                controller: _session,
                                tone: tone,
                                showArabic: showArabic,
                                arabicSize: arabicSize,
                                highlightQuery: widget.highlightQuery,
                                haptics: prefs.haptics,
                                itemScrollController: _itemCtrl,
                                onShare: _share,
                                onCompleteCurrent: _completeAdvance,
                              ),
                            ),
                          ),
                        ],
                      ),
                    DhikrViewMode.timeline => AnimatedBuilder(
                        animation: _session,
                        builder: (context, _) => DhikrTimelineView(
                          controller: _session,
                          tone: tone,
                          showArabic: showArabic,
                          arabicSize: arabicSize,
                          haptics: prefs.haptics,
                          scrollController: _scroll,
                          onShare: _share,
                          onCompleteCurrent: _completeAdvance,
                        ),
                      ),
                    DhikrViewMode.focus => AnimatedBuilder(
                        animation: _session,
                        builder: (context, _) => DhikrFocusView(
                          controller: _session,
                          tone: tone,
                          showArabic: showArabic,
                          arabicSize: arabicSize,
                          autoAdvance: prefs.autoAdvance,
                          onShare: _share,
                          onTapRing: _tapRing,
                          onCompleteAll: _completeAll,
                          onUndo: () => _session.undo(_session.currentIndex),
                          onSkip: () {
                            _session.skip(_session.currentIndex);
                            _session.advance();
                            _writeSessionNow();
                          },
                          onPrevious: _stepBack,
                          onNext: _stepNext,
                          onRevisitSkipped: () {
                            final skipped = _session.skippedIndexes;
                            if (skipped.isNotEmpty) {
                              _session.goTo(skipped.first);
                              _session.unskip(skipped.first);
                            }
                          },
                          onRestart: () => _session.resetAll(),
                        ),
                      ),
                  },
          ),
        ],
      ),
    );
  }
}

/// «ظاهر و ترتیب نمایش» — the same choices the settings screen offers, one tap
/// away from the collection being read.
class _DhikrAppearanceSheet extends StatelessWidget {
  const _DhikrAppearanceSheet({required this.prefs});

  final DhikrViewPrefs prefs;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) {
        final tone = DhikrTone.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نمایش اذکار',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: tone.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final option in DhikrViewMode.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () =>
                                unawaited(prefs.setMode(option)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: prefs.mode == option
                                  ? DhikrPalette.navy
                                  : null,
                              foregroundColor: prefs.mode == option
                                  ? DhikrPalette.cream
                                  : tone.ink,
                              side: BorderSide(
                                color: prefs.mode == option
                                    ? DhikrPalette.navy
                                    : tone.border,
                              ),
                            ),
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize:
                                    AppTheme.scaledFontSize(context, 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('رفتن خودکار به ذکر بعدی'),
                value: prefs.autoAdvance,
                onChanged: (v) => unawaited(prefs.setAutoAdvance(v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('لرزش هنگام شمارش و تکمیل'),
                value: prefs.haptics,
                onChanged: (v) => unawaited(prefs.setHaptics(v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('روشن ماندن صفحه در حالت تمرکز'),
                value: prefs.keepAwake,
                onChanged: (v) => unawaited(prefs.setKeepAwake(v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
