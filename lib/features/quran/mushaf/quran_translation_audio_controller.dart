import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_focus.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_player_base.dart';
import 'package:tawheeed/features/quran/mushaf/quran_translation_download_service.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Per-ayah Persian translation playback from the QuranEnc CDN.
///
/// Streams one mp3 per ayah from:
/// `https://d.quranenc.com/data/audio/persian_ih/{SSS}{AAA}.mp3`
///
/// Uses local cache when available (downloaded via
/// [QuranTranslationDownloadService]), falls back to streaming.
/// Auto-advances to the next verse when one finishes (continuous mode, on
/// by default).
///
/// Why ChangeNotifier (not a Riverpod Notifier): thin adapter over the
/// `audioplayers` event model — `notifyListeners()` maps 1:1 to player state
/// changes; exposed through a provider so the widget tree listens reactively.
class QuranTranslationAudioController extends QuranAudioPlayerBase {
  QuranTranslationAudioController();

  static const String _baseUrl = 'https://d.quranenc.com/data/audio/persian_ih';

  int _chapter = 1;
  int _verse = 1;
  bool _loading = false;
  bool _continuous = true;

  /// «تلاوت سپس ترجمه» (the QuranEnc site's «التلاوة ثم الترجمة» mode): a
  /// combined session starts with the ayah's recitation (same reciter the
  /// reader uses) and switches to the ayah's translation when it completes.
  bool _combinedWithRecitation = false;
  String? _reciterId;

  /// Which half of a combined session is loaded in the player:
  /// `'recitation'` or `'translation'`. Plain sessions are always
  /// `'translation'`.
  String _phase = 'translation';

  /// A session exists from playVerse until stop(), *including* while paused —
  /// same semantics as the talaawah controller (`_loadedChapter != null`).
  /// Previously `hasSession` was `_playing || _loading`, so pausing hid the
  /// mini-player and togglePlayPause could never resume (it restarted).
  bool _hasSession = false;

  String? _error;
  Duration _position = Duration.zero;

  /// Detaches the platform audio-focus subscriptions (see _init).
  void Function()? _detachAudioFocus;

  // ── Read-only state ───────────────────────────────────────────────────────

  bool get hasSession => _hasSession;
  int get chapter => _chapter;
  int get verse => _verse;
  @override
  bool get isLoading => _loading;
  bool get continuous => _continuous;

  /// Whether «صوتی» plays recitation-then-translation. The pane toggle
  /// reads this for its check; the view re-syncs the reciter on every tap.
  bool get combinedWithRecitation => _combinedWithRecitation;

  /// True while the loaded track is the recitation half of a combined
  /// session (the mini player labels the line «تلاوت» instead of
  /// «ترجمهٔ صوتی»).
  bool get isPlayingRecitation => _phase == 'recitation';

  /// Turns the combined «تلاوت سپس ترجمه» mode on/off. [reciterId] is the
  /// reader's current reciter — the recitation half resolves its mp3 through
  /// it, so the combined playback and the «تلاوت» button never disagree.
  void setCombinedWithRecitation(bool value, {String? reciterId}) {
    if (isDisposed) return;
    _combinedWithRecitation = value;
    if (reciterId != null) _reciterId = reciterId;
    notifyListeners();
  }
  String? get errorMessage => _error;
  @override
  Duration get position => _position;

  /// Label like «ترجمه: بقره — 255» for the mini player.
  @override
  String get verseLabel =>
      'ترجمه: ${getSurahNameArabic(_chapter)} — ${NumberFormat.toLatin('$_verse')}';

  /// Key of the currently-playing verse, e.g. `2:255`.
  @override
  String get activeVerseKey => '$_chapter:$_verse';

  /// The translation engine streams one mp3 per verse through audioplayers
  /// without a seek API wired up: the lock-screen card hides its seek bar
  /// instead of advertising a control that does nothing (skip-to-verse and
  /// play/pause remain fully functional).
  @override
  bool get supportsSeek => false;

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get positionLabel => _fmt(_position);

  // ── URL builder ───────────────────────────────────────────────────────────

  static String urlForVerse(int surah, int aya) =>
      '$_baseUrl/${surah.toString().padLeft(3, '0')}'
      '${aya.toString().padLeft(3, '0')}.mp3';

  /// Lock-screen seek: the translation engine has no seek wired up — a safe
  /// no-op so a stray MediaController.seek can never crash or restart it.
  @override
  Future<void> seekTo(Duration position) async {}

  // ── Setup / teardown ──────────────────────────────────────────────────────

  void _init() {
    if (isDisposed) return;
    attachPlayerListeners(
      onPosition: (pos) {
        if (isDisposed) return;
        _position = pos;
        notifyListeners();
      },
      onComplete: _onComplete,
    );
    // Platform audio focus (headset-unplug, calls, competing audio).
    if (_detachAudioFocus == null) {
      unawaited(attachQuranAudioFocus(
        onPause: pause,
        isPlaying: () => isPlaying && !isDisposed,
      ).then((detach) => _detachAudioFocus = detach));
    }
  }

  @override
  void dispose() {
    try {
      _detachAudioFocus?.call();
    } catch (e) {
      AppLogger.warning('quran_translation_audio_controller',
          'detach audio focus failed: $e');
    }
    _detachAudioFocus = null;
    unawaited(releaseWakelock('translation_audio'));
    // Stop before dispose and swallow native errors: disposing a MediaPlayer
    // mid-buffer/playing used to be able to crash the process.
    // Audit 9-B: route the cleanup through the queue like every other
    // player op — the bare fire-and-forget used to race an in-flight
    // setSource/resume from playVerse and hit the native player
    // concurrently with it.
    unawaited(disposePlayer());
    super.dispose();
  }

  // ── Public control ────────────────────────────────────────────────────────

  Future<void> playVerse(int surah, int verse,
      {bool skipRecitation = false}) async {
    if (isDisposed) return;
    _init();
    final token = beginSession();
    _loading = true;
    _hasSession = true;
    _error = null;
    setCompletionToken(token);
    _chapter = surah;
    _verse = verse;
    // Combined mode starts with the ayah's recitation and switches to its
    // translation on completion. `skipRecitation` is set by the completion
    // handler so the translation half never re-plays the recitation — a
    // fresh tap always starts from the recitation again.
    _phase = (!skipRecitation && _combinedWithRecitation && _reciterId != null)
        ? 'recitation'
        : 'translation';
    notifyListeners();
    try {
      await enqueuePlayer(player.stop);
      if (!sessionAlive(token)) return;
      if (_phase == 'recitation') {
        // Degrade gracefully: when the recitation half cannot be served,
        // play the verse's translation alone (the pre-combined behaviour).
        if (!await _playRecitationFile(surah, verse, token)) {
          if (!sessionAlive(token)) return;
          _phase = 'translation';
        }
      }
      if (_phase == 'translation') {
        if (!await _loadTranslationFile(surah, verse, token)) {
          if (!sessionAlive(token)) return;
          throw StateError('ترجمه یافت نشد');
        }
      }
      if (!sessionAlive(token)) return;
      await enqueuePlayer(() async {
        if (!sessionAlive(token)) return;
        await player.resume();
        // The recitation half plays at the natural 1× rate — only the
        // translation half honours the user's chosen playback speed, so
        // tilaawah never sounds sped up or slowed down.
        if (_phase != 'recitation') {
          try {
            await player.setPlaybackRate(playbackRate);
          } catch (e) {
            AppLogger.warning('quran_translation_audio_controller',
                'set playback rate failed: $e');
          }
        }
      });
      if (!sessionAlive(token)) return;
      await acquireWakelock('translation_audio');
      // The next verses start downloading while this one plays, so
      // advancing never waits on a fresh ~30s CDN fetch.
      unawaited(_prefetchAhead(surah, verse));
    } catch (e) {
      AppLogger.warning('quran_translation_audio_controller',
          'play translation $surah:$verse failed: $e');
      if (sessionAlive(token)) {
        _error = 'پخش ترجمه ناموفق بود';
      }
    } finally {
      if (sessionAlive(token)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Serves the ayah's recitation mp3 into the player — the same reciter and
  /// CDN fallbacks the «تلاوت» button uses. Returns false — never throws —
  /// when no source can be served, so a combined session falls back to
  /// translation-only instead of dying.
  Future<bool> _playRecitationFile(int surah, int verse, int token) async {
    try {
      final reciterId = _reciterId;
      if (reciterId == null) return false;
      final reciter = await Mp3QuranService.reciterById(reciterId);
      if (!sessionAlive(token) || reciter == null) return false;
      final localPath =
          await Mp3QuranService.localCachedVersePath(reciterId, surah, verse);
      if (!sessionAlive(token)) return false;
      final urls = localPath == null
          ? reciter.verseUrlsWithFallback(surah, verse)
          : const <String>[];
      if (localPath == null && urls.isEmpty) return false;
      var served = false;
      await enqueuePlayer(() async {
        if (!sessionAlive(token)) return;
        await player.stop();
        if (localPath != null) {
          await player.setSource(DeviceFileSource(localPath));
          served = true;
          return;
        }
        for (final u in urls) {
          try {
            await player.setSource(UrlSource(u));
            served = true;
            return;
          } catch (e) {
            // Per-URL, per-verse: debug trace only (a down CDN must not
            // flood the on-device log).
            AppLogger.debug('quran_translation_audio_controller',
                'combined recitation url failed: $e');
          }
        }
      });
      return served;
    } catch (e) {
      AppLogger.warning('quran_translation_audio_controller',
          'combined recitation failed: $e');
      return false;
    }
  }

  /// Loads the Persian translation mp3 into the player — local cache first,
  /// then the browser-UA download, then direct streaming as a last resort.
  /// Returns false when the session moved on (the caller re-checks the
  /// token); every other failure propagates to playVerse's catch.
  Future<bool> _loadTranslationFile(int surah, int verse, int token) async {
    // Check local cache first.
    final localPath =
        await QuranTranslationDownloadService.localCachedVersePath(
            surah, verse);
    if (!sessionAlive(token)) return false;
    if (localPath != null) {
      await enqueuePlayer(
          () => player.setSource(DeviceFileSource(localPath)));
      return true;
    }
    // The QuranEnc CDN blocks non-browser User-Agents (403). Download the
    // verse first (with a browser UA) and play the local file so playback
    // works reliably; keep streaming as a last-resort fallback.
    final downloaded =
        await QuranTranslationDownloadService.ensureVerseDownloaded(
            surah, verse);
    if (!sessionAlive(token)) return false;
    if (downloaded != null) {
      await enqueuePlayer(
          () => player.setSource(DeviceFileSource(downloaded)));
      return true;
    }
    await enqueuePlayer(
        () => player.setSource(UrlSource(urlForVerse(surah, verse))));
    return true;
  }

  @override
  Future<void> togglePlayPause() async {
    if (isDisposed) return;
    try {
      if (isPlaying) {
        await enqueuePlayer(player.pause);
      } else if (hasSession && !_loading) {
        await enqueuePlayer(player.resume);
        await acquireWakelock('translation_audio');
      } else {
        await playVerse(_chapter, _verse);
      }
    } catch (_) {
      // Stale player after a rapid session switch — never surface natively.
    }
  }

  Future<void> stop() async {
    if (isDisposed) return;
    invalidateSession();
    try {
      await enqueuePlayer(player.stop);
    } catch (e) {
      AppLogger.warning(
          'quran_translation_audio_controller', 'player stop failed: $e');
    }
    setPlaying(false);
    _loading = false;
    _hasSession = false;
    _position = Duration.zero;
    _error = null;
    unawaited(releaseWakelock('translation_audio'));
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> nextVerse() => _playRelative(1);

  @override
  Future<void> prevVerse() => _playRelative(-1);

  void setContinuous(bool value) {
    _continuous = value;
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Pre-downloads the next two verses in the background (translation audio
  /// always; the recitation half too in «تلاوت سپس ترجمه» mode), so the
  /// following verses play from the local cache instead of blocking on a
  /// fresh CDN download. Best-effort: every leg is cache-checked first and
  /// failures are silent — a missed prefetch just loads on demand.
  Future<void> _prefetchAhead(int surah, int verse) async {
    if (isDisposed) return;
    final combined = _combinedWithRecitation;
    final reciterId = _reciterId;
    var c = surah;
    var v = verse;
    final jobs = <Future<void>>[];
    for (var i = 0; i < 2; i++) {
      v++;
      if (v > getVerseCount(c)) {
        if (c >= 114) break;
        c++;
        v = 1;
      }
      jobs.add(_prefetchOne(c, v, combined, reciterId));
    }
    await Future.wait(jobs);
  }

  Future<void> _prefetchOne(
      int surah, int verse, bool combined, String? reciterId) async {
    try {
      await QuranTranslationDownloadService.ensureVerseDownloaded(
          surah, verse);
      if (combined && reciterId != null && !isDisposed) {
        await Mp3QuranService.prefetchVerse(reciterId, surah, verse);
      }
    } catch (_) {
      // Opportunistic only; the verse loads on demand if this missed.
    }
  }

  Future<void> _playRelative(int delta) async {
    var c = _chapter;
    var v = _verse + delta;
    if (v < 1) {
      if (c <= 1) return;
      c--;
      v = getVerseCount(c);
    } else if (v > getVerseCount(c)) {
      if (c >= 114) return;
      c++;
      v = 1;
    }
    await playVerse(c, v);
  }

  void _onComplete() {
    if (isDisposed || completionToken != sessionToken) return;
    // Combined mode: the recitation half finished — switch to this verse's
    // translation without re-entering the recitation half.
    if (_phase == 'recitation') {
      unawaited(playVerse(_chapter, _verse, skipRecitation: true));
      return;
    }
    if (!_continuous) {
      setPlaying(false);
      unawaited(releaseWakelock('translation_audio'));
      notifyListeners();
      return;
    }
    var c = _chapter;
    var v = _verse + 1;
    if (v > getVerseCount(c)) {
      if (c >= 114) {
        setPlaying(false);
        releaseWakelock('translation_audio');
        notifyListeners();
        return;
      }
      c++;
      v = 1;
    }
    // The combined flag survives: the next verse starts from its own
    // recitation half again («تلاوت سپس ترجمه» per ayah).
    unawaited(playVerse(c, v));
  }
}
