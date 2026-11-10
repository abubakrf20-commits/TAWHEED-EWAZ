import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One downloadable ruqyah audio track hosted on the app owner's GitHub
/// content catalog (`roqya/` folder of TAWHEED-EWAZ).
class RuqyahAudioTrack {
  /// Stable key used for the local file name (ASCII-safe).
  final String key;

  /// Display title (Persian).
  final String title;

  /// Reciter name (Persian).
  final String reciter;

  /// Remote file name on the catalog.
  final String remoteFile;

  const RuqyahAudioTrack({
    required this.key,
    required this.title,
    required this.reciter,
    required this.remoteFile,
  });

  /// Remote URL of the track (raw.githubusercontent.com — the same host the
  /// hadith/library content is downloaded from).
  String get url => '${QuranApiConfig.contentBaseUrl}/roqya/$remoteFile';

  /// Approximate size in MB, shown before download.
  double get approxSizeMb {
    switch (key) {
      case 'ahmad-al-nafis':
        return 14.2;
      case 'ghassan-al-shorbagi':
        return 8.7;
    }
    return 0;
  }
}

/// Download + playback state for a single ruqyah track.
class RuqyahAudioTrackState {
  /// Bytes received (during download).
  final int received;

  /// Total bytes (-1 when unknown).
  final int total;

  /// Whether a download is running.
  final bool downloading;

  /// Whether the file exists locally.
  final bool downloaded;

  /// Whether this track is currently playing.
  final bool playing;

  /// Whether this track is buffering/loading.
  final bool loading;

  /// Elapsed playback position.
  final Duration position;

  /// Total media duration (Duration.zero until the player reports it).
  final Duration duration;

  /// Last error message (Persian), null when fine.
  final String? error;

  const RuqyahAudioTrackState({
    this.received = 0,
    this.total = -1,
    this.downloading = false,
    this.downloaded = false,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  /// 0..1 download progress; null when unknown.
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// True once the player has reported a valid (non-zero) duration.
  bool get hasDuration => duration > Duration.zero;

  RuqyahAudioTrackState copyWith({
    int? received,
    int? total,
    bool? downloading,
    bool? downloaded,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    Object? error = _sentinel,
  }) {
    return RuqyahAudioTrackState(
      received: received ?? this.received,
      total: total ?? this.total,
      downloading: downloading ?? this.downloading,
      downloaded: downloaded ?? this.downloaded,
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

/// Manages downloading and playing the two full-ruqyah recitations from the
/// hosted content catalog (`roqya/*.opus`).
///
/// Files are stored once in
/// `<ApplicationDocuments>/ruqyah_audio/<key>.opus` and kept forever — same
/// keep-forever policy as the hadith/library content. Playback uses
/// audioplayers (opus is natively supported on Android/iOS/desktop).
///
/// Why ChangeNotifier (not a Riverpod Notifier): thin adapter over
/// `audioplayers` events — `notifyListeners()` mirrors player state changes —
/// owned as a singleton via provider rather than holding Riverpod state.
class RuqyahAudioService extends ChangeNotifier {
  RuqyahAudioService._();

  static final RuqyahAudioService instance = RuqyahAudioService._();

  /// The two hosted recitations.
  static const List<RuqyahAudioTrack> tracks = [
    RuqyahAudioTrack(
      key: 'ahmad-al-nafis',
      title: 'رقیه کامل',
      reciter: 'احمد النفیس',
      remoteFile: 'ahmad-al-nafis.opus',
    ),
    RuqyahAudioTrack(
      key: 'ghassan-al-shorbagi',
      title: 'رقیه کامل',
      reciter: 'غسان الشوربجی',
      remoteFile: 'ghassan-al-shorbagi.opus',
    ),
  ];

  static const String _dirName = 'ruqyah_audio';

  /// SharedPreferences key prefixes for the persisted playback position and
  /// media duration of each track (stored as milliseconds). Full ruqyah
  /// recordings run long, so the listener should resume where they left off
  /// even after closing the app or switching between the two recitations.
  static const String _posKeyPrefix = 'ruqyah_pos_';
  static const String _durKeyPrefix = 'ruqyah_dur_';

  /// Positions/durations restored from disk (milliseconds), keyed by track
  /// key. Populated lazily by [_loadSavedPosition] and updated by the player.
  final Map<String, int> _savedPositions = {};
  final Map<String, int> _savedDurations = {};

  /// Last persisted position per track (ms) — used to throttle writes so a
  /// position update only hits SharedPreferences at most every ~5 s.
  final Map<String, int> _lastPersistedMs = {};

  final Map<String, RuqyahAudioTrackState> _states = {
    for (final t in tracks) t.key: const RuqyahAudioTrackState(),
  };

  AudioPlayer? _player;
  String? _playingKey;
  int _sessionToken = 0;
  bool _disposed = false;
  http.Client? _downloadClient;

  /// Tracks whose download the user cancelled — the resulting stream error is
  /// a cancellation, not a network failure, and must not be reported as one.
  final Set<String> _cancelledDownloads = {};
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  /// Per-track states, keyed by [RuqyahAudioTrack.key].
  RuqyahAudioTrackState stateOf(RuqyahAudioTrack track) =>
      _states[track.key] ?? const RuqyahAudioTrackState();

  /// The track currently playing (null when none).
  RuqyahAudioTrack? get playingTrack {
    final k = _playingKey;
    if (k == null) return null;
    for (final t in tracks) {
      if (t.key == k) return t;
    }
    return null;
  }

  // ── Persisted playback position ─────────────────────────────────────

  /// Loads the persisted position of [track] (once) and returns it.
  Future<Duration> _loadSavedPosition(RuqyahAudioTrack track) async {
    final cached = _savedPositions[track.key];
    if (cached != null) return Duration(milliseconds: cached);
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedPositions[track.key] =
          prefs.getInt('$_posKeyPrefix${track.key}') ?? 0;
      _savedDurations[track.key] =
          prefs.getInt('$_durKeyPrefix${track.key}') ?? 0;
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'operation failed');
      _savedPositions[track.key] ??= 0;
    }
    return Duration(milliseconds: _savedPositions[track.key] ?? 0);
  }

  /// Persists the current position of [track] (best-effort; failures are
  /// logged and swallowed so playback is never interrupted).
  Future<void> _savePosition(RuqyahAudioTrack track, Duration position) async {
    final ms = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    _savedPositions[track.key] = ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_posKeyPrefix${track.key}', ms);
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'save position failed: $e');
    }
  }

  /// Clears the persisted position of [track] (used when the track finishes
  /// or its file is deleted) so the next play starts from the beginning.
  Future<void> _clearSavedPosition(RuqyahAudioTrack track) async {
    _savedPositions[track.key] = 0;
    _savedDurations[track.key] = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_posKeyPrefix${track.key}');
      await prefs.remove('$_durKeyPrefix${track.key}');
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'clear position failed: $e');
    }
  }

  /// Persists the reported media duration of [track] (best-effort) so the
  /// seek row can be rebuilt after an app restart.
  Future<void> _saveDuration(RuqyahAudioTrack track, Duration duration) async {
    final ms = duration.inMilliseconds < 0 ? 0 : duration.inMilliseconds;
    _savedDurations[track.key] = ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_durKeyPrefix${track.key}', ms);
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'save duration failed: $e');
    }
  }

  /// The track with [key], or null when unknown.
  RuqyahAudioTrack? _trackByKey(String key) {
    for (final t in tracks) {
      if (t.key == key) return t;
    }
    return null;
  }

  // ── Paths ────────────────────────────────────────────────────────────────

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, _dirName));
  }

  /// Local path of [track]'s audio file (whether or not it exists yet).
  Future<String> localPath(RuqyahAudioTrack track) async =>
      p.join((await _dir()).path, '${track.key}.opus');

  /// Whether [track] is already downloaded (non-empty file).
  Future<bool> isDownloaded(RuqyahAudioTrack track) async {
    try {
      final f = File(await localPath(track));
      return await f.exists() && await f.length() > 1024;
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'operation failed');
      return false;
    }
  }

  /// Refreshes the `downloaded` flag of every track and restores the saved
  /// resume points (call on screen open).
  Future<void> refresh() async {
    var changed = false;
    for (final t in tracks) {
      final ok = await isDownloaded(t);
      if (_states[t.key]?.downloaded != ok) {
        _states[t.key] = (_states[t.key] ?? const RuqyahAudioTrackState())
            .copyWith(downloaded: ok);
        changed = true;
      }
    }
    // Surface the persisted resume points so the cards show where the
    // listener stopped, even after leaving the screen or the app.
    for (final t in tracks) {
      if (_playingKey == t.key) continue;
      final savedPos = await _loadSavedPosition(t);
      if (savedPos <= Duration.zero) continue;
      final s = _states[t.key];
      if (s != null && s.position == Duration.zero) {
        _states[t.key] = s.copyWith(
          position: savedPos,
          duration: Duration(milliseconds: _savedDurations[t.key] ?? 0),
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // ── Download ─────────────────────────────────────────────────────────────

  /// Downloads [track] from the content catalog with live progress.
  /// A running download can be cancelled with [cancelDownload].
  Future<bool> download(
    RuqyahAudioTrack track, {
    void Function(int received, int total)? onProgress,
  }) async {
    final st = _states[track.key] ?? const RuqyahAudioTrackState();
    if (st.downloading) return false;

    final path = await localPath(track);
    final tmp = File('$path.part');
    final client = http.Client();
    _downloadClient = client;
    _cancelledDownloads.remove(track.key);
    _states[track.key] = st.copyWith(
      downloading: true,
      error: null,
      received: 0,
    );
    notifyListeners();

    var ok = false;
    try {
      final req = http.Request('GET', Uri.parse(track.url));
      final res = await client.send(req).timeout(const Duration(minutes: 15));
      if (res.statusCode != 200) {
        throw Exception('GET ${track.url} -> ${res.statusCode}');
      }
      final total = res.contentLength ?? -1;
      var received = 0;
      await tmp.parent.create(recursive: true);
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
          final s = _states[track.key];
          if (s != null && s.downloading) {
            _states[track.key] = s.copyWith(received: received, total: total);
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (await tmp.exists() && await tmp.length() > 1024) {
        await tmp.rename(path);
        ok = true;
      } else {
        throw Exception('Empty download for ${track.key}');
      }
    } catch (e) {
      AppLogger.warning(
          'RuqyahAudioService', 'Download failed ${track.key}: $e');
      final cancelled = _cancelledDownloads.remove(track.key);
      _states[track.key] =
          (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
        downloading: false,
        error: cancelled
            ? 'دانلود لغو شد.'
            : 'دانلود ناموفق بود؛ اتصال اینترنت را بررسی کنید.',
      );
      notifyListeners();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          AppLogger.warning('ruqyah_audio_service', 'operation failed');
        }
      }
      return false;
    } finally {
      _downloadClient = null;
    }

    _states[track.key] = (_states[track.key] ?? const RuqyahAudioTrackState())
        .copyWith(downloading: false, downloaded: true, error: null);
    notifyListeners();
    return ok;
  }

  /// Cancels the running download (if any). The `.part` file is removed.
  void cancelDownload() {
    try {
      _downloadClient?.close();
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'operation failed');
    }
    _downloadClient = null;
    for (final t in tracks) {
      final s = _states[t.key];
      if (s != null && s.downloading) {
        _cancelledDownloads.add(t.key);
        _states[t.key] = s.copyWith(downloading: false);
        notifyListeners();
      }
    }
  }

  /// Deletes the downloaded file of [track].
  Future<void> delete(RuqyahAudioTrack track) async {
    if (_playingKey == track.key) await stop();
    // The file is gone → the resume point no longer means anything.
    await _clearSavedPosition(track);
    try {
      final f = File(await localPath(track));
      if (await f.exists()) await f.delete();
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'Delete failed: $e');
    }
    _states[track.key] = (_states[track.key] ?? const RuqyahAudioTrackState())
        .copyWith(downloaded: false);
    notifyListeners();
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    // Audit 9-F: dispose() is async and nulls _player late, so a rapid
    // dispose→play cycle re-entered here, overwrote the stream subs and
    // leaked the first player. Any live player is torn down first.
    final stale = _player;
    if (stale != null) {
      _player = null;
      try {
        await stale.stop();
      } catch (_) {
        AppLogger.warning('ruqyah_audio_service', 'stale stop failed');
      }
      try {
        await stale.dispose();
      } catch (_) {
        AppLogger.warning('ruqyah_audio_service', 'stale dispose failed');
      }
    }
    final player = AudioPlayer(playerId: 'ruqyah_audio');
    _stateSub = player.onPlayerStateChanged.listen((s) {
      if (_disposed) return;
      final k = _playingKey;
      if (k == null) return;
      final playing = s == PlayerState.playing;
      final cur = _states[k] ?? const RuqyahAudioTrackState();
      if (cur.playing != playing) {
        _states[k] = cur.copyWith(playing: playing);
        notifyListeners();
        try {
          if (playing) {
            AppWakelock.acquire('ruqyah');
          } else {
            AppWakelock.release('ruqyah');
          }
        } catch (_) {
          AppLogger.warning('ruqyah_audio_service', 'wakelock toggle failed');
        }
      }
    });
    _completeSub = player.onPlayerComplete.listen((_) async {
      final k = _playingKey;
      // stop() persists whatever position the player last reported, so the
      // state must be zeroed before stopping — otherwise finishing a track
      // leaves a resume point at its very end, and the next play seeks there
      // and completes immediately.
      if (k != null) {
        final s = _states[k];
        if (s != null) _states[k] = s.copyWith(position: Duration.zero);
      }
      await stop();
      if (k != null) {
        final t = _trackByKey(k);
        if (t != null) await _clearSavedPosition(t);
      }
    });
    _posSub ??= player.onPositionChanged.listen((pos) {
      if (_disposed) return;
      final k = _playingKey;
      if (k == null) return;
      final cur = _states[k] ?? const RuqyahAudioTrackState();
      _states[k] = cur.copyWith(position: pos);
      // Persist the resume point at most every ~5 s while playing.
      final t = _trackByKey(k);
      if (t != null) {
        final last = _lastPersistedMs[k] ?? 0;
        if (pos.inMilliseconds - last >= 5000) {
          _lastPersistedMs[k] = pos.inMilliseconds;
          unawaited(_savePosition(t, pos));
        }
      }
      notifyListeners();
    });
    _durSub ??= player.onDurationChanged.listen((d) {
      if (_disposed) return;
      final k = _playingKey;
      if (k == null) return;
      final cur = _states[k] ?? const RuqyahAudioTrackState();
      _states[k] = cur.copyWith(duration: d);
      final t = _trackByKey(k);
      if (t != null && d > Duration.zero) {
        unawaited(_saveDuration(t, d));
      }
      notifyListeners();
    });
    _player = player;
  }

  /// Plays (or toggles) [track]. When it is already playing, pauses it.
  ///
  /// When the track is not downloaded yet, the download starts automatically
  /// (with live progress on the card) and playback begins once it finishes —
  /// raw.githubusercontent.com sends `content-disposition: attachment`, which
  /// some platform players mishandle when streaming, so we always play the
  /// local file.
  Future<void> togglePlay(RuqyahAudioTrack track) async {
    await _ensurePlayer();
    final token = ++_sessionToken;
    final player = _player;
    if (player == null) return;

    // Already this track → toggle pause/resume. Pausing persists the
    // position so it survives even if the app is killed right after.
    if (_playingKey == track.key) {
      try {
        if (player.state == PlayerState.playing) {
          await player.pause();
          final cur = _states[track.key];
          if (cur != null) {
            await _savePosition(track, cur.position);
            _lastPersistedMs[track.key] = cur.position.inMilliseconds;
          }
        } else {
          await player.resume();
        }
      } catch (e) {
        AppLogger.warning('RuqyahAudioService', 'toggle failed: $e');
      }
      return;
    }

    // Switching tracks → stop the old one first, persisting its position
    // so switching back later resumes where it left off.
    final oldKey = _playingKey;
    if (oldKey != null) {
      final oldTrack = _trackByKey(oldKey);
      final oldState = _states[oldKey];
      if (oldTrack != null &&
          oldState != null &&
          oldState.position > Duration.zero) {
        await _savePosition(oldTrack, oldState.position);
        _lastPersistedMs[oldKey] = oldState.position.inMilliseconds;
      }
      _states[oldKey] = (oldState ?? const RuqyahAudioTrackState()).copyWith(
        playing: false,
        loading: false,
        error: null,
      );
    }
    _states[track.key] =
        (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
      loading: true,
      error: null,
      position: Duration.zero,
      duration: Duration.zero,
    );
    notifyListeners();

    final path = await localPath(track);
    if (!(await isDownloaded(track))) {
      // Not on disk yet → download first, then play the local file.
      final ok = await download(track);
      if (_disposed || token != _sessionToken) return;
      if (!ok) {
        _states[track.key] =
            (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
          loading: false,
        );
        notifyListeners();
        return;
      }
    }

    try {
      await player.stop();
      if (_disposed || token != _sessionToken) return;
      _playingKey = track.key;
      _lastPersistedMs[track.key] = 0;
      await player.play(DeviceFileSource(path));
      // Resume from the persisted position (same session, another session
      // of the app, or after the process was killed).
      final resumePos = await _loadSavedPosition(track);
      if (!_disposed && token == _sessionToken && resumePos > Duration.zero) {
        try {
          await player.seek(resumePos);
          _states[track.key] =
              (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
            position: resumePos,
          );
        } catch (e) {
          AppLogger.warning('RuqyahAudioService', 'resume seek failed: $e');
        }
      }
      if (!_disposed && token == _sessionToken) {
        try {
          await AppWakelock.acquire('ruqyah');
        } catch (_) {
          AppLogger.warning('ruqyah_audio_service', 'wakelock enable failed');
        }
      }
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'play failed: $e');
      if (!_disposed && token == _sessionToken) {
        _states[track.key] =
            (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
          playing: false,
          loading: false,
          error: 'پخش ناموفق بود',
        );
        if (_playingKey == track.key) _playingKey = null;
        notifyListeners();
      }
    } finally {
      if (!_disposed && token == _sessionToken) {
        _states[track.key] =
            (_states[track.key] ?? const RuqyahAudioTrackState()).copyWith(
          loading: false,
        );
        notifyListeners();
      }
    }
  }

  /// Seeks to [position]. While a track is playing this moves the player;
  /// when nothing is playing it moves that track's saved resume point instead
  /// (the card shows the seek row for restored positions too, so the slider
  /// must not be a dead control). No-op until a valid duration is known; the
  /// position is clamped to the valid range.
  Future<void> seek(Duration position, {RuqyahAudioTrack? track}) async {
    final player = _player;
    final k = _playingKey;
    if (player == null || k == null) {
      final t = track;
      if (t == null) return;
      final saved = _states[t.key] ?? const RuqyahAudioTrackState();
      if (!saved.hasDuration) return;
      final updated =
          saved.copyWith(position: _clamp(position, saved.duration));
      _states[t.key] = updated;
      await _savePosition(t, updated.position);
      _lastPersistedMs[t.key] = updated.position.inMilliseconds;
      if (!_disposed) notifyListeners();
      return;
    }
    final cur = _states[k] ?? const RuqyahAudioTrackState();
    if (!cur.hasDuration) return;
    final target = _clamp(position, cur.duration);
    try {
      await player.seek(target);
      _states[k] = cur.copyWith(position: target);
      notifyListeners();
    } catch (e) {
      AppLogger.warning('RuqyahAudioService', 'seek failed: $e');
    }
  }

  static Duration _clamp(Duration position, Duration max) {
    if (position < Duration.zero) return Duration.zero;
    return position > max ? max : position;
  }

  /// Formats a duration as `m:ss` — or `h:mm:ss` for an hour or more, since
  /// full-ruqyah recordings can run well past 60 minutes.
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// Stops playback entirely (call when leaving the screen). The current
  /// position is persisted first so re-entry — or relaunching the app —
  /// resumes where the listener stopped.
  Future<void> stop() async {
    _sessionToken++;
    final k = _playingKey;
    if (k != null) {
      final t = _trackByKey(k);
      final s = _states[k];
      if (t != null && s != null && s.position > Duration.zero) {
        await _savePosition(t, s.position);
        _lastPersistedMs[k] = s.position.inMilliseconds;
      }
    }
    _playingKey = null;
    try {
      await _player?.stop();
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'operation failed');
    }
    var changed = false;
    for (final t in tracks) {
      final s = _states[t.key];
      if (s != null && (s.playing || s.loading)) {
        _states[t.key] = s.copyWith(playing: false, loading: false);
        changed = true;
      }
      // Playback positions are kept: they are the persisted resume points
      // the cards display after the app restarts.
    }
    try {
      await AppWakelock.release('ruqyah');
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'wakelock disable failed');
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_completeSub?.cancel());
    _posSub = null;
    _durSub = null;
    _stateSub = null;
    _completeSub = null;
    try {
      _downloadClient?.close();
    } catch (_) {
      AppLogger.warning('ruqyah_audio_service', 'operation failed');
    }
    unawaited(() async {
      try {
        await _player?.stop();
      } catch (_) {
        AppLogger.warning('ruqyah_audio_service', 'operation failed');
      }
      try {
        await _player?.dispose();
      } catch (_) {
        AppLogger.warning('ruqyah_audio_service', 'operation failed');
      }
    }());
    _player = null;
    super.dispose();
  }
}
