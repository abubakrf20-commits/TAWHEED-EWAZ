import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/features/quran/services/quran_timing_service.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_focus.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_player_base.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_stall_watchdog.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Per-ayah talaawah playback backed by the islamic.network CDN.
///
/// The CDN serves **one mp3 per ayah**, so tapping a verse plays exactly that
/// verse — no approximate seeking, the highlight always matches the audio.
/// Whole-surah playback advances verse by verse through the per-ayah files
/// (each verse's file, then the next), so the highlight stays exact for the
/// whole chapter too.
///
/// Responsibilities:
///  * plays the exact per-ayah file of the tapped verse (local cache when
///    available, streaming otherwise),
///  * tracks the currently-playing verse so the mushaf can highlight it,
///  * auto-advances to the next verse (and next surah) when one finishes.
///
/// Why ChangeNotifier (not a Riverpod Notifier): thin adapter over the
/// `audioplayers` event model — `notifyListeners()` maps 1:1 to player state
/// changes; exposed through a provider so the widget tree listens reactively.
class QuranAudioController extends QuranAudioPlayerBase {
  QuranAudioController();

  String? _reciterId;
  int _chapter = 1;
  int _verse = 1;
  bool _loading = false;
  bool _continuous = true;

  /// Extra replays of each verse before moving on (0 = off).
  int _repeatCount = 0;

  /// Replays still owed for the current verse.
  int _repeatRemaining = 0;

  // ── Range repeat for hifz (from ayah X to Y, N times) ─────────────────────
  int? _rangeStartChapter;
  int? _rangeStartVerse;
  int? _rangeEndChapter;
  int? _rangeEndVerse;
  int _rangeRepeatCount = 0;
  int _rangeRemaining = 0;

  bool get hasRepeatRange =>
      _rangeStartChapter != null &&
      _rangeEndChapter != null &&
      _rangeRepeatCount > 0;
  int? get rangeStartChapter => _rangeStartChapter;
  int? get rangeStartVerse => _rangeStartVerse;
  int? get rangeEndChapter => _rangeEndChapter;
  int? get rangeEndVerse => _rangeEndVerse;
  int get rangeRepeatCount => _rangeRepeatCount;
  int get rangeRemaining => _rangeRemaining;

  /// Chapter whose per-ayah session is currently loaded (null when idle).
  int? _loadedChapter;

  /// Set when playback paused exactly at a verse boundary in non-continuous
  /// mode; resuming plays the current verse again from its start.
  int? _boundaryPauseVerse;

  String? _error;
  Duration _position = Duration.zero;

  /// Lightweight tick bumped only when the *verse highlight* actually changes
  /// (chapter/verse/playing state), so the mushaf page can rebuild on this
  /// instead of on every audio position tick.
  final ValueNotifier<int> wordTick = ValueNotifier(0);

  /// Surfaces a frozen position (streamed verse on a weak link) so the mini
  /// player can show «اتصال ضعیف…» instead of a silently stopped clock.
  late final AudioStallWatchdog _stallWatchdog =
      AudioStallWatchdog(onStalled: (_) => _notify());

  void _bumpWordTick() {
    if (!isDisposed) wordTick.value++;
  }

  void _notify() {
    if (!isDisposed) notifyListeners();
  }

  /// Detaches the platform audio-focus subscriptions (see init).
  void Function()? _detachAudioFocus;

  // ── Read-only state ───────────────────────────────────────────────────────

  /// Whether an audio session is active.
  @override
  bool get hasSession => _loadedChapter != null;
  @override
  int get chapter => _chapter;
  @override
  int get verse => _verse;
  @override
  bool get isLoading => _loading;
  bool get continuous => _continuous;

  /// True while playing but the position has been frozen past the stall
  /// threshold (weak connection on a streamed verse). Any advance or pause
  /// clears it.
  bool get isStalled => _stallWatchdog.isStalled;
  int get repeatCount => _repeatCount;
  String? get errorMessage => _error;
  @override
  Duration get position => _position;

  List<WordTiming> _currentWords = const [];
  int _activeWord = -1;

  /// Position (1-based) of the word currently being recited, or -1 when the
  /// verse is highlighted as a whole (no per-word segments available).
  int get activeWord => _activeWord;

  /// Highlight key of the currently-playing word (e.g. "2:255:3").
  String? get activeWordKey =>
      _activeWord >= 0 ? '$_chapter:$_verse:${_activeWord + 1}' : null;

  /// Raw word timings of the current ayah (empty when fallback).
  List<WordTiming> get currentWords => _currentWords;

  /// Key of the currently-playing verse, e.g. `2:255`.
  @override
  String get activeVerseKey => '$_chapter:$_verse';

  /// Label like «سورهٔ بقره — آیهٔ 255» for the mini player.
  @override
  String get verseLabel =>
      'سورهٔ ${getSurahNameArabic(_chapter)} — آیهٔ ${NumberFormat.toLatin('$_verse')}';

  /// The per-ayah engine streams one mp3 per verse and scrubs inside the
  /// current ayah via [seekTo]; the lock-screen seek bar is real here.
  @override
  bool get supportsSeek => true;

  // ── Setup / teardown ──────────────────────────────────────────────────────

  /// Attaches player listeners (idempotent).
  void init() {
    if (isDisposed) return;
    attachPlayerListeners(
      onPosition: _onPosition,
      onComplete: _onComplete,
    );
    // Platform audio focus (headset-unplug, calls, competing audio):
    // pause instead of talking over. Attached once; detached in dispose.
    if (_detachAudioFocus == null) {
      unawaited(attachQuranAudioFocus(
        onPause: pause,
        isPlaying: () => isPlaying && !isDisposed,
      ).then((detach) => _detachAudioFocus = detach));
    }
    // پاک‌سازی کش قدیمی‌تر از 7 روز در پس‌زمینه
    unawaited(Mp3QuranService.cleanupExpiredCache());
  }

  @override
  void setPlaying(bool value) {
    _stallWatchdog.setPlaying(value);
    super.setPlaying(value);
  }

  void setReciter(String reciterId) {
    if (isDisposed) return;
    unawaited(enqueuePlayer(() async {
      try {
        await player.stop();
      } catch (e) {
        AppLogger.warning('quran_audio_controller',
            'stop player on reciter change failed: $e');
      }
    }));
    _reciterId = reciterId;
    invalidateSession();
    setPlaying(false);
    _loading = false;
    _loadedChapter = null;
    _boundaryPauseVerse = null;
    _repeatRemaining = 0;
    _rangeStartChapter = null;
    _rangeStartVerse = null;
    _rangeEndChapter = null;
    _rangeEndVerse = null;
    _rangeRepeatCount = 0;
    _rangeRemaining = 0;
    _chapterAudioReset();
    _bumpWordTick();
    _notify();
  }

  void _chapterAudioReset() {
    _position = Duration.zero;
    resetDuration();
    _error = null;
    _currentWords = const [];
    _activeWord = -1;
    _earlyAdvanceFired = false;
  }

  @override
  void dispose() {
    try {
      _detachAudioFocus?.call();
    } catch (e) {
      AppLogger.warning(
          'quran_audio_controller', 'detach audio focus failed: $e');
    }
    _detachAudioFocus = null;
    unawaited(releaseWakelock('quran_audio'));
    wordTick.dispose();
    _stallWatchdog.dispose();
    // Queue cleanup behind any in-flight native operation. Disposing directly
    // while setSource/resume is active can still crash some Android players.
    unawaited(disposePlayer());
    super.dispose();
  }

  // ── Public control ────────────────────────────────────────────────────────

  /// Plays [verse] of [chapter] — the exact per-ayah audio file, so what you
  /// hear always matches the highlighted verse.
  @override
  Future<void> playVerse(int chapter, int verse) async {
    if (isDisposed) return;
    final reciter = _reciterId;
    if (reciter == null) {
      _error = 'ابتدا یک قاری انتخاب کنید';
      _notify();
      return;
    }
    init();
    await _playAyah(chapter, verse);
  }

  @override
  Future<void> togglePlayPause() async {
    if (isDisposed) return;
    try {
      await enqueuePlayer(() async {
        if (isPlaying) {
          await player.pause();
          return;
        }
        if (hasSession && _boundaryPauseVerse == null) {
          await player.resume();
          await acquireWakelock('quran_audio');
        }
      });
      if (isPlaying || hasSession && _boundaryPauseVerse == null) return;
      if (hasSession) {
        if (_boundaryPauseVerse != null) {
          // Resuming after a verse-boundary pause replays the current verse.
          _boundaryPauseVerse = null;
          unawaited(_playAyah(_chapter, _verse));
          return;
        }
        await playVerse(_chapter, _verse);
      } else {
        await playVerse(_chapter, _verse);
      }
    } catch (_) {
      // A stale player (released mid-tap by a rapid session switch) must
      // never surface as an unhandled native error — the UI state stays
      // consistent and the next tap re-drives the player.
    }
  }

  /// Scrubs within the current ayah (lock-screen seek bar). No-op when no
  /// session is loaded; a seek never restarts playback.
  @override
  Future<void> seekTo(Duration position) async {
    if (isDisposed || !hasSession) return;
    try {
      await enqueuePlayer(() => player.seek(position));
    } catch (e) {
      AppLogger.warning('quran_audio_controller', 'seek failed: $e');
    }
  }

  @override
  Future<void> nextVerse() => _playRelative(1);

  @override
  Future<void> prevVerse() => _playRelative(-1);

  Future<void> stop() async {
    if (isDisposed) return;
    invalidateSession();
    _earlyAdvanceFired = false;
    try {
      await enqueuePlayer(() async {
        await player.stop();
      });
    } catch (e) {
      AppLogger.warning('quran_audio_controller', 'player stop failed: $e');
    }
    setPlaying(false);
    _loading = false;
    _loadedChapter = null;
    _boundaryPauseVerse = null;
    _repeatRemaining = 0;
    _rangeStartChapter = null;
    _rangeStartVerse = null;
    _rangeEndChapter = null;
    _rangeEndVerse = null;
    _rangeRepeatCount = 0;
    _rangeRemaining = 0;
    _position = Duration.zero;
    _error = null;
    _currentWords = const [];
    _activeWord = -1;
    _bumpWordTick();
    unawaited(releaseWakelock('quran_audio'));
    _notify();
  }

  void setContinuous(bool value) {
    _continuous = value;
    if (value) _boundaryPauseVerse = null;
    _notify();
  }

  /// Sets how many extra times each verse repeats before moving on
  /// (0 disables repetition).
  void setRepeatCount(int count) {
    final clamped = count < 0 ? 0 : count;
    _repeatCount = clamped;
    _repeatRemaining = 0;
    if (clamped > 0) clearRepeatRange();
    _notify();
  }

  /// تکرار محدوده برای حفظ: از [startChapter]:[startVerse] تا [endChapter]:[endVerse]
  /// به تعداد [repeatCount] بار (1 یا بیشتر، بی‌سقف). هر بار کل محدوده از ابتدا تا انتها پخش می‌شود.
  void setRepeatRange(int startChapter, int startVerse, int endChapter,
      int endVerse, int repeatCount) {
    final startGlobal = globalAyahNumber(startChapter, startVerse);
    final endGlobal = globalAyahNumber(endChapter, endVerse);
    if (startGlobal > endGlobal) {
      _rangeStartChapter = endChapter;
      _rangeStartVerse = endVerse;
      _rangeEndChapter = startChapter;
      _rangeEndVerse = startVerse;
    } else {
      _rangeStartChapter = startChapter;
      _rangeStartVerse = startVerse;
      _rangeEndChapter = endChapter;
      _rangeEndVerse = endVerse;
    }
    _rangeRepeatCount = repeatCount < 1 ? 1 : repeatCount;
    _rangeRemaining = _rangeRepeatCount;
    _repeatCount = 0;
    _repeatRemaining = 0;
    _notify();
  }

  void clearRepeatRange() {
    _rangeStartChapter = null;
    _rangeStartVerse = null;
    _rangeEndChapter = null;
    _rangeEndVerse = null;
    _rangeRepeatCount = 0;
    _rangeRemaining = 0;
    _notify();
  }

  /// Plays the whole [chapter] continuously from its first verse.
  @override
  Future<void> playChapter(int chapter) async {
    _continuous = true;
    await playVerse(chapter, 1);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Loads and plays the exact audio file of [chapter]:[verse] (local cache
  /// first, then the CDN). Each call captures a fresh session token so rapid
  /// taps never interleave.
  Future<void> _playAyah(int chapter, int verse) async {
    final reciter = _reciterId;
    if (isDisposed || reciter == null) {
      if (reciter == null && !isDisposed) {
        _error = 'ابتدا یک قاری انتخاب کنید';
        _notify();
      }
      return;
    }
    init();
    final token = beginSession();
    _loading = true;
    _error = null;
    _chapter = chapter;
    _verse = verse;
    _earlyAdvanceFired = false;
    // بارگذاری timing کلمه‌ها (بی‌صدا، با کش)
    _currentWords = const [];
    _activeWord = -1;
    unawaited(QuranTimingService.fetchTiming(reciter, chapter, verse).then((t) {
      if (!sessionAlive(token)) return;
      if (t != null && t.hasWords) {
        _currentWords = t.words;
      }
    }));
    _bumpWordTick();
    _notify();
    try {
      final reciterObj = await Mp3QuranService.reciterById(reciter);
      if (!sessionAlive(token)) return;
      if (reciterObj == null) throw StateError('قاری پیدا نشد');
      final local =
          await Mp3QuranService.localCachedVersePath(reciter, chapter, verse);
      if (!sessionAlive(token)) return;
      final urls = local == null
          ? reciterObj.verseUrlsWithFallback(chapter, verse)
          : <String>[];
      if (!sessionAlive(token)) return;
      if (local == null && urls.isEmpty) {
        throw StateError('قاری پیدا نشد');
      }
      await enqueuePlayer(() async {
        if (!sessionAlive(token)) return;
        await player.stop();
        if (local != null) {
          await player.setSource(DeviceFileSource(local));
        } else {
          // تلاش ترتیبی روی URLهای fallback تا یکی موفق شود
          Object? lastErr;
          for (final u in urls) {
            try {
              await player.setSource(UrlSource(u));
              lastErr = null;
              break;
            } catch (e) {
              // Per-URL, per-verse: persisting this floods the on-device log
              // while a reciter CDN is down. Debug trace only.
              AppLogger.debug(
                  'quran_audio_controller', 'fallback url failed: $e');
              lastErr = e;
              continue;
            }
          }
          if (lastErr != null) throw lastErr;
        }
        if (!sessionAlive(token)) return;
        _loadedChapter = chapter;
        _boundaryPauseVerse = null;
        _repeatRemaining = _repeatCount;
        setCompletionToken(token);
        await player.resume();
        try {
          await player.setPlaybackRate(playbackRate);
        } catch (e) {
          AppLogger.warning(
              'quran_audio_controller', 'set playback rate failed: $e');
        }
        await acquireWakelock('quran_audio');
        unawaited(_prefetchAhead(chapter, verse));
      });
    } catch (e) {
      AppLogger.warning(
          'quran_audio_controller', 'play ayah $chapter:$verse failed: $e');
      if (sessionAlive(token)) {
        _error = 'پخش صوت ممکن نشد؛ دوباره تلاش کنید.';
      }
    } finally {
      if (sessionAlive(token)) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Caches the next verses of the current session (best-effort, streaming
  /// stays the fallback). Only ever touches the ephemeral audio cache —
  /// never marks a surah as "downloaded".
  Future<void> _prefetchAhead(int chapter, int verse) async {
    final reciter = _reciterId;
    if (isDisposed) return;
    if (reciter == null) return;
    // پیش‌بار دو آیه بعدی هم‌زمان — تا 10 ثانیه تأخیر بین آیات به حداقل برسد
    var c = chapter;
    var v = verse;
    final toPrefetch = <Future<void>>[];
    for (var i = 0; i < 2; i++) {
      v++;
      if (v > getVerseCount(c)) {
        if (c >= 114) break;
        c++;
        v = 1;
      }
      toPrefetch.add(Mp3QuranService.prefetchVerse(reciter, c, v));
      // timing هم پیش‌بار شود
      toPrefetch.add(QuranTimingService.prefetch(reciter, c, v));
    }
    await Future.wait(toPrefetch);
  }

  Future<void> _playRelative(int delta) async {
    if (!hasSession) return;
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

  bool _earlyAdvanceFired = false;

  void _onPosition(Duration pos) {
    _position = pos;
    _stallWatchdog.onPosition(pos);
    // به‌روزرسانی کلمه فعال بر اساس timing
    if (_currentWords.isNotEmpty) {
      final ms = pos.inMilliseconds;
      var newWord = -1;
      for (var i = 0; i < _currentWords.length; i++) {
        final w = _currentWords[i];
        if (ms >= w.startMs && ms < w.endMs) {
          newWord = i;
          break;
        }
      }
      if (newWord == -1 && _currentWords.isNotEmpty) {
        for (var i = _currentWords.length - 1; i >= 0; i--) {
          if (ms >= _currentWords[i].startMs) {
            newWord = i;
            break;
          }
        }
      }
      if (newWord != _activeWord) {
        _activeWord = newWord;
        _bumpWordTick();
      }
    }
    // پیش‌رفتنِ زودهنگام برای حذف سکوت 5-10 ثانیه‌ایِ انتهای فایل
    if (_continuous &&
        !isDisposed &&
        duration > Duration.zero &&
        completionToken == sessionToken &&
        !_earlyAdvanceFired) {
      final remaining = duration - pos;
      if (remaining <= const Duration(milliseconds: 600) &&
          remaining > Duration.zero &&
          _position > const Duration(milliseconds: 800)) {
        _earlyAdvanceFired = true;
        _onComplete();
      }
    } else if (_position < const Duration(milliseconds: 400)) {
      _earlyAdvanceFired = false;
    }
    _notify();
  }

  void _onComplete() {
    if (isDisposed || completionToken != sessionToken) return;
    if (hasRepeatRange) {
      final curGlobal = globalAyahNumber(_chapter, _verse);
      final startGlobal =
          globalAyahNumber(_rangeStartChapter!, _rangeStartVerse!);
      final endGlobal = globalAyahNumber(_rangeEndChapter!, _rangeEndVerse!);
      if (curGlobal >= startGlobal && curGlobal <= endGlobal) {
        if (curGlobal == endGlobal) {
          _rangeRemaining--;
          if (_rangeRemaining > 0) {
            _bumpWordTick();
            _notify();
            unawaited(playVerse(_rangeStartChapter!, _rangeStartVerse!));
            return;
          } else {
            _rangeStartChapter = null;
            _rangeStartVerse = null;
            _rangeEndChapter = null;
            _rangeEndVerse = null;
            _rangeRepeatCount = 0;
            _rangeRemaining = 0;
            setPlaying(false);
            _bumpWordTick();
            unawaited(releaseWakelock('quran_audio'));
            _notify();
            return;
          }
        } else {
          var c = _chapter;
          var v = _verse + 1;
          if (v > getVerseCount(c)) {
            if (c < 114) {
              c++;
              v = 1;
            }
          }
          unawaited(playVerse(c, v));
          return;
        }
      } else {
        _rangeRemaining = _rangeRepeatCount;
        unawaited(playVerse(_rangeStartChapter!, _rangeStartVerse!));
        return;
      }
    }
    if (_repeatRemaining > 0) {
      // Replay the current verse.
      _repeatRemaining--;
      unawaited(_playAyah(_chapter, _verse));
      return;
    }
    if (!_continuous) {
      // توقف بعد از هر آیه — pause at the verse boundary.
      setPlaying(false);
      _boundaryPauseVerse = _verse;
      _bumpWordTick();
      unawaited(releaseWakelock('quran_audio'));
      _notify();
      return;
    }
    var c = _chapter;
    var v = _verse + 1;
    if (v > getVerseCount(c)) {
      if (c >= 114) {
        setPlaying(false);
        _bumpWordTick();
        unawaited(releaseWakelock('quran_audio'));
        notifyListeners();
        return;
      }
      c++;
      v = 1;
    }
    unawaited(playVerse(c, v));
  }
}

/// Error surfaced when a chapter's data cannot be built (should not happen —
/// the bundled Quran data is always present).
class QuranSurahTimingException implements Exception {
  final String message;
  QuranSurahTimingException(this.message);
}

/// Maps playback positions inside a surah file to (approximate) verse
/// boundaries, scaled by each verse's text length.
///
/// Per-ayah playback no longer needs this table for live playback, but the
/// class is kept (and unit-tested) as a pure utility — e.g. for estimating a
/// position within a whole-surah file when the exact per-ayah files are not
/// available.
class QuranSurahTiming {
  /// Cumulative weights: `cum[i]` = total weight of verses 1..i, `cum[0]` = 0.
  final List<int> cum;

  QuranSurahTiming(this.cum);

  /// Total weight of the whole chapter.
  int get total => cum.isEmpty ? 0 : cum.last;

  /// Number of verses.
  int get verseCount => cum.isEmpty ? 0 : cum.length - 1;

  /// Builds the timing table for [chapter] from the bundled Quran text.
  static QuranSurahTiming forChapter(int chapter) {
    final count = getVerseCount(chapter);
    final weights = List<int>.filled(count, 0);
    for (final aya in quran) {
      if (aya['sora'] != chapter) continue;
      final v = aya['aya_no'] as int;
      if (v < 1 || v > count) continue;
      final text = (aya['aya_text'] as String?) ?? '';
      weights[v - 1] = text.length;
    }
    // Fallback: any verse without text still gets a minimal weight so the
    // table stays strictly monotonic.
    for (var i = 0; i < count; i++) {
      if (weights[i] <= 0) weights[i] = 1;
    }
    final cum = List<int>.filled(count + 1, 0);
    for (var i = 1; i <= count; i++) {
      cum[i] = cum[i - 1] + weights[i - 1];
    }
    return QuranSurahTiming(cum);
  }

  /// Verse (1-based) audible at [ms] into a file of [durMs] total.
  ///
  /// Defined as the largest verse whose start offset (per [offsetMsFor]) is at
  /// or before [ms], so a seek to a verse's own offset always maps back to
  /// that verse (or a later verse sharing the same zero-width window).
  int verseAtMs(int ms, int durMs) {
    if (verseCount == 0 || total <= 0 || durMs <= 0) return 1;
    var lo = 1;
    var hi = verseCount;
    var ans = 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (offsetMsFor(mid, durMs) <= ms) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// Approximate start offset (ms) of [verse] (1-based) in a file of [durMs].
  int offsetMsFor(int verse, int durMs) {
    if (verseCount == 0 || total <= 0 || durMs <= 0) return 0;
    final v = verse.clamp(1, verseCount);
    return (cum[v - 1] * durMs) ~/ total;
  }
}
