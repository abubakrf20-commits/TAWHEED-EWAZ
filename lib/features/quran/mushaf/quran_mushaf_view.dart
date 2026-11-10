import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/features/quran/api/quran_api_models.dart';
import 'package:tawheeed/features/quran/api/quran_api_service.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/quran_page_verses_cache.dart';
import 'package:tawheeed/features/quran/data/suwar.dart'; // ignore: unused_import
import 'package:tawheeed/features/quran/presentation/providers/ayah_highlight_provider.dart';
import 'package:tawheeed/features/quran/presentation/providers/quran_bookmark_provider.dart';
import 'package:tawheeed/features/quran/presentation/screens/quran_bookmarks_screen.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn_settings.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_controller.dart';
import 'package:tawheeed/features/quran/mushaf/quran_media_session.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_download_service.dart';
import 'package:tawheeed/features/quran/mushaf/quran_translation_audio_controller.dart';
import 'package:tawheeed/features/quran/mushaf/quran_translation_download_service.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/mushaf/quran_reciter_sheet.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/quran/mushaf/quran_mushaf_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/quran_surah_list_screen.dart';
import 'package:tawheeed/features/quran/mushaf/quran_search_screen.dart';
import 'package:tawheeed/features/quran/mushaf/quran_ayah_share_screen.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_download_manager.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reading.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_nav_policy.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/features/quran/services/quran_translation_service.dart';
import 'package:tawheeed/shared/services/device_status_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
part 'quran_mushaf_view_build.dart';
part 'quran_reader_header.dart';
part 'quran_page_chrome.dart';
part 'quran_mushaf_overlays.dart';
part 'quran_reader_player.dart';
part 'quran_reader_ayah_sheet.dart';
part 'quran_mushaf_small_sheets.dart';
part 'quran_mushaf_pre_download_sheet.dart';
part 'quran_mushaf_content_sheets.dart';
part 'quran_download_storage_hero.dart';
part 'quran_mushaf_qcf4_sheet.dart';

/// The new mushaf reader: Medina print (Hafs) rendered from the Quran
/// Foundation API with per-page QCF V2 fonts, talaawah playback and
/// word-by-word highlighting.
///
/// Fixed palette (theme-independent): chocolate [#4A3525], quran hue [#1F7A63],
/// cream [#FBF3E7]; UI text uses Vazirmatn, Quran glyphs use the page fonts.
class QuranMushafView extends ConsumerStatefulWidget {
  const QuranMushafView({super.key});

  @override
  QuranMushafViewState createState() => QuranMushafViewState();
}

class QuranMushafViewState extends ConsumerState<QuranMushafView>
    with WidgetsBindingObserver {
  /// Wakelock owner key for «روشن ماندن صفحه». Stable and feature-scoped so
  /// the ref-counted [AppWakelock] never drops an owner it does not know.
  static const _kKeepAwakeOwner = 'quran_reader';

  final QuranApiService _api = QuranApiService();
  late final QuranAudioController _audio;
  late final QuranTranslationAudioController _translationAudio;
  late final PageController _pageController;

  /// Highlight the tapped word's ayah, then open its action sheet — the one
  /// route the word tap, the verse end and the long press all share.
  void _selectHighlight(int s, int a) {
    setState(() {
      _navHighlightSurah = s;
      _navHighlightVerse = a;
    });
    _showVerseActions(s, a);
  }

  // Pages are fixed-size — no zoom (removed at the user's request).

  final QuranPageVersesCache _pageVerses =
      QuranPageVersesCache(api: QuranApiService.instance);

  /// QCF4 pages whose font/data failed to load (viewer reported fallback).
  /// Those pages render an inline error card with retry/download actions
  /// instead of a dead blank page. [_pageRetryTick] re-triggers the viewer.
  final Set<int> _pageFailed = {};
  final Map<int, int> _pageRetryTick = {};

  /// The page the reader is actually on. Advanced ONLY by `onPageChanged`
  /// (i.e. once the pager has settled), never by a navigation request — the
  /// two used to disagree, and every correction downstream compared against a
  /// page the reader was not on yet.
  int _currentPage = 1;

  /// Never-firing tick source for the pages that are not being read. Every
  /// page slot keeps the same wrappers no matter which page is current (see
  /// the pager's `itemBuilder`); only the listenable differs.
  static final ValueNotifier<int> _idleWordTick = ValueNotifier<int>(0);

  /// Page a programmatic `animateToPage` is heading for, or 0. Suppresses the
  /// audio follow while an explicit jump is still in flight so it cannot
  /// cancel or redirect it.
  int _pendingNav = 0;
  String? _reciterId;
  List<Mp3QuranReciter> _reciters = [];
  bool _recitersLoading = true;
  String? _recitersError;
  String _lastAudioKey = '';
  String _lastTranslationKey = '';
  bool _translationWasActive = false;

  /// Verse highlighted after a global-search navigation (no audio involved).
  /// [_navHighlightPage] anchors the highlight to the page it was set on:
  /// moving to any other page clears it (the doc always promised this).
  int? _navHighlightSurah;
  int? _navHighlightVerse;
  int? _navHighlightPage;

  /// Landscape reading lock. When true the orientation is forced to
  /// landscape while this tab is open (users with weak eyesight read the
  /// wide page with much larger glyphs). Persisted in prefs.
  bool _landscapeLock = false;

  /// «روشن ماندن صفحه» (spec C). The lock itself is held on the shared
  /// ref-counted [AppWakelock] under [_kKeepAwakeOwner], so leaving
  /// قبله‌نما or the pomodoro timer can never drop it as a side effect.
  bool _keepAwake = false;
  static const String landscapeLockPrefsKey = 'quran_landscape_lock';

  /// How a swipe crosses to the next page. Rides the pager itself, so a page
  /// never changes slot and the memoized page tree survives the whole turn.
  /// The book turn is opt-in: a fresh install slides plainly, and only a
  /// reader who chose the effect carries it.
  MushafPageTurn _pageTurn = MushafPageTurn.plain;

  /// «ظاهر صفحات راست و چپ مثل مصحف چاپی» — the printed-book page: the odd
  /// sheet leads with the surah and its folio on the right, the even sheet with
  /// the juz and its folio on the left. Off restores the pre-parity page.
  bool _pageChromeByParity = true;

  /// The page as it looked at rest — what the strip effects paint.
  ///
  /// Captured AFTER a settle (never at drag start: a GPU readback of the whole
  /// viewport landing on the first gesture frame was the turn's biggest jank
  /// source), kept warm while the reader stays on the page, and released as
  /// soon as they move on. A reader who never turns a page never pays for an
  /// image; a drag that starts before the next capture lands falls back to the
  /// live single-plane tilt.
  ui.Image? _turnLeafImage;

  /// Which page [_turnLeafImage] shows, so a settled page can reuse its own
  /// snapshot instead of regrabbing it on every settle.
  int _turnLeafPage = 0;

  /// Set while a capture is in flight, so a fast back-and-forth cannot stack
  /// two grabs and leak one of the images.
  bool _turnLeafCapturing = false;

  /// The deferred capture, so a quick settle-and-flick does not stack grabs.
  Timer? _turnCaptureTimer;

  /// The pager's own boundary.
  ///
  /// It sits around the PageView, not on a page: a boundary key on the current
  /// page would have to move to the next one as the swipe commits, and moving
  /// a GlobalKey unmounts the subtree — the exact page-tree loss this reader
  /// spent `e198fa7` removing. At rest the viewport shows one page, so the
  /// snapshot is still the sheet under the reader's finger.
  final GlobalKey _turnLeafKey = GlobalKey();

  /// The watchdog's memory for this session: once a turn has missed the frame
  /// budget, it stays on lite (fewer, wider hinges, a 1.0x capture) until the
  /// app restarts. It no longer retires the effect outright — a reader who
  /// asked for the turn keeps it.
  bool _turnLite = false;

  /// «سرعت» and «لرزش ملایم». The speed drives the turns the app starts
  /// itself; the haptic fires once when a turn commits.
  MushafTurnSpeed _pageTurnSpeed = MushafTurnSpeed.normal;
  bool _pageTurnHaptic = true;

  /// A navigation of more than one page is a leap: the strip effect would
  /// paint pages the reader never reads, so it runs as the plain slide.
  bool _multiPageNav = false;

  /// How long a leap takes. Short enough to read as one move.
  static const int _kLeapMillis = 120;

  /// Frame costs seen during the current turn, in milliseconds. The watchdog
  /// keeps twelve and then judges them: a turn that cannot hold 14 ms drops to
  /// lite, so a weak phone never fights its own animation.
  final List<double> _turnFrameCosts = [];

  /// Glyph size of the font mushaf in portrait (30) — in the landscape
  /// reading mode the page binds on width so the same size renders far
  /// larger; a dedicated size keeps both modes comfortable.
  static const double _portraitFontSize = 30;
  static const double _landscapeFontSize = 30;

  /// Fullscreen chrome. When false the header, mini player and shell bottom
  /// bar are hidden (tap the page to toggle back). Auto-enabled on landscape.
  /// The reader's live chrome state: the mini player, the shell's bottom bar
  /// and the Android system UI. Off = immersive full screen.
  bool _chromeVisible = true;

  /// Whether the header band is up. **Off by default** (reader request): the
  /// reader opens on a bare page that shows the whole mushaf, and the band
  /// appears when the settings tick is on — or on a double tap. Persisted, so
  /// the choice survives a restart.
  bool _headerVisible = false;

  /// The header's state before landscape auto-hid it, restored on the way back
  /// to portrait: the auto-hide may never overwrite the reader's own choice.
  bool _headerBeforeLandscape = true;
  bool _autoHiddenForLandscape = false;
  bool _landscape = false;

  /// Manual or timed dismissal of the mini-player panel (the chevron-down on
  /// the player, or [_playerIdleTimeout] of silence while a session is
  /// paused). Playback keeps running either way: a small resume pill takes the
  /// panel's place, and any new play-tap restores it (see [_playVerse] and
  /// [_playTranslation]).
  bool _playerDismissed = false;
  Timer? _playerIdleTimer;
  static const Duration _playerIdleTimeout = Duration(seconds: 10);

  /// Whether either player currently has something to show — a session, a
  /// load in flight, or an inline error. Mirrors the mini players' own
  /// `visible` rule, so the resume pill can never lose access to a panel the
  /// reader dismissed.
  bool get _playerPanelActive =>
      _audio.hasSession ||
      _audio.isLoading ||
      _audio.errorMessage != null ||
      _translationAudio.hasSession ||
      _translationAudio.isLoading ||
      _translationAudio.errorMessage != null;

  /// Chrome bands reserved *inside* each page, recomputed on every build.
  ///
  /// These are deliberately NOT viewport insets: the header band and the mini
  /// player are overlays, so charging them to the PageView would resize the
  /// viewport on every chrome tap and on every audio start/stop. A resize
  /// re-maps the scroll offset against a new viewport, so a swipe in progress
  /// would be cancelled or skipped. Keeping them page-internal leaves the
  /// scroll extent invariant while the page still renders exactly as before
  /// (the FittedBox fits the same reduced rect either way).
  double _pageTopInset = 0.0;
  double _pageBottomInset = 0.0;

  /// Status-bar inset, cached so toggling immersive mode (which hides the
  /// bar and would otherwise re-measure the pager) cannot change the geometry.
  double _statusBarH = 0.0;

  /// The reader's current picks into the shared palettes.
  ///
  /// Both palettes live in `mushaf_backgrounds.dart` (25 page papers, 20
  /// recited-ayah colours, no two the same colour, every one legible on every
  /// paper it can be painted on) and the picks are persisted as *colour
  /// values* by `MushafReaderPrefs` — not as indices into the lists. That is
  /// what let the duplicates be pruned: an index-keyed palette had to be
  /// append-only, so nothing could ever be removed or reordered.
  int _bgIndex = 0;

  /// Selected recited-ayah color; 0 keeps the historical emerald default.
  int _recitationColorIndex = 0;

  /// User-saved per-ayah colors, keyed 'surah:ayah'. Rebuilt from
  /// [ayahHighlightsProvider] in build; kept as the *chosen* palette colour so
  /// the swatch picker can still preselect it, and so the band on the page can
  /// be re-derived when the paper changes.
  Map<String, Color> _verseTints = const {};

  /// The same saved highlights as the opaque bands the viewer paints: each
  /// chosen colour composited over the current paper with
  /// [mushafAyahBandOn], which guarantees the band is both visible on that
  /// paper and leaves the page ink legible over it. Derived rather than stored
  /// because it depends on the paper, which the reader can change at any time.
  Map<String, Color> get _verseBands => {
        for (final entry in _verseTints.entries)
          entry.key: mushafAyahBandOn(_bgColor, entry.value),
      };

  /// Sleep timer: stops playback after the remaining duration. Off (null)
  /// when inactive. A per-second tick updates the notifier — ONLY the mini
  /// player's sleep row listens to it, so the countdown no longer rebuilds
  /// the whole reader every second.
  final ValueNotifier<Duration?> _sleepRemaining = ValueNotifier(null);
  Timer? _sleepTimer;

  /// Background color behind the transparent page image.
  Color get _bgColor =>
      kMushafBackgrounds[_bgIndex.clamp(0, kMushafBackgrounds.length - 1)]
          .color;

  /// Chrome/sheet palette: the night variant activates automatically when
  /// the chosen page background needs the cream ink — the same decision the
  /// page builder makes for its glyphs, so the chrome can never be light while
  /// the page is painted dark. No separate day/night switch.
  MushafPalette get _palette =>
      mushafNeedsLightInk(_bgColor) ? MushafPalette.night : MushafPalette.light;

  /// The recited-ayah colour the reader picked. Clamped rather than trusted:
  /// the palette is shared and can shrink between builds.
  Color get _recitationColor => kMushafRecitationColors[
          _recitationColorIndex.clamp(0, kMushafRecitationColors.length - 1)]
      .color;

  /// Name of the current recited-ayah colour, for the settings sheet subtitle.
  String get _recitationColorName => kMushafRecitationColors[
          _recitationColorIndex.clamp(0, kMushafRecitationColors.length - 1)]
      .name;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTurnTimings);
    // The debounced last-page write must survive the app going to the
    // background: the reader is disposed long after the user leaves, if at all.
    WidgetsBinding.instance.addObserver(this);
    // Warm the restored page's snapshot once the first settle has drawn, so a
    // reader with the book turn armed never drags into a cold capture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageTurn != MushafPageTurn.plain) {
        _scheduleTurnLeafCapture(delayMs: 400);
      }
    });
    // Restore the header band. Default OFF: a fresh install opens on the full
    // page, and the band is a deliberate tick (or a double tap).
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final visible = MushafReaderPrefs.loadHeaderVisibleSync(p);
      if (visible != _headerVisible) {
        setState(() => _headerVisible = visible);
      }
    });
    _pageController = PageController(
      // Last-resort sync for the committed page. It is normally redundant
      // (PageView reports the page it settles on) but the first, silent jump
      // to the restored bookmark can land before the list is attached; without
      // this the reader would sit on page 1 while the pager rests on 42.
      onAttach: (_) => _syncCurrentPageFromController(),
    );
    // Warm the last-read page's JSON + fonts immediately, in parallel with
    // the UI and the page-restore jump. Previously warming only ran from
    // _onPageChanged (after the jump), so the restored page always loaded
    // cold — the main source of the sluggish first mushaf open.
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      final saved = (p.getInt('quran_last_page') ?? 1).clamp(1, 604);
      _prefetchPages(saved);
    });
    _audio = QuranAudioController()..addListener(_onAudioChanged);
    // Lock-screen / notification controls for recitation. Started after the
    // first frame so the AudioService.init channel has a live widget tree;
    // stopped in dispose() so leaving the mushaf closes the session card.
    // The zone guard keeps plugin-internal async errors (a missing platform
    // dir in tests, an OEM shim) away from the widget tree — the session is
    // a decorative layer, never a crash source.
    // ignore: discarded_futures
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      runZonedGuarded(
        () => unawaited(QuranMediaSession.instance.start(_audio)),
        (e, st) => AppLogger.error(
            'quran_mushaf_view', 'media session failed: $e', st),
      );
    });
    _translationAudio = QuranTranslationAudioController()
      ..addListener(_onTranslationAudioChanged);
    // Restore the «تلاوت سپس ترجمه» choice (default ON — the combined mode
    // is what the user asked for; the pane toggle can turn it off). The
    // reciter id reaches the controller again on every translation tap, so
    // loading it here before the reciter list is harmless.
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      _translationAudio.setCombinedWithRecitation(
          p.getBool('quran_translation_combined') ?? true,
          reciterId: _reciterId);
    });
    // Kick the QCF4 full-download state early so the download sheet reflects
    // what is already on disk without re-downloading on fresh start.
    unawaited(Qcf4DownloadManager.instance.refreshFullyDownloaded());
    // Apply the persisted page background before the first frame when possible.
    // `backgroundFrom` also translates the retired index key, so a reader
    // upgrading from the old palette keeps the colour they had chosen;
    // `writeBack` is left to the canonical load in [_initLastPageAndReciter]
    // rather than writing prefs twice on start.
    // ignore: discarded_futures
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final index = mushafNearestBackgroundIndexOf(
          MushafReaderPrefs.backgroundFrom(p, writeBack: false));
      if (index != _bgIndex) {
        setState(() => _bgIndex = index);
        // Re-apply so the status-bar icon brightness matches the restored
        // page color.
        _applyChromeState();
      }
    });
    // Leaving the mushaf tab must restore the system chrome.
    // (ref.listen is only allowed inside build in Riverpod 3.x — use
    // listenManual for listeners that must be attached in initState.)
    ref.listenManual(shellTabIndexProvider, (prev, next) {
      if (next == 1) {
        // Back on the reader: re-assert the lock the reader chose, which the
        // branch below released for the rest of the app.
        if (_landscapeLock) {
          unawaited(SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]));
        }
        return;
      }
      // Leaving the tab releases both things the reader took from the shell:
      // the immersive chrome and the forced orientation. The reader's tab stays
      // mounted behind the others (the shell keeps visited tabs alive), so
      // dispose() cannot be relied on to do this — and while the lock stayed on,
      // every other screen in the app was rendered sideways.
      if (!_chromeVisible) {
        setState(() {
          _chromeVisible = true;
          _autoHiddenForLandscape = false;
        });
        _applyChromeState();
      }
      if (_landscapeLock) {
        unawaited(SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]));
      }
    });
    // Entering the tab: apply edge-to-edge + the status-icon style that
    // matches the (default) page background right away. Deferred out of
    // initState — it writes the immersive provider, which is not allowed
    // while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyChromeState();
    });
    _initLastPageAndReciter();
    _restoreLandscapeLock();
  }

  Future<void> _restoreLandscapeLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locked = prefs.getBool(landscapeLockPrefsKey) ?? false;
      if (!mounted) return;
      setState(() => _landscapeLock = locked);
      if (locked) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
      }
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'orientation lock failed: $e');
    }
  }

  /// «روشن ماندن صفحه» — holds/releases the shared wakelock and persists the
  /// choice, so it survives a restart (spec C).
  Future<void> _setKeepAwake(bool on) async {
    setState(() => _keepAwake = on);
    try {
      if (on) {
        await AppWakelock.acquire(_kKeepAwakeOwner);
      } else {
        await AppWakelock.release(_kKeepAwakeOwner);
      }
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'keep-awake toggle failed: $e');
    }
    unawaited(_saveQuietly(
        MushafReaderPrefs.saveKeepAwake(on), 'save keep-awake failed'));
  }

  Future<void> _setPageTurn(MushafPageTurn turn) async {
    if (!mounted || _pageTurn == turn) return;
    // The state flips synchronously, before the first await, so the settings
    // sheet's `setState` can read the new value on the same tap.
    setState(() => _pageTurn = turn);
    unawaited(_saveQuietly(
        MushafReaderPrefs.savePageTurn(turn), 'save page turn failed'));
    // The snapshot only serves the strip effects: on plain it is dead weight,
    // on the book turn it must be warm before the first drag.
    if (turn == MushafPageTurn.plain) {
      _releaseTurnLeaf();
    } else {
      _scheduleTurnLeafCapture();
    }
  }

  Future<void> _setPageTurnSpeed(MushafTurnSpeed speed) async {
    if (!mounted || _pageTurnSpeed == speed) return;
    setState(() => _pageTurnSpeed = speed);
    unawaited(_saveQuietly(MushafReaderPrefs.savePageTurnSpeed(speed),
        'save page turn speed failed'));
  }

  Future<void> _setPageTurnHaptic(bool on) async {
    if (!mounted || _pageTurnHaptic == on) return;
    setState(() => _pageTurnHaptic = on);
    unawaited(_saveQuietly(MushafReaderPrefs.savePageTurnHaptic(on),
        'save page turn haptic failed'));
  }

  Future<void> _setPageChromeByParity(bool on) async {
    if (!mounted || _pageChromeByParity == on) return;
    setState(() => _pageChromeByParity = on);
    unawaited(_saveQuietly(MushafReaderPrefs.savePageChromeByParity(on),
        'save page chrome failed'));
  }

  Future<void> _setLandscapeLock(bool locked) async {
    setState(() => _landscapeLock = locked);
    unawaited(_saveQuietly(
        SharedPreferences.getInstance()
            .then((p) => p.setBool(landscapeLockPrefsKey, locked)),
        'save landscape lock failed'));
    await SystemChrome.setPreferredOrientations(locked
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape == _landscape) return;
    _landscape = landscape;
    // Defer the chrome change out of the build phase: it writes the
    // immersive provider, which is not allowed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (landscape && _chromeVisible) {
        // Rotate to landscape → enter fullscreen automatically for reading.
        setState(() {
          _headerBeforeLandscape = _headerVisible;
          _chromeVisible = false;
          _headerVisible = false;
          _autoHiddenForLandscape = true;
        });
        _applyChromeState();
      } else if (!landscape && _autoHiddenForLandscape) {
        // Back to portrait → restore the chrome that was auto-hidden, and the
        // band exactly as the reader had it before the rotation.
        setState(() {
          _chromeVisible = true;
          _headerVisible = _headerBeforeLandscape;
          _autoHiddenForLandscape = false;
        });
        _applyChromeState();
      }
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTurnTimings);
    WidgetsBinding.instance.removeObserver(this);
    // The wakelock is ref-counted and system-wide: it must be handed back
    // even when the state is torn down mid-session.
    AppWakelock.release(_kKeepAwakeOwner);
    _sleepRemaining.dispose();
    // Restore the system chrome if we left the app fullscreen. Reading
    // providers inside dispose() is not allowed in Riverpod 3.x — the shell
    // already resets the immersive flag when the mushaf tab is disposed
    // (it watches the tab index), so only the Android system UI is touched.
    // Give the system its UI and its orientation back unconditionally.
    //
    // Both used to be gated on `!_chromeVisible`, so leaving the reader with the
    // bars showing while the landscape lock was still forcing landscape left
    // the *whole app* sideways — the reader's orientation lock had escaped the
    // reader, and the only way to undo it was to find the mushaf again.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_landscapeLock) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
    unawaited(QuranMediaSession.instance.stop());
    _audio
      ..removeListener(_onAudioChanged)
      ..dispose();
    _translationAudio
      ..removeListener(_onTranslationAudioChanged)
      ..dispose();
    // Leaving inside the debounce window must still record the page the reader
    // was on — otherwise the next open restores whatever was last written.
    _flushLastPageSave();
    _lastPageSaveTimer?.cancel();
    _turnCaptureTimer?.cancel();
    _turnLeafImage?.dispose();
    _turnLeafImage = null;
    _playerIdleTimer?.cancel();
    _dragGraceTimer?.cancel();
    _sleepTimer?.cancel();
    _api.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Toggles the fullscreen chrome (header / mini player / shell bottom bar).
  ///
  /// This is the reader's *only* gesture-driven way out of fullscreen, and it
  /// is a double tap on the page (reader request). The floating chip that used
  /// to open the header is gone: nothing may sit over the mushaf. The page
  /// instead carries its own identity in the bands it reserves (see
  /// `_PageChrome`), and the hint below names the gesture.
  void _toggleChrome() {
    // The band and the chrome travel together: a double tap gives the reader
    // the bare page, and the same gesture brings the band back. The header is
    // the only chrome drawn over the page, so its state is what the gesture is
    // about; the player and the shell follow so fullscreen stays bare.
    final show = !_headerVisible || !_chromeVisible;
    setState(() {
      _headerVisible = show;
      _chromeVisible = show;
      _autoHiddenForLandscape = false;
    });
    _applyChromeState();
    unawaited(_saveQuietly(MushafReaderPrefs.saveHeaderVisible(show),
        'save header visible failed'));
    if (!show) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'برای بازگشت، دو بار روی صفحه ضربه بزنید',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _palette.chrome,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
    }
  }

  /// «نوار بالای صفحه» — the settings tick.
  ///
  /// Showing the band always restores the normal (non-immersive) UI, so the
  /// tick can never leave the app with a hidden bottom bar and no visible way
  /// back. Hiding it leaves the player and the shell alone: the page is bare,
  /// playable and navigable, which is the reading mode the reader asked for.
  Future<void> _setHeaderVisible(bool on) async {
    setState(() {
      _headerVisible = on;
      if (on) _chromeVisible = true;
    });
    if (on) _applyChromeState();
    await _saveQuietly(
        MushafReaderPrefs.saveHeaderVisible(on), 'save header visible failed');
  }

  /// Applies the immersive state: hides/shows the shell bottom bar and the
  /// Android system UI. [forceRestore] always restores the normal UI.
  void _applyChromeState({bool forceRestore = false}) {
    final immersive = !forceRestore && !_chromeVisible;
    ref.read(quranImmersiveProvider.notifier).set(immersive);
    if (immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // The status bar is transparent over the full-bleed mushaf, so its
      // icon brightness must contrast with the page color behind it (light
      // icons on dark pages, dark icons on light pages).
      final onDarkBg = mushafNeedsLightInk(_bgColor);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: onDarkBg ? Brightness.light : Brightness.dark,
        statusBarBrightness: onDarkBg ? Brightness.dark : Brightness.light,
      ));
    }
  }

  /// Bottom sheet picking the page background behind the transparent mushaf
  /// page.
  ///
  /// The palette, the swatch grid, the full-page preview and the persistence
  /// all live in their own files; this owns only the reader's state, plus the
  /// status-bar repaint (the bar is transparent over the page, so its icon
  /// brightness follows the chosen paper).
  ///
  /// Note there is no value to read back: the sheet stays open and applies
  /// every tap through [_applyBackground], so the page you can see behind it
  /// repaints live while you choose.
  Future<void> _showBgPicker() async {
    await showMushafBackgroundPicker(
      context: context,
      palette: _palette,
      selected: _bgColor,
      recitationColor: _recitationColor,
      onPick: _applyBackground,
    );
  }

  /// Paints and saves a new page background straight away. Called on every tap
  /// in the picker, i.e. deliberately *while* the sheet is open, so it must
  /// stay confined to reader state and the system chrome.
  void _applyBackground(Color chosen) {
    if (!mounted) return;
    setState(() => _bgIndex = mushafNearestBackgroundIndexOf(chosen));
    _applyChromeState();
    unawaited(_saveQuietly(MushafReaderPrefs.saveBackground(chosen),
        'save background color failed'));
  }

  /// Bottom sheet picking the color of the recited ayah (the talaawah
  /// highlight). Identical interaction to [_showBgPicker].
  Future<void> _showRecitationColorPicker() async {
    await showMushafRecitationColorPicker(
      context: context,
      palette: _palette,
      selected: _recitationColor,
      pageBackground: _bgColor,
      onPick: _applyRecitationColor,
    );
  }

  /// Paints and saves a new recited-ayah colour straight away — see
  /// [_applyBackground] for why this has to be safe while a sheet is open.
  void _applyRecitationColor(Color chosen) {
    if (!mounted) return;
    setState(
        () => _recitationColorIndex = mushafNearestRecitationIndexOf(chosen));
    unawaited(_saveQuietly(MushafReaderPrefs.saveRecitationColor(chosen),
        'save recitation color failed'));
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initLastPageAndReciter() async {
    var lastPage = 1;
    String? savedReciter;
    try {
      final prefs = await SharedPreferences.getInstance();
      lastPage = (prefs.getInt('quran_last_page') ?? 1).clamp(1, 604);
      savedReciter = prefs.getString('quran_reciter_id_v2');
      // Read as colour values; this is where the one-time migration off the
      // retired index keys happens, and where a colour that is no longer in
      // the palette snaps to its nearest neighbour instead of resetting.
      _bgIndex = mushafNearestBackgroundIndexOf(
          MushafReaderPrefs.backgroundFrom(prefs));
      _recitationColorIndex = mushafNearestRecitationIndexOf(
          MushafReaderPrefs.recitationColorFrom(prefs));
      _keepAwake = MushafReaderPrefs.loadKeepAwakeSync(prefs);
      _pageTurn = MushafReaderPrefs.loadPageTurnSync(prefs);
      _pageChromeByParity = MushafReaderPrefs.loadPageChromeByParitySync(prefs);
      _pageTurnSpeed = MushafReaderPrefs.loadPageTurnSpeedSync(prefs);
      _pageTurnHaptic = MushafReaderPrefs.loadPageTurnHapticSync(prefs);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'read reader prefs failed: $e');
    }
    if (!mounted) return;
    // Re-arm the screen awake lock from the restored preference before the
    // first page paints, so a returning reader never loses it.
    if (_keepAwake) {
      unawaited(AppWakelock.acquire(_kKeepAwakeOwner).catchError((Object e) {
        AppLogger.warning('quran_mushaf_view', 'keep-awake acquire failed: $e');
      }));
    }

    // Restore the reader immediately. The reciter catalog is network-backed
    // and must never delay the first mushaf page.
    setState(() {
      _currentPage = lastPage;
      _bgIndex = _bgIndex.clamp(0, kMushafBackgrounds.length - 1);
    });
    _restorePageWhenReady(lastPage);

    await _loadReciters(preferredId: savedReciter);
  }

  /// Fetches the reciter catalog. Re-runnable: the picker sheet's retry
  /// button calls this when the initial (cold-start) fetch failed, instead
  /// of the old dead end that forced the reader to be re-entered.
  Future<void> _loadReciters({String? preferredId}) async {
    setState(() => _recitersLoading = true);
    var list = <Mp3QuranReciter>[];
    var listError = '';
    try {
      list = await Mp3QuranService.fetchReciters();
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'fetch reciters failed: $e');
      listError = _friendlyMessage(e);
    }
    if (!mounted) return;

    setState(() {
      _reciters = list;
      _recitersLoading = false;
      _recitersError = listError;
      if (list.isNotEmpty) {
        final sel = (preferredId != null &&
                list.any((r) => r.identifier == preferredId))
            ? preferredId
            : _preferredReciterId(list);
        _reciterId = sel;
        _audio.setReciter(sel);
      }
    });
  }

  /// Page waiting to be restored from the saved preference. Kept outside the
  /// post-frame callback so the jump is retried until the PageView actually
  /// has clients — a single postFrame check used to lose the target whenever
  /// the view remounted (fullscreen toggle, tab switch) and land on Fatiha.
  int? _pendingRestorePage;

  void _restorePageWhenReady(int page) {
    _pendingRestorePage = page;
    _tryRestorePage();
  }

  void _tryRestorePage() {
    final target = _pendingRestorePage;
    if (target == null || !mounted) return;
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryRestorePage();
      });
      return;
    }
    _pendingRestorePage = null;
    if (target > 1 && _pageController.page?.round() != target - 1) {
      _pageController.jumpToPage(target - 1);
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Default reciter: Alafasy when available, else the first in the list.
  String _preferredReciterId(List<Mp3QuranReciter> list) {
    for (final r in list) {
      if (r.identifier == 'ar.alafasy') return r.identifier;
    }
    return list.first.identifier;
  }

  String get _reciterName {
    if (_reciterId == null) return 'انتخاب قاری';
    for (final r in _reciters) {
      if (r.identifier == _reciterId) return r.name;
    }
    return 'انتخاب قاری';
  }

  /// Pending last-page write — coalesced so a fast multi-page flick issues a
  /// single prefs write (each write crosses a platform channel; one per
  /// settled page used to pile up behind rapid flips).
  Timer? _lastPageSaveTimer;
  int _lastPageSaveTarget = -1;

  /// True while the reader is showing a page for someone else's benefit (the
  /// Quran teacher's assignment preview). While set, `quran_last_page` is not
  /// written — see [goToPage].
  bool _previewOnly = false;

  /// Where the user actually was before a preview began; restored when the
  /// preview ends or the reader is disposed, so a preview can never cost the
  /// reader their place even if a write slipped through.
  int? _previewRestorePage;

  /// Ends preview mode, restoring the user's own saved page.
  ///
  /// Called when the reader is closed and when a non-preview jump arrives.
  /// Restoring (rather than only skipping the write) covers the case where a
  /// preview was interrupted — the app being killed mid-preview still leaves
  /// the correct page on disk because nothing was ever written over it.
  void _endPreview() {
    if (!_previewOnly) return;
    _previewOnly = false;
    _previewRestorePage = null;
  }

  /// True while the reader is showing a page on someone else's behalf. Exposed
  /// so a widget test can assert the preview flag latches and clears.
  @visibleForTesting
  bool get isPreviewOnly => _previewOnly;

  /// The page the user was on when the preview began (null outside a preview).
  @visibleForTesting
  int? get previewRestorePage => _previewRestorePage;

  void _onPageChanged(int index) {
    final page = index + 1;
    final previous = _currentPage;
    _currentPage = page;
    // A nav highlight (search/bookmark jump, tapped verse) belongs to the page
    // it was set on; settling on any other page is "navigating elsewhere",
    // which is where the doc always claimed the highlight ended.
    if (_navHighlightSurah != null && page != _navHighlightPage) {
      _navHighlightSurah = null;
      _navHighlightVerse = null;
      _navHighlightPage = null;
    }
    // Phase-1 audit: a settle fires on every page turn while swiping, so this
    // trail is debug-only (console in debug builds, never the release file);
    // the page itself is already persisted via quran_last_page.
    AppLogger.debug('mushaf_nav',
        'settled page $page (was $previous, ${page > previous ? 'forward' : 'back'})');
    // Debounce the bookmark write: only persist the page the user actually
    // settles on (750 ms of stillness), not every page a flick passes.
    _lastPageSaveTarget = page;
    _lastPageSaveTimer?.cancel();
    _lastPageSaveTimer = Timer(const Duration(milliseconds: 750), () {
      _lastPageSaveTimer = null;
      _flushLastPageSave();
    });
    // One light click when a turn lands — the same signal a page selector
    // gives, only when the reader asked for it and the page really moved. The
    // haptic belongs to the page change, not to the effect: a plain slide still
    // turns a page, so it clicks too.
    if (_pageTurnHaptic && page != previous) {
      unawaited(HapticFeedback.selectionClick());
    }
    // The snapshot shows the page the reader just left. Retire it now (the
    // strip effects must never paint a stale sheet) and warm the new page's
    // own snapshot once the settle has finished drawing — this is the capture
    // the NEXT drag will paint from, off the critical path of any gesture.
    if (_turnLeafPage != page && _turnLeafImage != null) {
      _releaseTurnLeaf();
    }
    if (_pageTurn != MushafPageTurn.plain) {
      _scheduleTurnLeafCapture();
    }
    if (mounted) setState(() {});
    _prefetchPages(page);
  }

  /// Writes the page the reader settled on, if a write is still pending.
  ///
  /// The debounce used to be the ONLY writer, and `dispose()` cancelled its
  /// timer — so leaving the reader (or the app) within 750 ms of a page turn
  /// dropped that page and the next open restored the page before it. Callers:
  /// the debounce itself, [didChangeAppLifecycleState] and [dispose].
  void _flushLastPageSave() {
    final target = _lastPageSaveTarget;
    if (target < 1) return;
    _lastPageSaveTarget = -1;
    _lastPageSaveTimer?.cancel();
    _lastPageSaveTimer = null;
    // A preview page belongs to the student's assignment, not to the reader's
    // own place in the mushaf. Dropping the pending write is the whole point of
    // ReaderLaunchOptions.previewOnly.
    if (_previewOnly) return;
    // The write is async: a bare try/catch around the fire-and-forget chain
    // never saw a failure, so a lost last-page save went unlogged.
    unawaited(_saveQuietly(
        SharedPreferences.getInstance()
            .then((p) => p.setInt('quran_last_page', target)),
        'save last page failed'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is the last state guaranteed before the process can be killed
    // on iOS; on Android `paused`/`hidden`/`detached` follow. Flushing on each
    // is cheap: without a pending target it is a no-op.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _flushLastPageSave();
    }
  }

  /// Warms the QCF4 page JSON (+ the fonts those pages need) for the current
  /// and neighbouring pages so flipping pages is instant instead of stalling
  /// on a network/disk fetch mid-swipe. Best-effort and never blocks the UI.
  /// ±2 gives the reader margin for a two-page flick; the data-store's RAM
  /// LRU keeps the recent window alive so revisits skip even the disk read.
  ///
  /// Ordering matters for swipe latency: the two *just-swiped-to* pages
  /// warm first (their JSON decode + font registration finishes before the
  /// user can flick again).
  ///
  /// This is re-entered on every page change and on every chrome tap, and each
  /// entry re-warms the whole window. Without [_warmInFlight] the same page was
  /// routinely warmed several times over: duplicate JSON decodes, duplicate
  /// font registrations, and both run on the UI isolate. Single-flighting
  /// collapses a window to exactly one pass, so a re-request for a page that is
  /// already being warmed shares that pass instead of starting another.
  void _prefetchPages(int center) {
    if (!mounted) return;
    // Only ever warm one window at a time. Serialising matters because the
    // expensive part (font registration) is a UI-thread operation, so several
    // windows in flight is the same work interleaved — and the older window is
    // the one about to become irrelevant as the reader keeps swiping.
    if (_prefetchActive) {
      // Re-centre and let the running pass pick it up: `_prefetchCenter` is
      // what the loop reads, and it finishes with `_finishPrefetch`, which
      // immediately re-runs if the center moved while it was in flight.
      _prefetchCenter = center;
      return;
    }
    _prefetchActive = true;
    _prefetchCenter = center;
    unawaited(_runPrefetch());
  }

  /// Pages whose warm-up is currently running, so a re-request joins the
  /// existing pass instead of duplicating it.
  final Map<int, Future<void>> _warmInFlight = <int, Future<void>>{};
  bool _prefetchActive = false;
  int _prefetchCenter = 0;

  Future<void> _runPrefetch() async {
    while (_prefetchActive) {
      final center = _prefetchCenter;
      // Deltas in swipe-latency order: the pages just swiped to warm first.
      const order = [0, 1, -1, 2, -2];
      for (final delta in order) {
        final n = center + delta;
        if (n < 1 || n > QuranApiConfig.mushafPageCount) continue;
        // An already-running warm for this page is left alone: it is doing
        // exactly this work, and duplicating it doubles UI-isolate font work.
        if (_warmInFlight.containsKey(n)) continue;
        final future = _warmQcf4Page(n);
        _warmInFlight[n] = future;
        // Drop the entry as soon as it settles so a later re-request after a
        // fresh page change warms again if needed (the data store's own LRU
        // makes an already-cached page return instantly).
        unawaited(future.whenComplete(() => _warmInFlight.remove(n)));
      }
      // Yield so the warm-ups interleave with rendering rather than occupying
      // the frame, then re-centre if a newer page arrived meanwhile.
      await Future<void>.delayed(Duration.zero);
      _prefetchActive = false;
      if (_prefetchCenter != center) {
        _prefetchActive = true;
      }
    }
  }

  Future<void> _warmQcf4Page(int page) async {
    try {
      final res = await Qcf4DataStore.instance.loadPage(page);
      if (res is! Qcf4PageLoaded) return;
      final pageData = res.page;
      final needed = <String>{
        pageData.font,
        Qcf4Config.qbsmlFontFamily,
      };
      for (final line in pageData.lines) {
        for (final w in line.words) {
          if (w.font.isNotEmpty) needed.add(w.font);
        }
      }
      // Register the page's own body font FIRST (serially): it is what the
      // incoming page paints, and its engine registration is the UI-thread
      // bottleneck — parallel registrations pile up and stall the very
      // gesture that triggered them. Ornaments/BSML follow concurrently.
      final loader = Qcf4FontLoader.instance;
      try {
        await loader.ensure(pageData.font);
      } catch (e) {
        AppLogger.warning('quran_mushaf_view', 'prefetch body font failed: $e');
      }
      final rest = needed..remove(pageData.font);
      if (rest.isNotEmpty) {
        await Future.wait(rest.map(loader.ensure));
      }
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'prefetch page fonts failed: $e');
    }
  }

  /// Public navigation used by the global search (`quranNavRequestProvider`).
  /// When [surah]/[verse] are given, that verse is highlighted until the user
  /// navigates elsewhere or starts audio playback.
  ///
  /// [previewOnly] marks every page change from this jump until the reader is
  /// closed as NOT being the user's own position: their saved `quran_last_page`
  /// is neither overwritten nor lost. «دفتر مربی قرآن» uses it to show a
  /// student's assignment page — a teacher checking page 300 must still find
  /// their own reading page next time.
  void goToPage(int page, {int? surah, int? verse, bool previewOnly = false}) {
    if (!mounted) return;
    if (previewOnly && !_previewOnly) {
      // Remember where the user really was, once, before the preview moves.
      _previewRestorePage = _currentPage;
    } else if (!previewOnly && _previewOnly) {
      // Any ordinary jump ends the preview: from here on, pages are the
      // reader's own again and are saved normally.
      _endPreview();
    }
    _previewOnly = previewOnly;
    setState(() {
      _navHighlightSurah = surah;
      _navHighlightVerse = verse;
      _navHighlightPage = page;
    });
    // Through the single entry point so an in-flight user drag still wins and
    // the audio follow is suppressed for this jump.
    _goToPage(page, MushafNavSource.explicitJump, animate: true);
  }

  /// The single place allowed to move the pager.
  ///
  /// Everything that wants to change the page — the audio follow, the global
  /// search, the surah list, bookmark restore, the retry sheet — goes through
  /// here. The *whether* is delegated to [MushafNavPolicy] (pure, unit-tested);
  /// this method is only the *how*: clamp, then move the controller.
  ///
  /// The committed page ([_currentPage]) is advanced only by the pager itself
  /// once it has settled. Writing it here instead (as this method used to) moved
  /// the truth ahead of the scroll position, so every correction downstream
  /// compared against a page the reader was not on yet.
  void _goToPage(
    int page,
    MushafNavSource source, {
    bool animate = false,
  }) {
    if (!_pageController.hasClients) {
      _retryGoToPageWhenReady(page, source, animate: animate);
      return;
    }
    final policy = MushafNavPolicy(
      currentPage: _currentPage,
      userDragging: _userDragging,
      dragGraceActive: _dragGraceTimer != null,
      pendingNavPage: _pendingNav,
    );
    final index =
        policy.resolve(source, page, pageCount: QuranApiConfig.mushafPageCount);
    if (index == null) {
      // A follow that was dropped (drag in progress, grace window, or a jump
      // in flight) used to vanish without a trace — the exact gap that made
      // the release log look unordered during playback.
      // Phase-1 audit: debug-only like the settle trail above — a dropped
      // follow is routine during drags, not a persisted diagnostic.
      if (source == MushafNavSource.audioFollow && page != _currentPage) {
        AppLogger.debug(
            'mushaf_nav',
            'audio follow → page $page dropped (dragging: $_userDragging, '
                'grace: ${_dragGraceTimer != null}, pendingNav: $_pendingNav)');
      }
      return;
    }
    final target = index + 1;
    // A navigation that actually resolves supersedes a restore that has not
    // landed yet: its post-frame retry would otherwise drag the reader back to
    // the saved page after the jump.
    _pendingRestorePage = null;
    // Phase-1 audit: debug-only like the settle trail — programmatic jumps
    // (search/bookmark/audio-follow) fire per page turn during playback.
    AppLogger.debug('mushaf_nav',
        'nav → page $target ($source, ${animate ? 'animate' : 'jump'})');
    if (animate) {
      _pendingNav = target;
      // A jump of more than one page is a leap, not a turn: the effect would
      // churn through pages nobody reads in between, so those get the short
      // plain slide the spec asks for.
      final leap = (target - _currentPage).abs() > 1;
      _pageController
          .animateToPage(
        index,
        duration:
            Duration(milliseconds: leap ? _kLeapMillis : _pageTurnSpeed.millis),
        curve: Curves.easeInOutCubic,
      )
          .whenComplete(() {
        if (_pendingNav == target) _pendingNav = 0;
        if (leap && _multiPageNav) {
          if (mounted) setState(() => _multiPageNav = false);
          _multiPageNav = false;
        }
      });
      if (leap && !_multiPageNav) setState(() => _multiPageNav = true);
    } else {
      _pendingNav = 0;
      _pageController.jumpToPage(index);
    }
  }

  /// A navigation arriving before the pager is attached (first frame, a
  /// fullscreen toggle rebuilding the view) used to be dropped without a trace.
  /// Retry a bounded number of frames, then say so in the log.
  void _retryGoToPageWhenReady(
    int page,
    MushafNavSource source, {
    required bool animate,
    int attempt = 0,
  }) {
    const maxAttempts = 10;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Checked before `hasClients`: a disposed controller asserts on it.
      if (!mounted) return;
      if (_pageController.hasClients) {
        _goToPage(page, source, animate: animate);
        return;
      }
      if (attempt + 1 >= maxAttempts) {
        AppLogger.warning('quran_mushaf_view',
            'nav → page $page dropped: pager not attached after $maxAttempts frames');
        return;
      }
      _retryGoToPageWhenReady(page, source,
          animate: animate, attempt: attempt + 1);
    });
  }

  /// Adopts the pager's resting page as the committed one. Used on attach to
  /// recover the silent restore jump; during normal reading the pager itself
  /// drives [_currentPage] through [PageController.onPageChanged].
  void _syncCurrentPageFromController() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final settled = (page.round() + 1).clamp(1, QuranApiConfig.mushafPageCount);
    if (settled == _currentPage) return;
    _currentPage = settled;
    if (mounted) setState(() {});
  }

  /// Set while the user has a finger on the pager. Maintained by
  /// [_onScrollNotification]; the audio follow is suspended for as long as it
  /// is true, plus [_dragReleaseGrace] afterwards so a flick that has just
  /// ended is not immediately overridden. Read by [MushafNavPolicy] through
  /// [_goToPage].
  bool _userDragging = false;
  Timer? _dragGraceTimer;
  static const _dragReleaseGrace = Duration(milliseconds: 400);

  /// Feeds the drag/settle signal that gates the audio follow. Deliberately
  /// does NOT write the bookmark or call `setState` on a settle notification —
  /// [_onPageChanged] already did that for the real page change, and
  /// recomputing the prefetch window here would cancel and restart it on every
  /// single scroll event.
  ///
  /// Always returns `false`: this only observes, it must not swallow the
  /// notification the pager relies on.
  /// The effect actually painted: the reader's pick, unless the system asks for
  /// reduced motion.
  MushafPageTurn get _effectivePageTurn {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return MushafPageTurn.plain;
    }
    return _pageTurn;
  }

  /// Defers the page snapshot to a moment no gesture is in flight.
  ///
  /// A `toImage` of the whole viewport is a GPU readback of millions of
  /// pixels; running it on the frame a drag starts was the turn's biggest
  /// hitch. Captures are instead scheduled from a settle (see
  /// [_onPageChanged]), so by the time the reader grabs the page the image is
  /// already warm.
  void _scheduleTurnLeafCapture({int delayMs = 220}) {
    _turnCaptureTimer?.cancel();
    _turnCaptureTimer = Timer(Duration(milliseconds: delayMs), () {
      _turnCaptureTimer = null;
      if (!mounted) return;
      unawaited(_captureTurnLeaf());
    });
  }

  /// Snapshots the page at rest. The strip effects paint this instead of N
  /// live copies of a widget subtree; a capture that never lands simply leaves
  /// the live tilt in place, so a turn is never slower than it was.
  Future<void> _captureTurnLeaf() async {
    if (_pageTurn == MushafPageTurn.plain || _turnLeafCapturing || !mounted) {
      return;
    }
    // The settled page already has its snapshot: regrabbing it on every
    // settle would burn the readback for an identical image.
    if (_turnLeafImage != null && _turnLeafPage == _currentPage) return;
    final boundary = _turnLeafKey.currentContext?.findRenderObject();
    if (boundary is! rendering.RenderRepaintBoundary) return;
    final page = _currentPage;
    _turnLeafCapturing = true;
    try {
      // 1.25x is enough for a page that is moving; the dpr of a modern phone
      // would triple the bytes for pixels nobody can see mid-turn. Lite mode
      // drops to 1.0x — fewer bytes on the phones that need fewer bytes.
      final ratio = _turnLite ? 1.0 : 1.25;
      final image = await boundary.toImage(pixelRatio: ratio);
      if (!mounted || page != _currentPage) {
        image.dispose();
        return;
      }
      _turnLeafImage?.dispose();
      _turnLeafPage = page;
      setState(() => _turnLeafImage = image);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'page snapshot failed: $e');
    } finally {
      _turnLeafCapturing = false;
    }
  }

  /// Judge a turn's frames: the effect drops to lite and stays there.
  void _onTurnTimings(List<FrameTiming> timings) {
    if (!_userDragging || _pageTurn == MushafPageTurn.plain) return;
    for (final t in timings) {
      _turnFrameCosts.add(t.buildDuration.inMicroseconds / 1000.0 +
          t.rasterDuration.inMicroseconds / 1000.0);
    }
    if (_turnFrameCosts.length < 12) return;
    final avg =
        _turnFrameCosts.reduce((a, b) => a + b) / _turnFrameCosts.length;
    _turnFrameCosts.clear();
    if (avg <= 14 || !mounted) return;
    if (_turnLite) return;
    setState(() {
      _turnLite = true;
      // Re-grab at 1.0x: the expensive image is exactly what lite exists to
      // stop paying for.
      _releaseTurnLeaf();
    });
    _scheduleTurnLeafCapture(delayMs: 120);
    AppLogger.warning('quran_mushaf_view',
        'page turn is lite: ${avg.toStringAsFixed(1)} ms/frame');
  }

  void _releaseTurnLeaf() {
    final image = _turnLeafImage;
    if (image == null) {
      _turnLeafPage = 0;
      return;
    }
    _turnLeafImage = null;
    _turnLeafPage = 0;
    // The painter may still be holding it in the frame that is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    if (mounted) setState(() {});
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      // A programmatic animateToPage/jump also emits ScrollStart, so only a
      // *drag* counts as the user taking over. No capture here on purpose: a
      // GPU readback on the first gesture frame is the jank this reader
      // exists to avoid. If the pre-warmed snapshot is missing, the live
      // single-plane tilt paints instead.
      if (n.dragDetails != null) {
        _userDragging = true;
        _dragGraceTimer?.cancel();
        _dragGraceTimer = null;
        // Whatever settle-capture is pending is now too late to matter.
        _turnCaptureTimer?.cancel();
        _turnCaptureTimer = null;
      }
    } else if (n is ScrollEndNotification) {
      if (_userDragging) {
        _userDragging = false;
        _dragGraceTimer?.cancel();
        _dragGraceTimer = Timer(_dragReleaseGrace, () {
          _dragGraceTimer = null;
        });
      }
      // The snapshot stays warm for the page the reader settled on (the
      // settle path in [_onPageChanged] retires/regrabs it); releasing here
      // would make every second drag paint without the strips.
    }
    return false;
  }

  // ── Audio hooks ───────────────────────────────────────────────────────────

  /// Hides the mini-player panel without touching playback. The resume pill
  /// takes its place whenever a session still exists.
  void _dismissPlayerPanel() {
    _playerIdleTimer?.cancel();
    if (!_playerDismissed) setState(() => _playerDismissed = true);
  }

  /// Brings the panel back (resume pill tap, or any new play command).
  void _restorePlayerPanel() {
    _playerIdleTimer?.cancel();
    if (_playerDismissed) setState(() => _playerDismissed = false);
  }

  /// Auto-hide (user: hide the player bar after non-use): with a session
  /// loaded but nothing playing, the panel tucks itself away after
  /// [_playerIdleTimeout] so an idle reader gets the page back. A playing
  /// session never hides; the resume pill and any play-tap restore it.
  void _schedulePlayerAutoHide() {
    _playerIdleTimer?.cancel();
    if (_playerDismissed || !_chromeVisible) return;
    final playing = _audio.isPlaying || _translationAudio.isPlaying;
    final hasSession = _audio.hasSession || _translationAudio.hasSession;
    if (!hasSession || playing) return;
    _playerIdleTimer = Timer(_playerIdleTimeout, () {
      if (mounted && !_playerDismissed) {
        setState(() => _playerDismissed = true);
      }
    });
  }

  void _onAudioChanged() {
    if (!mounted) return;
    _schedulePlayerAutoHide();
    // Only follow while a session is actually playing — the controller emits
    // notifications on stop/reset where chapter/verse fall back to defaults
    // (1:1), which used to yank the reader back to Surah Al-Fatiha.
    if (!_audio.hasSession) return;
    final key = _audio.activeVerseKey;
    if (key == _lastAudioKey) return;
    _lastAudioKey = key;
    // Always rebuild when the active verse changes so the highlighted ayah
    // follows the recitation even when it advances to the NEXT verse on the
    // same page (previously only a page change triggered a rebuild, so the
    // recited ayah never got coloured).
    setState(() {});
    try {
      final page = getPageNumber(_audio.chapter, _audio.verse);
      // The follow is a *proposal*, not a command: MushafNavPolicy makes it
      // yield to the user while they are dragging (and right after a flick) and
      // to an explicit jump in flight. Two writers on one PageController is
      // what made a swipe land somewhere neither the reader nor the recitation
      // asked for.
      if (page != _currentPage) {
        _goToPage(page, MushafNavSource.audioFollow, animate: true);
      }
    } catch (e) {
      AppLogger.warning(
          'quran_mushaf_view', 'recitation page follow failed: $e');
    }
  }

  void _playVerse(int chapter, int verse) {
    // Playback is the strongest signal that the panel is wanted again.
    _restorePlayerPanel();
    // Priority rule: recitation wins over a running translation session —
    // stop the translation player and move the lock-screen card over to the
    // recitation source so the OS controls never mirror a stopped player.
    if (_translationAudio.hasSession) {
      _translationAudio.stop();
      // ignore: discarded_futures
      unawaited(QuranMediaSession.instance.start(_audio).catchError(
          (Object e) => AppLogger.warning(
              'quran_mushaf_view', 'session rebind failed: $e')));
    }
    unawaited(_audio.playVerse(chapter, verse));
  }

  // ── Translation audio hooks ───────────────────────────────────────────────

  void _onTranslationAudioChanged() {
    if (!mounted) return;
    _schedulePlayerAutoHide();
    // Rebuild only when the active verse or session changes (not on every
    // position tick — the mini player listens to the controller directly).
    final hasSession = _translationAudio.hasSession;
    final key = '${_translationAudio.chapter}:${_translationAudio.verse}';
    if (key != _lastTranslationKey || hasSession != _translationWasActive) {
      _lastTranslationKey = key;
      _translationWasActive = hasSession;
      setState(() {});
      if (hasSession) {
        try {
          final page =
              getPageNumber(_translationAudio.chapter, _translationAudio.verse);
          // Same rule as the tilawah follow: the user's gesture wins.
          if (page != _currentPage) {
            _goToPage(page, MushafNavSource.audioFollow, animate: true);
          }
        } catch (e) {
          AppLogger.warning(
              'quran_mushaf_view', 'translation page follow failed: $e');
        }
      }
    }
  }

  Future<void> _playTranslation(int surah, int verse) async {
    // A fresh translation tap restores the panel it may have auto-hidden.
    _restorePlayerPanel();
    // Combined «تلاوت سپس ترجمه» resolves its recitation half through the
    // reader's current reciter, so the two halves stay in step with the
    // «تلاوت» button even if the reciter changed since the last toggle.
    _translationAudio.setCombinedWithRecitation(
        _translationAudio.combinedWithRecitation,
        reciterId: _reciterId);
    // Priority rule: a fresh translation tap wins over recitation — stop the
    // recitation player, then hand the lock-screen card to the translation
    // source (its own notification channel, «ترجمهٔ فارسی» album line).
    if (_audio.hasSession) {
      await _audio.stop();
      try {
        await QuranMediaSession.instance
            .start(_translationAudio, kind: QuranMediaSource.translation);
      } catch (e) {
        AppLogger.warning('quran_mushaf_view', 'session rebind failed: $e');
      }
    }
    await _translationAudio.playVerse(surah, verse);
  }

  /// «تلاوت سپس ترجمه» for the ayah audio — persisted so the choice survives
  /// a restart. The controller flag is the single source of truth for the
  /// pane toggle's check.
  void _setTranslationCombined(bool value) {
    _translationAudio.setCombinedWithRecitation(value, reciterId: _reciterId);
    // ignore: discarded_futures
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('quran_translation_combined', value);
      } catch (e) {
        AppLogger.warning(
            'quran_mushaf_view', 'save combined translation pref failed: $e');
      }
    }());
  }

  /// Bottom sheet shown when tapping an ayah: play, tafsir, or translation —
  /// the user explicitly chooses; tapping never starts the talaawah by itself.
  Future<void> _showVerseActions(int surah, int verse) async {
    if (!mounted) return;
    final palette = _palette;
    final surahName = getSurahNameArabic(surah);
    final accent = palette.accent;
    // Chips: page, juz and revelation place — the same facts the header
    // carries, but for the verse the reader tapped.
    final page = getPageNumber(surah, verse);
    final juz = getCurrentJuzNumberForPage(page);
    final makki = _isSurahMakki(surah);
    // Active state for the bookmark tile, read from the same stream the
    // header and the bookmarks screen use. The note rides the same row, so the
    // note tile can open pre-filled (report §7.4).
    final bookmarkRows = ref.watch(quranBookmarksProvider).value;
    // Unknown is not «not bookmarked»: while the stream has not emitted (or
    // failed), the sheet must not promise «نشان‌گذاری» for an ayah whose mark
    // already exists. The action itself stays safe either way — the DAO's
    // toggle reads the row at tap time — but the wording is kept neutral.
    final bookmarkKnown = bookmarkRows != null;
    final matches = (bookmarkRows ?? const [])
        .where((b) => b.surah == surah && b.ayah == verse);
    final bookmarked = matches.isNotEmpty;
    final existingNote = matches.isEmpty ? null : matches.first.note;
    // The note cell's state: whether opening it means writing or editing keeps
    // the icon in step with the stored text (report §7.4).
    final hasNote = existingNote != null && existingNote.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: MushafSheetScroll(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'سورهٔ $surahName — آیهٔ ${NumberFormat.toLatin('$verse')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.surfaceText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _VerseChip(
                      label: 'صفحه ${NumberFormat.toLatin('$page')}',
                      color: accent),
                  _VerseChip(
                      label: 'جزء ${NumberFormat.toLatin('$juz')}',
                      color: accent),
                  _VerseChip(label: makki ? 'مکیّه' : 'مدنیّه', color: accent),
                ],
              ),
              const SizedBox(height: 12),
              // One row of six (reader request): the three two-cell rows left
              // the glyphs small and the sheet tall. The visible labels are one
              // word each — six cells share the sheet — and `semanticLabel`
              // carries the full wording for screen readers.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AyahActionTile(
                      icon: Icons.play_circle_outline,
                      label: 'تلاوت',
                      semanticLabel: 'پخش تلاوت این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _playVerse(surah, verse);
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: Icons.menu_book_rounded,
                      label: 'تفسیر',
                      semanticLabel: 'تفسیر این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_showTafsirSheet(surah, verse));
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: Icons.translate,
                      label: 'ترجمه',
                      semanticLabel: 'ترجمهٔ این صفحه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_showTranslationSheet());
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: Icons.volume_up_rounded,
                      label: 'صوتی',
                      semanticLabel: 'پخش ترجمهٔ صوتی',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _playTranslation(surah, verse);
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: _verseTints.containsKey('$surah:$verse')
                          ? Icons.border_color_rounded
                          : Icons.format_color_fill_rounded,
                      label: 'هایلایت',
                      semanticLabel: _verseTints.containsKey('$surah:$verse')
                          ? 'ویرایش هایلایت این آیه'
                          : 'هایلایت رنگی این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_showAyahHighlightPicker(surah, verse));
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: bookmarked
                          ? Icons.bookmark
                          : bookmarkKnown
                              ? Icons.bookmark_add_outlined
                              : Icons.bookmark_border,
                      label: bookmarked ? 'حذف نشان' : 'نشان',
                      semanticLabel: bookmarked
                          ? 'حذف از نشان‌ها'
                          : bookmarkKnown
                              ? 'نشان‌گذاری این آیه'
                              : 'تغییر نشان این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final added = await ref
                            .read(quranBookmarkDaoProvider)
                            .toggle(surah, verse);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(added
                              ? 'به نشان‌ها افزوده شد'
                              : 'از نشان‌ها حذف شد'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // A second row of the same icon tiles (user request): sharing
              // and noting the ayah are icon actions too, so they sit below
              // the six exactly like the ones above — the two full-width
              // subtitled rows are gone. The share range is still chosen on
              // the next screen, and `semanticLabel` carries that wording for
              // screen readers; the note cell keeps its state, flipping to
              // the edit glyph once the ayah carries a note.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AyahActionTile(
                      icon: Icons.share_outlined,
                      label: 'اشتراک',
                      semanticLabel: 'اشتراک‌گذاری این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_showRangeShareSheet(surah, verse));
                      },
                    ),
                  ),
                  Expanded(
                    child: _AyahActionTile(
                      icon: hasNote
                          ? Icons.edit_note_rounded
                          : Icons.note_add_outlined,
                      label: 'یادداشت',
                      semanticLabel: hasNote
                          ? 'ویرایش یادداشت این آیه'
                          : 'یادداشت این آیه',
                      tone: accent,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_editVerseNote(surah, verse, existingNote));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Writes, edits or clears the note on the tapped ayah's bookmark
  /// (report §7.4).
  ///
  /// Saving on an ayah that is not marked yet marks it — the table has carried
  /// the `note` column from the start, and a note would have nowhere to live
  /// without the row. Saving an empty note keeps the mark and clears only the
  /// note, so erasing text never silently costs the reader their position.
  Future<void> _editVerseNote(
      int surah, int verse, String? existingNote) async {
    final palette = _palette;
    // The writer owns its own controller (see [_VerseNoteDialog]); `null` is the
    // cancel, an empty string is a deliberate clear.
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _VerseNoteDialog(palette: palette, existingNote: existingNote),
    );
    if (text == null || !mounted) return;
    final stored =
        await ref.read(quranBookmarkDaoProvider).setNote(surah, verse, text);
    if (!mounted) return;
    final hadNote = existingNote != null && existingNote.trim().isNotEmpty;
    final message = stored != null
        ? 'یادداشت ذخیره شد'
        : hadNote
            ? 'یادداشت پاک شد'
            : 'آیه نشان‌گذاری شد';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Persistent ayah highlight (Audit 8.12) ──────────────────────────────

  static Color _hexToColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return const Color(0xFF0E7A5A);
    return Color(0xFF000000 | value);
  }

  /// Whether the mushaf marks [surah] as revealed at Makkah. The surah table
  /// carries `place` ("Makkah" / "Madinah") — the same field the index rows
  /// render, so the two can never disagree.
  static bool _isSurahMakki(int number) {
    // The top-level table is `surah`; the parameter must not shadow it.
    const List table = surah;
    for (final s in table) {
      if ((s['id'] as int?) == number) {
        return (s['place'] as String?)?.toLowerCase() == 'makkah';
      }
    }
    return false;
  }

  static String _colorToHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Fire-and-forget a prefs/DB write whose result nobody reads. A
  /// `.then((p) => p.setInt(...))` chain completes as `Future<bool>`, which a
  /// void `catchError` cannot legally follow — flattening to `Future<void>`
  /// first keeps the failure path both compilable and logged.
  Future<void> _saveQuietly(Future<Object?> op, String what) =>
      op.then<void>((_) {}).catchError((Object e) {
        AppLogger.warning('quran_mushaf_view', '$what: $e');
      });

  /// Swatch sheet saving a permanent marker color on one ayah (Drift
  /// `ayah_highlight_table`). The pick renders as a soft band on every page
  /// until it is removed here.
  ///
  /// Shares the recited-ayah palette and grid with the reader's own picker, so
  /// a swatch can never mean one colour here and a different one there.
  Future<void> _showAyahHighlightPicker(int surah, int verse) async {
    final palette = _palette;
    final current = _verseTints['$surah:$verse'];
    final dao = ref.read(ayahHighlightDaoProvider);
    final colors =
        kMushafRecitationColors.map((c) => c.color).toList(growable: false);
    final names =
        kMushafRecitationColors.map((c) => c.name).toList(growable: false);
    await showMushafSheet<void>(
      context: context,
      palette: palette,
      title: 'هایلایت این آیه',
      subtitle: 'رنگ نشانه روی آیه ذخیره می‌شود و تا حذف نکردن در مصحف می‌ماند',
      contentBuilder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MushafSwatchGroup(
            palette: palette,
            colors: colors,
            names: names,
            selected: current,
            keyPrefix: 'ayah_highlight_swatch',
            onPick: (i) {
              Navigator.of(sheet).pop();
              unawaited(_saveQuietly(
                  dao.setColor(surah, verse, _colorToHex(colors[i])),
                  'save ayah highlight failed'));
            },
          ),
          if (current != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              key: const ValueKey('ayah_highlight_remove'),
              onPressed: () {
                Navigator.of(sheet).pop();
                unawaited(_saveQuietly(
                    dao.remove(surah, verse), 'remove ayah highlight failed'));
              },
              icon: Icon(Icons.highlight_off, color: palette.accent),
              label: Text('حذف هایلایت',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: palette.surfaceText)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reading settings sheet ───────────────────────────────────────────────

  /// One place for every reading-view customization: page background, the
  /// recited-ayah color, the landscape big-print lock and the fullscreen
  /// toggle.
  ///
  /// Each row carries its current pick as a subtitle. The sheet used to be
  /// three bare labels with no indication of what was set — and the page you
  /// would check against is exactly what the sheet covers.
  Future<void> _showReadingSettingsSheet() async {
    final palette = _palette;
    await showMushafSheet<void>(
      context: context,
      palette: palette,
      title: 'تنظیمات مطالعه',
      footer: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size.fromHeight(40),
        ),
        child: Text('بستن',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                color: palette.surfaceText)),
      ),
      contentBuilder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Card 1: the page's own colours ─────────────────────────────
          _settingsCard(
            palette,
            title: 'نمای صفحه',
            children: [
              MushafSettingRow(
                leading: _swatch(
                  kMushafBackgrounds[
                          _bgIndex.clamp(0, kMushafBackgrounds.length - 1)]
                      .color,
                ),
                icon: Icons.palette_outlined,
                title: 'رنگ پس‌زمینهٔ صفحه',
                value: kMushafBackgrounds[
                        _bgIndex.clamp(0, kMushafBackgrounds.length - 1)]
                    .name,
                palette: palette,
                onTap: () {
                  Navigator.of(sheet).pop();
                  unawaited(_showBgPicker());
                },
              ),
              MushafSettingRow(
                leading: _swatch(_recitationColor),
                icon: Icons.format_color_fill_rounded,
                title: 'رنگ آیهٔ در حال تلاوت',
                value: _recitationColorName,
                palette: palette,
                onTap: () {
                  Navigator.of(sheet).pop();
                  unawaited(_showRecitationColorPicker());
                },
              ),
            ],
          ),
          // ── Card 2: how a swipe turns the page ───────────────────────────
          // The card owns a local StatefulBuilder because the sheet's content
          // is built once: the reader's `setState` repaints the page behind the
          // sheet, never the sheet itself.
          StatefulBuilder(
            builder: (context, setSheetState) => _settingsCard(
              palette,
              title: 'ورق زدن صفحه',
              children: [
                MushafPageTurnSection(
                  palette: palette,
                  selected: _pageTurn,
                  speed: _pageTurnSpeed,
                  haptic: _pageTurnHaptic,
                  // The system's reduced-motion switch wins over the stored
                  // choice: the cards stay visible, the effect does not run.
                  reduceMotion:
                      MediaQuery.maybeOf(context)?.disableAnimations ?? false,
                  onSelected: (turn) {
                    unawaited(_setPageTurn(turn));
                    setSheetState(() {});
                  },
                  onSpeed: (speed) {
                    unawaited(_setPageTurnSpeed(speed));
                    setSheetState(() {});
                  },
                  onHaptic: (on) {
                    unawaited(_setPageTurnHaptic(on));
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
          // ── Card 3: how the reader presents itself ─────────────────────
          _settingsCard(
            palette,
            title: 'نمایش',
            children: [
              _settingsSwitch(
                palette,
                icon: Icons.menu_book_outlined,
                title: 'ظاهر صفحات راست و چپ مثل مصحف چاپی',
                subtitle: 'شمارهٔ صفحه و نشانهٔ سرصفحه در لبهٔ بیرونی',
                value: _pageChromeByParity,
                onChanged: _setPageChromeByParity,
              ),
              _settingsSwitch(
                palette,
                icon: Icons.screen_rotation_alt_outlined,
                title: 'حالت افقی — فونت بزرگ‌تر',
                subtitle: 'خروج: ضربه روی صفحه',
                value: _landscapeLock,
                onChanged: (v) {
                  Navigator.of(sheet).pop();
                  unawaited(_setLandscapeLock(v));
                },
              ),
              // The tick the reader asked for: off by default, so the mushaf
              // opens as a whole page; on, the band is up and stays up across
              // restarts. A double tap on the paper does the same thing.
              _settingsSwitch(
                palette,
                icon: Icons.view_headline_rounded,
                title: 'نوار بالای صفحه',
                subtitle: 'خاموش: صفحهٔ کامل قرآن، بدون نوار',
                value: _headerVisible,
                onChanged: (v) {
                  Navigator.of(sheet).pop();
                  unawaited(_setHeaderVisible(v));
                },
              ),
              _settingsSwitch(
                palette,
                icon: Icons.light_mode_outlined,
                title: 'روشن ماندن صفحه',
                subtitle: 'در حین خواندن و پخش تلاوت',
                value: _keepAwake,
                onChanged: _setKeepAwake,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A titled card grouping the settings rows (spec C's cards).
  Widget _settingsCard(
    MushafPalette palette, {
    required String title,
    required List<Widget> children,
  }) {
    // Material, not a bare Container: the rows are ListTiles and they paint
    // their ink splashes on the nearest Material ancestor, which a coloured
    // DecoratedBox would swallow.
    return Material(
      color: palette.accent.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppPalette.heroGold, AppPalette.heroGoldDeep],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.surfaceText,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  /// The circular colour swatch in front of the two colour rows — the same
  /// selection language the pickers use, so the current pick is visible
  /// without opening them.
  Widget _swatch(Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: AppPalette.heroGold.withValues(alpha: 0.85),
          width: 2,
        ),
      ),
    );
  }

  /// A dense switch row with an IconTile-sized leading icon.
  Widget _settingsSwitch(
    MushafPalette palette, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      // One line per row keeps the sheet inside a 640dp phone without
      // scrolling.
      dense: true,
      visualDensity: VisualDensity.compact,
      secondary: Icon(icon, color: palette.accent),
      title: Text(title,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily, color: palette.surfaceText)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: palette.surfaceMuted),
      ),
      value: value,
      activeThumbColor: palette.accent,
      onChanged: onChanged,
    );
  }

  // ── Sharing ────────────────────────────────────────────────────────────────

  // Share one ayah or a consecutive range, each with or without the Persian
  // translation.

  /// Bottom sheet: pick a consecutive range and share with/without translation.
  Future<void> _showRangeShareSheet(int surah, int anchorVerse) async {
    await _openAyahShare(surah, anchorVerse, anchorVerse);
  }

  /// Opens the آیهٔ مشترک screen (text + image, like حصن المسلم) for the
  /// given surah and an initial ayah range.
  Future<void> _openAyahShare(int surah, int from, int to) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranAyahShareScreen(
          surah: surah,
          initialFrom: from,
          initialTo: to,
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Pager geometry is INVARIANT ──────────────────────────────────────────
    // The PageView's box must never change while the reader is open: a resize
    // re-maps the scroll offset against a new viewport, which is what used to
    // make a swipe "skip" a page (the reader jumped back to the page the drag
    // started from). The chrome — header band and mini player — is therefore
    // NEVER a viewport inset. It is an overlay (see the `Positioned`s below)
    // and the space it covers is reserved *inside the page* instead
    // (`_pageTopInset` / `_pageBottomInset` are passed into `_buildPage`).
    // Scrolling geometry therefore depends only on the system insets, which
    // change on rotation/immersive-toggle alone, never on a tap or on audio
    // starting.
    final mq = MediaQuery.of(context);
    final audioPlayerVisible = _chromeVisible &&
        (_audio.hasSession || _audio.isLoading || _audio.errorMessage != null);
    final translationPlayerVisible =
        _chromeVisible && _translationAudio.hasSession;
    final anyPlayerVisible = audioPlayerVisible || translationPlayerVisible;
    // Applied inside the page, not to the viewport: see the note above.
    // Only the band reserves space on the page. With it down the page is the
    // whole mushaf; the player is an overlay and never charges the pager.
    _pageTopInset = _headerVisible ? _kReaderHeaderBand + _statusBarH : 0.0;
    _pageBottomInset = anyPlayerVisible ? 72.0 : 0.0;
    final bottomInset = mq.padding.bottom;
    // The mushaf tab is full-bleed (the shell skips the top SafeArea for it),
    // so the status-bar inset is handled here: the page background extends
    // behind the status bar and the header band sits below it. Read from the
    // window view: the shell's SafeArea strips the top inset from the ambient
    // MediaQuery, so mq.padding.top is always 0 here. Cached per orientation
    // (see `_statusBarH`) so an immersive toggle cannot resize the pager.
    _statusBarH = MediaQueryData.fromView(View.of(context)).padding.top;

    // Persistent ayah highlights (Audit 8.12 wiring): watching the whole
    // table as an AsyncValue means a save/remove re-renders exactly the
    // pages whose tint fingerprint changed — the viewer memo invalidates
    // through its render key. Stream failures leave the map empty.
    final highlightRows = ref.watch(ayahHighlightsProvider).value ??
        const <AyahHighlightTableData>[];
    _verseTints = {
      for (final h in highlightRows)
        '${h.surah}:${h.ayah}': _hexToColor(h.colorHex),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            // A drag is the user asserting a page change; the notification
            // stream is what lets [_goToPage] know to stand down. PageView has
            // no notificationListener of its own, so it is wrapped here.
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: RepaintBoundary(
                key: _turnLeafKey,
                child: PageView.builder(
                  controller: _pageController,
                  // Pre-build the neighbour pages so a flip never constructs
                  // a whole page mid-gesture; each page also paints in its
                  // own layer so scrolling one page never re-rasterizes others.
                  allowImplicitScrolling: true,
                  // Forgiving flip: settle on the next/previous page once the
                  // drag passes ~30% of the page (or any release velocity),
                  // instead of the stock ~40%-of-the-viewport that made users
                  // swipe two or three times per flip.
                  physics: const ForgivingPageScrollPhysics(),
                  // With allowImplicitScrolling already true the pager caches one
                  // extra viewport on each side, so a swipe never has to
                  // construct (load JSON + fonts + measure) a whole page
                  // mid-gesture — the main source of flip jank. Made explicit to
                  // pin the behavior.
                  scrollCacheExtent:
                      const rendering.ScrollCacheExtent.viewport(1),
                  onPageChanged: _onPageChanged,
                  itemCount: QuranApiConfig.mushafPageCount,
                  itemBuilder: (context, index) {
                    final page = index + 1;
                    // The recitation highlight (active word/ayah) is the only
                    // reason a page has to rebuild on a timer, and it only
                    // matters on the page being read. The rebuild used to wrap
                    // the whole PageView, so every word of the recitation
                    // re-laid-out every built page — including the neighbours,
                    // whose text cannot change. Listening on the active page
                    // alone keeps the highlight live while a swipe no longer
                    // competes with a full page re-layout per word.
                    //
                    // EVERY page keeps the same wrapper chain regardless of
                    // whether it is current: only the listenable differs. Giving
                    // the incoming page a different widget type at the moment
                    // `onPageChanged` fired used to unmount its
                    // `Qcf4PageViewer` (and the memoized, already-laid-out page
                    // tree) in the middle of the drag, so the framework re-shaped
                    // the whole page on a gesture frame.
                    return MushafTurningPage(
                      controller: _pageController,
                      index: index,
                      mode: _multiPageNav
                          ? MushafPageTurn.plain
                          : _effectivePageTurn,
                      pageCount: QuranApiConfig.mushafPageCount,
                      palette: _palette,
                      leafImage: _turnLeafImage,
                      lite: _turnLite,
                      child: ValueListenableBuilder<int>(
                        valueListenable: page == _currentPage
                            ? _audio.wordTick
                            : _idleWordTick,
                        builder: (context, _, __) =>
                            RepaintBoundary(child: _buildPage(page)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Chrome overlay — header pinned to the top. The page now extends
        // behind it (its own `_pageTopInset` keeps the glyphs clear), so the
        // band is free to appear/disappear without touching the pager.
        // The band slides down from under the status bar on the way in. It is
        // REMOVED from the tree when hidden — an invisible band would still
        // answer taps and still be read out by a screen reader, which is the
        // opposite of a bare page.
        if (_headerVisible)
          Positioned(
            top: _statusBarH,
            left: 0,
            right: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => FractionalTranslation(
                translation: Offset(0, t - 1),
                child: Opacity(opacity: t, child: child),
              ),
              child: _buildReaderHeader(),
            ),
          ),
        // No escape-hatch control sits over the page any more (reader
        // request). Fullscreen is a bare page carrying only its own identity,
        // printed in the bands the page reserves (`_PageChrome`), and the
        // double tap on the page is the way back to the chrome.
        //
        // Chrome overlay — mini player at the bottom, or its resume pill when
        // the reader tucked the bar away. Playback keeps running either way;
        // the whole cluster belongs to the visible chrome, so fullscreen stays
        // bare.
        if (_chromeVisible && _playerDismissed && _playerPanelActive)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: _ResumePlayerPill(
                palette: _palette,
                onTap: _restorePlayerPanel,
              ),
            ),
          )
        else if (_chromeVisible &&
            !_playerDismissed &&
            _translationAudio.hasSession)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _translationAudio,
              builder: (context, _) => _TranslationMiniPlayer(
                audio: _translationAudio,
                palette: _palette,
                onToggle: () => unawaited(_translationAudio.togglePlayPause()),
                onNext: () => unawaited(_translationAudio.nextVerse()),
                onPrev: () => unawaited(_translationAudio.prevVerse()),
                onStop: () => unawaited(_translationAudio.stop()),
                onContinuous: (v) => _translationAudio.setContinuous(v),
                onCombined: _setTranslationCombined,
                onSetSpeed: (r) =>
                    unawaited(_translationAudio.setPlaybackRate(r)),
                onHide: _dismissPlayerPanel,
              ),
            ),
          )
        else if (_chromeVisible && !_playerDismissed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _audio,
              builder: (context, _) => _MiniPlayer(
                audio: _audio,
                palette: _palette,
                onToggle: () => unawaited(_audio.togglePlayPause()),
                onNext: () => unawaited(_audio.nextVerse()),
                onPrev: () => unawaited(_audio.prevVerse()),
                onStop: () => unawaited(_audio.stop()),
                onContinuous: (v) => _audio.setContinuous(v),
                onSetRepeat: (n) => _audio.setRepeatCount(n),
                onSetSpeed: (r) => unawaited(_audio.setPlaybackRate(r)),
                onPlayChapter: () =>
                    unawaited(_audio.playChapter(_audio.chapter)),
                onShowRepeatRange: _showRepeatRangeDialog,
                onShowSleepTimer: _showSleepTimerDialog,
                sleepRemaining: _sleepRemaining,
                onShowReciter: _showReciterSheet,
                reciterName: _reciterId != null ? _reciterName : '',
                onHide: _dismissPlayerPanel,
              ),
            ),
          ),
      ],
    );
  }

  /// Spec-A header: a slim two-cluster band that carries the page identity
  /// (surah / juz / page) so nothing has to float over the glyphs. The old
  /// bar crammed reciter + repeat + settings + overflow into one row, which
  /// truncated the reciter name to «ماهر ال…»; those controls now live in the
  /// player (reciter, speed, repeat) and the overflow menu (settings,
  /// verse-follow, downloads, translation & tafsir).
  /// The Arabic name of the surah that opens [page], or '' when the bundled
  /// page data cannot be read. Shared by the header and the fullscreen corner
  /// identity so the two can never print different names.
  String _surahNameFor(int page) {
    try {
      final data = getPageData(page);
      return getSurahNameArabic((data.first['surah'] as int?) ?? 1);
    } catch (e) {
      AppLogger.warning(
          'quran_mushaf_view', 'surah name lookup failed for page $page: $e');
      return '';
    }
  }

  /// The juz [page] belongs to, or 0 when the lookup fails. Same single source
  /// as [_surahNameFor].
  int _juzFor(int page) {
    try {
      return getCurrentJuzNumberForPage(page);
    } catch (e) {
      AppLogger.warning(
          'quran_mushaf_view', 'juz lookup failed for page $page: $e');
      return 0;
    }
  }

  Widget _buildReaderHeader() {
    final surahName = _surahNameFor(_currentPage);
    final juz = _juzFor(_currentPage);
    // The page's own bookmark state, straight from the same stream the
    // bookmarks screen lists — no second source of truth. Before the stream
    // emits (or after it fails) the chip keeps its neutral inactive face; it
    // is a door to the bookmark list, not a claim about the page, and the
    // list screen owns the honest error state.
    final bookmarkRows = ref.watch(quranBookmarksProvider).value;
    final bookmarked = bookmarkRows?.any(
          (b) => getPageNumber(b.surah, b.ayah) == _currentPage,
        ) ??
        false;
    return _ReaderHeader(
      palette: _palette,
      page: _currentPage,
      surahName: surahName,
      juz: juz,
      bookmarked: bookmarked,
      landscape: _landscapeLock,
      onIndex: _showSurahIndex,
      onSearch: _showQuranSearch,
      // The bar's bookmark button opens the LIST — that is what the reader
      // expects and what used to live here. Marking the current page moved
      // to the overflow menu, which also keeps the ayah sheet's own
      // «نشان‌گذاری» as the per-ayah path.
      onBookmark: _showBookmarkList,
      onOrientation: () => unawaited(_toggleOrientation()),
      onOverflow: _showOverflowMenu,
      onGoTo: _showGoToDialog,
    );
  }

  /// The header's rotate button (reader request): flips the reader between the
  /// locked landscape view and portrait. It writes the SAME preference the
  /// reading-settings switch does, so the two controls can never disagree —
  /// and it survives a restart through the existing restore path.
  Future<void> _toggleOrientation() => _setLandscapeLock(!_landscapeLock);

  /// Fires the overflow menu; extracted so the header widget can call it
  /// without knowing about popup internals.
  void _showSurahIndex() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranSurahListScreen(
          onSelect: (surahNumber) async {
            final page = await _resolveSurahPage(surahNumber);
            if (!mounted) return;
            _goToPage(page, MushafNavSource.explicitJump, animate: true);
          },
        ),
      ),
    );
  }

  /// Bookmark the page the reader is on (empty state of the bookmark screen
  /// says «روی آیه نگه دارید», but a whole-page marker is the one gesture
  /// that survives a page flip).
  void _togglePageBookmark() {
    // Reuse the existing ayah-level bookmark flow anchored on the page's
    // first verse, so behaviour and storage stay exactly as they are.
    try {
      final data = getPageData(_currentPage);
      final surah = (data.first['surah'] as int?) ?? 1;
      final verse = (data.first['ayah'] as int?) ?? 1;
      _showVerseActions(surah, verse);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'page bookmark failed: $e');
    }
  }

  /// The header's overflow menu (spec B): a card of IconTile rows opened
  /// from the ⋮ button. The header itself only carries index / search / the
  /// page identity / bookmark / ⋮, so this is where the rest of the chrome
  /// lives.
  ///
  /// Reading settings moved in here on purpose — it used to have its own
  /// pinned tune button, and that plus the reciter chip and the repeat
  /// toggle is what truncated the reciter name to «ماهر ال…» on a phone.
  /// Verse-follow («لیست آیات») stays grouped with settings; the two data
  /// sections (downloads, translation & tafsir) sit under a divider.
  void _showOverflowMenu() {
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? Offset.zero
        : box.localToGlobal(Offset.zero) + Offset(0, box.size.height);
    showMenu<String>(
      context: context,
      color: _palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        anchor.dx,
        anchor.dy,
      ),
      items: [
        _menuItem(
          Icons.tune_rounded,
          'تنظیمات مطالعه',
          onTap: _showReadingSettingsSheet,
        ),
        _menuItem(
          Icons.view_list_outlined,
          'لیست آیات (پیروی از تلاوت)',
          onTap: _showVerseFollowSheet,
        ),
        const PopupMenuDivider(),
        _menuItem(
          Icons.download_for_offline_outlined,
          'دانلود برای آفلاین',
          onTap: _showPreDownloadSheet,
        ),
        _menuItem(
          Icons.auto_stories,
          'ترجمه و تفاسیر',
          onTap: _showContentSheet,
        ),
        // Optional additions (spec B): bookmark list + page share — both
        // cheap, they reuse existing routes and the existing share screen.
        const PopupMenuDivider(),
        _menuItem(
          Icons.bookmarks_outlined,
          'نشان‌ها',
          onTap: _showBookmarkList,
        ),
        _menuItem(
          Icons.bookmark_add_outlined,
          'نشان‌گذاری این صفحه',
          onTap: _togglePageBookmark,
        ),
        _menuItem(
          Icons.share_outlined,
          'اشتراک‌گذاری صفحه',
          onTap: () => unawaited(_showRangeShareSheet(_pageSurah, _pageVerse)),
        ),
      ],
    );
  }

  PopupMenuEntry<String> _menuItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return PopupMenuItem<String>(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: _palette.surfaceText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w500,
                color: _palette.surfaceText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// First surah on the current page (share/bookmark anchor).
  int get _pageSurah {
    try {
      return (getPageData(_currentPage).first['surah'] as int?) ?? 1;
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'page surah lookup failed: $e');
      return 1;
    }
  }

  /// First ayah on the current page (share/bookmark anchor).
  int get _pageVerse {
    try {
      return (getPageData(_currentPage).first['ayah'] as int?) ?? 1;
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'page ayah lookup failed: $e');
      return 1;
    }
  }

  /// The bookmark list, in the reader's own palette (report §6.1) — it used to
  /// open on the app's time theme, so a night reader cross-faded into the light
  /// theme. A tap jumps to the page and highlights it.
  void _showBookmarkList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranBookmarksScreen(
          palette: _palette,
          onGoToPage: (s, a) {
            try {
              final page = getPageNumber(s, a);
              _goToPage(page, MushafNavSource.explicitJump, animate: true);
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted) {
                  setState(() {
                    _navHighlightSurah = s;
                    _navHighlightVerse = a;
                    _navHighlightPage = page;
                  });
                }
              });
            } catch (e) {
              AppLogger.warning(
                  'quran_mushaf_view', 'bookmark page lookup failed: $e');
            }
          },
        ),
      ),
    );
  }

  Future<int> _resolveSurahPage(int surahNumber) async {
    try {
      final lookup = await _api.lookupPages(chapterNumber: surahNumber);
      if (lookup.pages.isNotEmpty) {
        return lookup.pages.keys.reduce((a, b) => a < b ? a : b);
      }
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'surah page lookup failed: $e');
    }
    try {
      return getPageNumber(surahNumber, 1);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'surah page lookup failed: $e');
      return 1;
    }
  }

  Future<int> _resolveJuzPage(int juzNumber) async {
    try {
      final lookup = await _api.lookupPages(juzNumber: juzNumber);
      if (lookup.pages.isNotEmpty) {
        return lookup.pages.keys.reduce((a, b) => a < b ? a : b);
      }
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'juz page lookup failed: $e');
    }
    try {
      return getJuzStartPage(juzNumber);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'juz page lookup failed: $e');
      return 1;
    }
  }

  Future<void> _showGoToDialog() async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => _GoToDialog(
        palette: _palette,
        onResolveSurah: _resolveSurahPage,
        onResolveJuz: _resolveJuzPage,
      ),
    );
    if (page != null && mounted) {
      _goToPage(page, MushafNavSource.explicitJump, animate: true);
    }
  }

  /// Switches the active reciter (used by the reciter picker inside the
  /// offline-download sheet and the header picker).

  Future<void> _showRepeatRangeDialog() async {
    final startVerseCtrl = TextEditingController(
        text: _audio.hasRepeatRange
            ? _audio.rangeStartVerse.toString()
            : _audio.verse.toString());
    final endVerseCtrl = TextEditingController(
        text: _audio.hasRepeatRange
            ? _audio.rangeEndVerse.toString()
            : _audio.verse.toString());
    final countCtrl = TextEditingController(
        text: _audio.hasRepeatRange ? _audio.rangeRepeatCount.toString() : '5');
    var sc = _audio.hasRepeatRange
        ? (_audio.rangeStartChapter ?? 1)
        : _audio.chapter;
    var ec =
        _audio.hasRepeatRange ? (_audio.rangeEndChapter ?? 1) : _audio.chapter;
    int? svRes, evRes, cntRes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تکرار برای حفظ', textDirection: TextDirection.rtl),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_audio.hasRepeatRange)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: AppPalette.heroGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.repeat_on_rounded,
                            size: 16, color: AppPalette.heroGold),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                'تکرار فعلی: ${_audio.rangeStartChapter}:${_audio.rangeStartVerse} تا ${_audio.rangeEndChapter}:${_audio.rangeEndVerse} ×${_audio.rangeRepeatCount} (باقی ${_audio.rangeRemaining})',
                                style: const TextStyle(fontSize: 11))),
                      ],
                    ),
                  ),
                // Surah pickers: a dropdown of named surahs instead of asking
                // the reader to type a chapter number they have to look up.
                DropdownButtonFormField<int>(
                  initialValue: sc,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'از سوره'),
                  items: [
                    for (var n = 1; n <= 114; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text(
                          '$n. ${getSurahNameArabic(n)}',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(fontFamily: AppTheme.fontFamily),
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => sc = v ?? sc),
                ),
                TextField(
                    controller: startVerseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'از آیه', hintText: '255'),
                    textDirection: TextDirection.ltr),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: ec,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تا سوره'),
                  items: [
                    for (var n = 1; n <= 114; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text(
                          '$n. ${getSurahNameArabic(n)}',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(fontFamily: AppTheme.fontFamily),
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => ec = v ?? ec),
                ),
                TextField(
                    controller: endVerseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'تا آیه', hintText: '260'),
                    textDirection: TextDirection.ltr),
                const SizedBox(height: 10),
                TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'تعداد تکرار',
                        hintText: '5',
                        helperText: 'مثلا 5، 20 یا 1000 بار'),
                    textDirection: TextDirection.ltr),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final quick in const [5, 10, 20, 100])
                      ActionChip(
                        label: Text('$quick'),
                        onPressed: () {
                          countCtrl.text = '$quick';
                          setDialogState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (_audio.hasRepeatRange)
              TextButton(
                  onPressed: () {
                    _audio.clearRepeatRange();
                    Navigator.pop(ctx, false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تکرار محدوده حذف شد')));
                  },
                  child: const Text('حذف تکرار')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final sv = int.tryParse(startVerseCtrl.text.trim());
                final ev = int.tryParse(endVerseCtrl.text.trim());
                final cnt = int.tryParse(countCtrl.text.trim()) ?? 5;
                if (sv == null || ev == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('لطفا شماره آیه را درست وارد کنید')));
                  return;
                }
                if (sv < 1 || ev < 1 || cnt < 1) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('مقادیر نامعتبر: تکرار حداقل 1 بار')));
                  return;
                }
                try {
                  if (sv > getVerseCount(sc) || ev > getVerseCount(ec)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('شماره آیه برای این سوره نامعتبر است')));
                    return;
                  }
                } catch (e) {
                  AppLogger.warning(
                      'quran_mushaf_view', 'validate repeat range failed: $e');
                }
                svRes = sv;
                evRes = ev;
                cntRes = cnt;
                Navigator.pop(ctx, true);
              },
              child: const Text('شروع تکرار'),
            ),
          ],
        ),
      ),
    );
    startVerseCtrl.dispose();
    endVerseCtrl.dispose();
    countCtrl.dispose();
    if (confirmed == true && svRes != null) {
      _applyRepeatRange(sc, svRes!, ec, evRes!, cntRes!);
    }
  }

  // ── Sleep timer ──────────────────────────────────────────────────────────
  // Stops playback after a chosen duration (useful for listening before bed).
  void _startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepRemaining.value = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _sleepTimer?.cancel();
        return;
      }
      final remaining = _sleepRemaining.value;
      if (remaining == null) {
        _sleepTimer?.cancel();
        return;
      }
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _sleepTimer?.cancel();
        _sleepRemaining.value = null;
        if (_audio.hasSession) unawaited(_audio.stop());
        if (_translationAudio.hasSession) unawaited(_translationAudio.stop());
        // Stopping the audio tears the mini player down through the audio
        // controllers' own notifications; no reader rebuild needed here.
      } else {
        _sleepRemaining.value = next;
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining.value = null;
  }

  Future<void> _showSleepTimerDialog() async {
    final minutes = <int>[5, 10, 15, 20, 30, 45, 60];
    await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _palette.surface,
      // Height cap + scrollable body: the chip Wrap grows if more durations
      // are ever added — never overflow (landscape viewport).
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: MushafSheetScroll(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    _sleepRemaining.value != null
                        ? 'توقف پخش بعد از ${_fmtSleep(_sleepRemaining.value!)}'
                        : 'تایمر خواب — پخش پس از چند دقیقه متوقف شود؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in minutes)
                      ActionChip(
                        label:
                            Text('${NumberFormat.normalizeDigits('$m')} دقیقه'),
                        backgroundColor: _palette.surface,
                        labelStyle: TextStyle(fontFamily: AppTheme.fontFamily),
                        onPressed: () => Navigator.pop(ctx, m),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_sleepTimer != null)
                  TextButton.icon(
                    onPressed: () {
                      _cancelSleepTimer();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.timer_off_outlined, size: 18),
                    label: Text('لغو تایمر خواب',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).then((m) {
      if (m != null) _startSleepTimer(Duration(minutes: m));
    });
  }

  static String _fmtSleep(Duration d) {
    final totalMin = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${NumberFormat.normalizeDigits('$totalMin')}:${NumberFormat.normalizeDigits(sec.toString().padLeft(2, '0'))}';
  }

  void _applyRepeatRange(int sc, int sv, int ec, int ev, int cnt) {
    _audio.setRepeatRange(sc, sv, ec, ev, cnt);
    try {
      final page = getPageNumber(sc, sv);
      _goToPage(page, MushafNavSource.explicitJump, animate: true);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'repeat-range jump failed: $e');
    }
    _audio.playVerse(sc, sv);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('تکرار از $sc:$sv تا $ec:$ev به تعداد $cnt بار فعال شد')));
  }

  Future<void> _changeReciter(String id) async {
    setState(() => _reciterId = id);
    _audio.setReciter(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quran_reciter_id_v2', id);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'save reciter pref failed: $e');
    }
  }

  Future<void> _showPreDownloadSheet() async {
    var currentSurah = 1;
    try {
      final data = getPageData(_currentPage);
      currentSurah = (data.first['surah'] as int?) ?? 1;
    } catch (e) {
      AppLogger.warning(
          'quran_mushaf_view', 'download sheet surah lookup failed: $e');
    }
    final reciterName = _reciterId != null ? _reciterName : '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PreDownloadSheet(
        palette: _palette,
        audioService: QuranAudioDownloadService.instance,
        reciters: _reciters,
        reciterId: _reciterId,
        reciterName: reciterName,
        currentSurah: currentSurah,
        onReciterChanged: _changeReciter,
      ),
    );
  }

  /// Bottom sheet with the Persian translation of the current page's verses.
  Future<void> _showTranslationSheet() async {
    final verses = await _loadVersesFor(_currentPage);
    if (!mounted) return;
    if (verses.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('صفحه هنوز بارگذاری نشده است.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TranslationSheet(
        initialPage: _currentPage,
        initialVerses: verses,
        palette: _palette,
        loadPage: _loadVersesFor,
        // The mushaf underneath turns with the sheet, so closing it never drops
        // the reader on a page the sheet was no longer showing.
        onPageChanged: goToPage,
      ),
    );
  }

  /// One page's verses for the translation sheet — through the extracted
  /// cache (wave-3 #4, slice 2).
  Future<List<QuranVerse>> _loadVersesFor(int page) =>
      _pageVerses.versesForPage(page);

  /// Bottom sheet listing the verses of the current surah. While playing, the
  /// list auto-scrolls to keep the recited ayah highlighted in view.
  Future<void> _showVerseFollowSheet() async {
    // Determine the active surah: the recited one when a session is live,
    // otherwise the last tapped verse, otherwise the first surah on the
    // current page.
    int surah;
    if (_audio.hasSession) {
      surah = _audio.chapter;
    } else if (_navHighlightSurah != null) {
      surah = _navHighlightSurah!;
    } else {
      try {
        final rows = getPageData(_currentPage);
        surah = (rows.isNotEmpty && rows.first['surah'] is int)
            ? (rows.first['surah'] as int)
            : 1;
      } catch (e) {
        AppLogger.warning('quran_mushaf_view', 'read page data failed: $e');
        surah = 1;
      }
    }
    final count = getVerseCount(surah);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VerseFollowSheet(
        surah: surah,
        verseCount: count,
        palette: _palette,
        audio: _audio,
        translationAudio: _translationAudio,
      ),
    );
  }

  /// Bottom sheet with the download manager for the hosted content
  /// (Persian translation + tafsir databases).
  Future<void> _showContentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MushafContentSheet(palette: _palette),
    );
  }

  /// Bottom sheet with the tafsir of one verse (long-press on a word).
  Future<void> _showTafsirSheet(int surah, int verse) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MushafTafsirSheet(
        surah: surah,
        verse: verse,
        palette: _palette,
      ),
    );
  }

  Future<void> _showReciterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.surface,
      // Shared sheet geometry (spec): radius 30 top corners.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      isScrollControlled: true,
      builder: (ctx) => ReciterPickerSheet(
        palette: _palette,
        reciters: _reciters,
        loading: _recitersLoading,
        error: _recitersError,
        onRetry: () => unawaited(_loadReciters()),
        selectedId: _reciterId,
        onSelect: (pick) async {
          setState(() => _reciterId = pick.id);
          _audio.setReciter(pick.id);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('quran_reciter_id_v2', pick.id);
          } catch (e) {
            AppLogger.warning(
                'quran_mushaf_view', 'save reciter pref failed: $e');
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Arabic-text search inside the mushaf (local FTS, no internet needed).
  Future<void> _showQuranSearch() async {
    final selection = await Navigator.of(context).push<(int, int)>(
      MaterialPageRoute<(int, int)>(
        builder: (_) => QuranSearchScreen(palette: _palette),
      ),
    );
    if (selection == null || !mounted) return;
    final (surah, verse) = selection;
    int page;
    try {
      page = getPageNumber(surah, verse);
    } catch (e) {
      AppLogger.warning('quran_mushaf_view', 'selection nav failed: $e');
      page = 1;
    }
    goToPage(page, surah: surah, verse: verse);
  }
}

String bundledArabicVerse(int surah, int verse) {
  for (final row in quran) {
    if (row['sora'] == surah && row['aya_no'] == verse) {
      final text = row['aya_text_emlaey'] ?? row['aya_text'] ?? '';
      return text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return '';
}

/// Page-flip physics tuned for the mushaf reader.
///
/// The stock [PageScrollPhysics] only settles on the next page after ~40% of
/// the viewport has been dragged (or a fast fling), so readers often had to
/// swipe two or three times to turn a single page. Here the drag itself is
/// eased once it passes 30% of a page (the page is already mostly turned),
/// and release always completes the flip — with a spring that starts stiff
/// and critically damped so the settle feels snappy, never rubbery.
class ForgivingPageScrollPhysics extends PageScrollPhysics {
  const ForgivingPageScrollPhysics({super.parent});

  @override
  ForgivingPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ForgivingPageScrollPhysics(parent: buildParent(ancestor));

  /// Stiffer, critically damped: the flip reaches its target quickly and
  /// stops without a visible bounce (contrast the stock bouncy settle).
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.55,
        stiffness: 380,
        ratio: 1.05,
      );

  /// The settle target is computed from the pager's page-aligned position
  /// (see [createBallisticSimulation]), never outside the scroll range, so
  /// the stock edge clamping needs no strengthening here.
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) => 0.0;

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // A fling always completes the flip in its own direction; a slow release
    // settles on the nearest page. The two `velocity < 0` branches are RTL on
    // purpose: this reader's axis direction is left, so a forward swipe
    // arrives here with a negative pixel velocity. Do not "correct" them to
    // stock's form — that reverses every flick.
    final viewport =
        position.viewportDimension > 0 ? position.viewportDimension : 1.0;
    final page = position.pixels / viewport;
    final targetPage = velocity.abs() > minFlingVelocity
        ? (velocity < 0 ? page + 1 : page - 1)
        : page.roundToDouble();
    // The spring's end value is PIXELS, so the chosen page must be converted
    // back. Handing it a page index is not a small error: at the last page
    // (192960 px / 320 px = 603) it springs toward 603 px — page 3 — which is
    // exactly the reported "opening the mushaf jumps back to a page I read
    // before". applyBoundaryConditions is disabled above, so the clamp here is
    // the only thing keeping the target inside the pager.
    final target = (targetPage * viewport)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

// ── Content sheet (translation + tafsirs manager) ──────────────────────────
