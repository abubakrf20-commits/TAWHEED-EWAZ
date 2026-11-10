import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/features/audio_library/audio_library_config.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_media_session.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// How playback behaves when the current track finishes.
enum AudioPlaybackMode {
  /// Stop at the end of the track.
  off,

  /// Continue with the next track of the same category (no wrap-around).
  category,

  /// Repeat the current track forever.
  one,
}

/// Download + playback state for a single audio-library track.
class AudioLibraryTrackState {
  /// Bytes received (during a download).
  final int received;

  /// Total bytes (-1 when unknown).
  final int total;

  /// Whether a download is running.
  final bool downloading;

  /// Whether the file exists locally.
  final bool downloaded;

  /// Whether this track is currently playing.
  final bool playing;

  /// Whether this track is buffering/loading (stream or source switch).
  final bool loading;

  /// Elapsed playback position.
  final Duration position;

  /// Media duration (Duration.zero until the player reports it).
  final Duration duration;

  /// Last error message (Persian), null when fine.
  final String? error;

  const AudioLibraryTrackState({
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

  /// 0..1 download progress; null when the total size is unknown.
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// True once the player has reported a valid (non-zero) duration.
  bool get hasDuration => duration > Duration.zero;

  AudioLibraryTrackState copyWith({
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
    return AudioLibraryTrackState(
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

/// A download whose host answered with a non-200 status.
class _AudioHttpStatusException implements Exception {
  final int statusCode;
  const _AudioHttpStatusException(this.statusCode);

  @override
  String toString() => 'HTTP $statusCode';
}

/// The transfer finished but produced no usable file — a local storage or
/// truncated-response problem, never an internet-connectivity one.
class _AudioEmptyDownloadException implements Exception {
  const _AudioEmptyDownloadException(this.received);

  final int received;

  @override
  String toString() => 'empty download ($received bytes)';
}

/// What a finished transfer looks like.
enum DownloadVerdict {
  /// The bytes on disk are the whole track.
  complete,

  /// Something arrived, but not all of it.
  truncated,

  /// Nothing usable arrived.
  empty,
}

/// Decides whether a finished transfer is really a whole file.
///
/// WHY this is a function and not an `if` inside `download()`: a transfer that
/// stops early still leaves more than a kilobyte on disk, and the old check
/// (`length > 1024`) called that a finished download — the card showed the
/// delete icon and the lecture played as silence, with nothing ever re-fetching
/// it. When the server declares a length the byte count has to agree with it;
/// `>=` because a decompressed stream may overshoot the declared size.
@visibleForTesting
DownloadVerdict downloadVerdict({
  required int received,
  required int declaredTotal,
  required int onDisk,
}) {
  if (onDisk <= 1024) return DownloadVerdict.empty;
  if (declaredTotal > 0 && received < declaredTotal) {
    return DownloadVerdict.truncated;
  }
  return DownloadVerdict.complete;
}

/// The response ended before the length it declared — a partial file.
///
/// Kept apart from [_AudioEmptyDownloadException] because the two mean
/// different things to the listener: an empty response is the server's
/// problem, a short one is a dropped connection mid-transfer.
class _AudioTruncatedDownloadException implements Exception {
  const _AudioTruncatedDownloadException(this.received, this.expected);

  final int received;
  final int expected;

  @override
  String toString() => 'truncated download ($received of $expected bytes)';
}

/// Manages hybrid playback of the audio-library tracks hosted on Supabase
/// Storage (public bucket).
///
/// • No local file → streams directly from the bucket (`UrlSource`; Supabase
///   answers Range requests with `206 audio/ogg`, so seeking works online).
/// • A downloaded file → plays the local copy (`DeviceFileSource`) and keeps
///   working offline.
/// • When a download finishes for the track that is currently streaming, the
///   player switches to the local file seamlessly at the same position.
/// • Playback position/duration are persisted per track, so the listener
///   resumes where they left off even after restarting the app.
/// • Advanced controls: playback speed (0.5×–2×, persisted), repeat/auto-next
///   across a category, ±15s skip, sleep timer, and one-tap category download.
///
/// Files live under `<ApplicationDocuments>/audio_library/<id>.opus`.
///
/// Why ChangeNotifier (not a Riverpod Notifier): it is a thin adapter over
/// the `audioplayers` event model — `notifyListeners()` maps 1:1 to player
/// state changes. It is a plain singleton reached via [instance]; widgets
/// subscribe with `AnimatedBuilder`/`ListenableBuilder` so only the playbar
/// subtree rebuilds, rather than the whole screen, on every position tick.
class AudioLibraryPlayer extends ChangeNotifier
    implements AudioLibraryMediaPlayback {
  AudioLibraryPlayer._();

  static final AudioLibraryPlayer instance = AudioLibraryPlayer._();

  static const String _dirName = 'audio_library';
  static const String _posKeyPrefix = 'audio_lib_pos_';
  static const String _durKeyPrefix = 'audio_lib_dur_';
  static const String _speedKey = 'audio_lib_speed';

  /// Manifest rows of the tracks currently on disk, so the library can still
  /// be listed and played when the audio host is unreachable.
  static const String _localIndexKey = 'audio_lib_local_index';

  final Map<String, AudioLibraryTrackState> _states = {};
  final Map<String, int> _savedPositions = {};
  final Map<String, int> _savedDurations = {};
  final Map<String, int> _lastPersistedMs = {};

  /// Farthest playback position seen this session per track — used as a seek
  /// limit while the real duration has not been reported yet (some devices/
  /// networks report it late for streamed Opus).
  final Map<String, Duration> _seenMax = {};

  // Category/playlist wiring (built by [configureCategories]).
  final Map<String, String?> _nextOf = {};

  /// First track of the speaker/category group owning each track — used to
  /// wrap repeat-category back inside the same group (never crossing into
  /// another speaker).
  final Map<String, String> _firstOfGroup = {};
  final Map<String, String> _trackCategory = {};
  final Map<String, AudioTrack> _trackById = {};

  /// Track id → owning speaker id (only for speaker-grouped categories).
  final Map<String, String> _speakerOfTrack = {};
  final Map<String, String> _speakerTitlesById = {};

  /// Ids written to the on-disk library index last time — the index is only
  /// rewritten when this set actually changes, not on every screen open.
  Set<String>? _localIndexIds;

  AudioPlayer? _player;
  String? _playingId;
  AudioTrack? _activeTrack;
  int _sessionToken = 0;
  bool _disposed = false;
  http.Client? _downloadClient;
  int _downloadGeneration = 0;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  // Fired on every position tick instead of the whole-screen notifyListeners(),
  // so only the active seek bar / mini player rebuild while the rest of the
  // library stays put. Value is the currently playing track's position.
  final ValueNotifier<Duration> _positionValue =
      ValueNotifier<Duration>(Duration.zero);
  // Set when we auto-pause for a transient interruption (call, other app), so
  // we only resume after the OS reports the interruption ended.
  bool _resumeAfterInterruption = false;

  // Advanced controls state.
  double _speed = 1.0;
  AudioPlaybackMode _repeatMode = AudioPlaybackMode.off;
  bool _autoNext = false;
  bool _shuffle = false;
  DateTime? _sleepDeadline;
  Duration? _sleepRemaining;
  Timer? _sleepTimer;
  bool _sessionConfigured = false;

  // ── New-content tracking ─────────────────────────────────────────────────
  // The manifest carries no "added at" timestamps, so "new" = a track id that
  // was not in the manifest on any previous load. Seen ids persist in prefs;
  // on the VERY first load (no seen set at all) everything is marked seen
  // silently so a fresh install doesn't show 139 "new" badges.
  static const String _seenIdsKey = 'audio_lib_seen_ids';

  /// Track ids present in the current manifest but absent from the last
  /// persisted seen-set. Cleared per id once the user sees/plays it.
  final Set<String> _newTrackIds = {};

  // Batch (category) download progress.
  bool _downloadingCategory = false;
  String? _downloadingCategoryId;
  int _categoryTotal = 0;
  int _categoryDone = 0;

  AudioLibraryTrackState stateOf(AudioTrack track) =>
      _states[track.id] ?? const AudioLibraryTrackState();

  /// Seek-bar maximum for [track]: the reported duration when known, otherwise
  /// the farthest position seen this session, otherwise the duration persisted
  /// from a previous session. Stays usable even on devices/networks that
  /// report the streamed duration late (or never).
  Duration seekLimitOf(AudioTrack track) {
    final st = _states[track.id];
    if (st != null && st.hasDuration) return st.duration;
    final seen = _seenMax[track.id];
    if (seen != null && seen > Duration.zero) return seen;
    return Duration(milliseconds: _savedDurations[track.id] ?? 0);
  }

  /// Id of the track currently playing (null when none).
  String? get playingId => _playingId;

  /// Live playhead of the active track. Widgets that render a seek bar or
  /// current-time label listen to this instead of the whole-screen listener.
  ValueListenable<Duration> get positionListenable => _positionValue;

  /// Track currently loaded into the active session (even when paused).
  @override
  AudioTrack? get activeTrack => _activeTrack;

  AudioLibraryTrackState? get activeState =>
      _playingId == null ? null : _states[_playingId];

  // ── Lock-screen / notification card (AudioLibraryMediaPlayback) ───────────

  /// Whether the loaded track is producing sound right now — the card's
  /// play/pause flip, distinct from [playingId] which survives pause.
  @override
  bool get isPlaying {
    final track = _activeTrack;
    return track != null && stateOf(track).playing;
  }

  /// Whether the loaded track is buffering (stream start / source switch).
  @override
  bool get isLoading {
    final track = _activeTrack;
    return track != null && stateOf(track).loading;
  }

  /// Live playhead of the active track, same notifier the seek bars listen to.
  @override
  Duration get position => _positionValue.value;

  /// Seek-bar length of the active track: the reported duration, or the
  /// persisted fallback while a streamed track has not reported one yet.
  @override
  Duration get duration {
    final track = _activeTrack;
    return track == null ? Duration.zero : seekLimitOf(track);
  }

  /// Teacher/speaker line of the active track (the mini player's byline).
  @override
  String? get activeByline => bylineOf(activeTrack?.id);

  // ── Advanced controls ─────────────────────────────────────────────────────

  @override
  double get speed => _speed;

  AudioPlaybackMode get repeatMode => _repeatMode;

  bool get autoNext => _autoNext;

  /// Whether the next-track pick (auto-next / repeat-category) jumps to a
  /// random track of the same group instead of the linear order.
  bool get shuffle => _shuffle;

  void setShuffle(bool enabled) {
    if (enabled == _shuffle) return;
    _shuffle = enabled;
    notifyListeners();
  }

  /// A random other track from the group (speaker or flat category) owning
  /// [trackId]; null when the group has no other track.
  String? _shuffledNextOf(String trackId) {
    final categoryId = _trackCategory[trackId];
    if (categoryId == null) return null;
    final speakerId = _speakerOfTrack[trackId];
    final groupIds = <String>[];
    for (final entry in _trackCategory.entries) {
      if (entry.value != categoryId) continue;
      if (speakerId != null && _speakerOfTrack[entry.key] != speakerId) {
        continue;
      }
      groupIds.add(entry.key);
    }
    if (groupIds.length <= 1) return null;
    groupIds.shuffle(math.Random());
    return groupIds.firstWhere((id) => id != trackId, orElse: () => trackId);
  }

  Duration? get sleepRemaining => _sleepRemaining;

  bool get sleepTimerActive =>
      _sleepDeadline != null &&
      (_sleepRemaining ?? Duration.zero) > Duration.zero;

  bool get downloadingCategory => _downloadingCategory;

  String? get downloadingCategoryId => _downloadingCategoryId;

  int get categoryDownloadTotal => _categoryTotal;

  int get categoryDownloadDone => _categoryDone;

  double? get categoryProgress => _categoryTotal > 0
      ? (_categoryDone / _categoryTotal).clamp(0.0, 1.0)
      : null;

  @visibleForTesting
  Map<String, String?> get debugNextOf => _nextOf;

  /// Category id of [trackId] (null when the track is unknown to the
  /// configured manifest).
  String? categoryOf(String? trackId) =>
      trackId == null ? null : _trackCategory[trackId];

  /// Speaker id owning [trackId] (null when the track's category is not
  /// speaker-grouped, so the whole category acts as one group).
  String? speakerOf(String? trackId) =>
      trackId == null ? null : _speakerOfTrack[trackId];

  /// Persian speaker title for [trackId], used as the byline in the mini
  /// player. Null when the category has no speaker grouping.
  String? speakerTitleOf(String? trackId) {
    final speakerId = trackId == null ? null : _speakerOfTrack[trackId];
    if (speakerId == null) return null;
    return _speakerTitlesById[speakerId];
  }

  /// Byline shown next to the [trackId] in compact surfaces (mini player):
  /// the speaker title for speaker-grouped categories, or the category-wide
  /// teacher name. Categories without a teacher (e.g. anasheed language
  /// sections) get no byline.
  String? bylineOf(String? trackId) {
    final categoryId = categoryOf(trackId);
    if (categoryId == null) return null;
    if (AudioCategory.bylineForCategory(categoryId) == null) return null;
    return speakerTitleOf(trackId) ??
        AudioCategory.bylineForCategory(categoryId);
  }

  /// First track of the group (speaker or flat category) owning [trackId].
  /// Null when [trackId] is unknown.
  String? firstOfGroup(String? trackId) =>
      trackId == null ? null : _firstOfGroup[trackId];

  @visibleForTesting
  Map<String, String> get debugFirstOfGroup => _firstOfGroup;

  /// Test-only shuffled-next pick for [trackId].
  @visibleForTesting
  String? debugShuffledNextOf(String trackId) => _shuffledNextOf(trackId);

  /// Clears all session state so a test can re-run [configureCategories] as
  /// if the app restarted (persisted prefs are NOT touched).
  @visibleForTesting
  void debugResetForTest() {
    _nextOf.clear();
    _firstOfGroup.clear();
    _trackCategory.clear();
    _trackById.clear();
    _speakerOfTrack.clear();
    _speakerTitlesById.clear();
    _states.clear();
    _newTrackIds.clear();
    _localIndexIds = null;
    _dirCached = null;
    _sessionConfigured = false;
  }

  /// Builds the next/previous playlist wiring from the manifest categories.
  Future<void> configureCategories(List<AudioCategory> categories) async {
    _nextOf.clear();
    _firstOfGroup.clear();
    _trackCategory.clear();
    _trackById.clear();
    _speakerOfTrack.clear();
    _speakerTitlesById.clear();
    for (final category in categories) {
      final grouped = category.hasSpeakers;
      final groups = <(String, List<AudioTrack>)>[
        for (final s in category.speakers) (s.id, s.tracks),
        if (!grouped) (category.id, category.tracks),
      ];
      for (final (groupId, groupTracks) in groups) {
        final firstId = groupTracks.isEmpty ? null : groupTracks.first.id;
        for (var i = 0; i < groupTracks.length; i++) {
          final t = groupTracks[i];
          _trackById[t.id] = t;
          _trackCategory[t.id] = category.id;
          if (grouped) {
            _speakerOfTrack[t.id] = groupId;
            final speaker = category.speakers.firstWhere(
              (s) => s.id == groupId,
              orElse: () =>
                  AudioSpeaker(id: groupId, title: '', tracks: const []),
            );
            _speakerTitlesById[groupId] = speaker.title;
          }
          _nextOf[t.id] =
              i + 1 < groupTracks.length ? groupTracks[i + 1].id : null;
          if (firstId != null) _firstOfGroup[t.id] = firstId;
        }
      }
    }
    await _computeNewTracks(categories);
    await _loadSpeed();
    // Preload persisted positions/durations so the seek bar has a duration
    // available immediately, even on devices that report it late (or never).
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in _trackById.keys) {
        _savedPositions[id] = prefs.getInt('$_posKeyPrefix$id') ?? 0;
        _savedDurations[id] = prefs.getInt('$_durKeyPrefix$id') ?? 0;
      }
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
  }

  // ── New-content tracking ─────────────────────────────────────────────────

  /// Whether [trackId] arrived with a manifest update the user has not seen.
  bool isNewTrack(String trackId) => _newTrackIds.contains(trackId);

  /// Number of unseen tracks per category id (for header badges).
  int newCountForCategory(String categoryId) {
    var n = 0;
    for (final t in _trackById.values) {
      if (_trackCategory[t.id] == categoryId && _newTrackIds.contains(t.id)) {
        n++;
      }
    }
    return n;
  }

  /// Number of unseen tracks inside one speaker group.
  int newCountForSpeaker(String categoryId, String speakerId) {
    var n = 0;
    for (final entry in _speakerOfTrack.entries) {
      if (_trackCategory[entry.key] == categoryId &&
          entry.value == speakerId &&
          _newTrackIds.contains(entry.key)) {
        n++;
      }
    }
    return n;
  }

  /// Marks every current manifest track as seen (call after the user has
  /// viewed the library listing, so badges clear on the next diff).
  Future<void> markAllTracksSeen() async {
    if (_newTrackIds.isEmpty) return;
    _newTrackIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenIdsKey, _trackById.keys.toList());
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'mark seen failed: $e');
    }
    notifyListeners();
  }

  /// Persists the current manifest ids as the seen-set and flags ids that
  /// were NOT in the previous seen-set as new. First ever run: store all ids
  /// with no badges (a fresh install would otherwise flag everything).
  Future<void> _computeNewTracks(List<AudioCategory> categories) async {
    final currentIds = _trackById.keys.toSet();
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getStringList(_seenIdsKey);
      if (previous == null) {
        // First ever load: everything is "known", nothing is new.
        await prefs.setStringList(_seenIdsKey, currentIds.toList());
        _newTrackIds.clear();
        return;
      }
      final previousSet = previous.toSet();
      _newTrackIds
        ..clear()
        ..addAll(currentIds.difference(previousSet));
      // Persist the CURRENT ids as the seen-set (not a growing union):
      // re-configures with the same manifest stop flagging, while a track
      // that was removed and later re-uploaded correctly re-flags as new.
      await prefs.setStringList(_seenIdsKey, currentIds.toList());
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'new-track diff failed: $e');
      _newTrackIds.clear();
    }
  }

  /// Playback speed in 0.5×…2×; persisted across sessions.
  Future<void> setSpeed(double value) async {
    final clamped = value.clamp(0.5, 2.0);
    if (clamped == _speed) {
      if (_player != null) {
        try {
          await _player!.setPlaybackRate(clamped);
        } catch (_) {
          AppLogger.warning('audio_library_player', 'operation failed');
        }
      }
      return;
    }
    _speed = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedKey, clamped);
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'speed save failed: $e');
    }
    try {
      await _player?.setPlaybackRate(clamped);
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
    notifyListeners();
  }

  Future<void> _loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_speedKey);
      _speed = (v == null || v < 0.5 || v > 2.0) ? 1.0 : v;
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
      _speed = 1.0;
    }
  }

  void setRepeatMode(AudioPlaybackMode mode) {
    if (mode == _repeatMode) return;
    _repeatMode = mode;
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case AudioPlaybackMode.off:
        _repeatMode = AudioPlaybackMode.one;
      case AudioPlaybackMode.one:
        _repeatMode = AudioPlaybackMode.category;
      case AudioPlaybackMode.category:
        _repeatMode = AudioPlaybackMode.off;
    }
    notifyListeners();
  }

  void setAutoNext(bool enabled) {
    if (enabled == _autoNext) return;
    _autoNext = enabled;
    notifyListeners();
  }

  /// Arms a sleep timer: playback stops after [duration] (null cancels).
  /// The remaining time is exposed via [sleepRemaining] and ticked every
  /// second.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null || duration <= Duration.zero) {
      _sleepDeadline = null;
      _sleepRemaining = null;
      _sleepTimer = null;
      notifyListeners();
      return;
    }
    _sleepDeadline = DateTime.now().add(duration);
    _sleepRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _sleepDeadline == null) return;
      final remain = _sleepDeadline!.difference(DateTime.now());
      final rem = remain.isNegative ? Duration.zero : remain;
      _sleepRemaining = rem;
      notifyListeners();
      if (rem <= Duration.zero) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _sleepDeadline = null;
        _sleepRemaining = null;
        final p = _player;
        if (_playingId != null && p != null && p.state == PlayerState.playing) {
          stop();
        } else {
          notifyListeners();
        }
      }
    });
    notifyListeners();
  }

  // ── Persisted playback position ───────────────────────────────────────────

  Future<Duration> _loadSavedPosition(String id) async {
    final cached = _savedPositions[id];
    if (cached != null) return Duration(milliseconds: cached);
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedPositions[id] = prefs.getInt('$_posKeyPrefix$id') ?? 0;
      _savedDurations[id] = prefs.getInt('$_durKeyPrefix$id') ?? 0;
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
      _savedPositions[id] ??= 0;
    }
    return Duration(milliseconds: _savedPositions[id] ?? 0);
  }

  Future<void> _savePosition(String id, Duration position) async {
    final ms = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    _savedPositions[id] = ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_posKeyPrefix$id', ms);
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'save position failed: $e');
    }
  }

  Future<void> _clearSavedPosition(String id) async {
    _savedPositions[id] = 0;
    _savedDurations[id] = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_posKeyPrefix$id');
      await prefs.remove('$_durKeyPrefix$id');
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'clear position failed: $e');
    }
  }

  Future<void> _saveDuration(String id, Duration duration) async {
    final ms = duration.inMilliseconds < 0 ? 0 : duration.inMilliseconds;
    _savedDurations[id] = ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_durKeyPrefix$id', ms);
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'save duration failed: $e');
    }
  }

  // ── Paths ─────────────────────────────────────────────────────────────────

  /// Cached audio directory path. [getApplicationDocumentsDirectory] is a
  /// platform-channel round trip; before caching, [refresh] awaited it once
  /// PER TRACK (139 manifest entries → 139 channel calls on first open).
  Directory? _dirCached;

  Future<Directory> _dir() async {
    final cached = _dirCached;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    return _dirCached = Directory(p.join(docs.path, _dirName));
  }

  /// Local file path for a downloaded track. The extension is derived from the
  /// track's manifest `file` field (e.g. `.mp3` for Badri tracks) so that
  /// non-Opus uploads keep their original container. Falls back to `.opus`
  /// when the track is unknown.
  Future<String> localPath(String id) async {
    // One lookup, no null assertion: the map is read once and the empty case
    // falls through to the same '.opus' default the missing-track case used.
    final ext = p.extension(_trackById[id]?.file ?? '');
    return p.join((await _dir()).path, '$id${ext.isEmpty ? '.opus' : ext}');
  }

  Future<bool> isDownloaded(String id) async {
    try {
      final f = File(await localPath(id));
      return await f.exists() && await f.length() > 1024;
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
      return false;
    }
  }

  /// Refreshes downloaded flags, restores saved resume points and reloads the
  /// persisted playback speed (call once the manifest is loaded).
  ///
  /// The downloaded checks run CONCURRENTLY: serially they were 139 awaited
  /// file-stat round trips, a large slice of the first-open latency.
  Future<void> refresh(List<AudioTrack> tracks) async {
    await _loadSpeed();
    final flags = await Future.wait(
      [for (final t in tracks) isDownloaded(t.id)],
    );
    final onDisk = <AudioTrack>[];
    for (var i = 0; i < tracks.length; i++) {
      final ok = flags[i];
      if (ok) onDisk.add(tracks[i]);
      final cur = _states[tracks[i].id];
      if (cur == null) {
        _states[tracks[i].id] = AudioLibraryTrackState(downloaded: ok);
      } else if (cur.downloaded != ok) {
        _states[tracks[i].id] = cur.copyWith(downloaded: ok);
      }
    }
    await _syncAll();
    notifyListeners();
    await _saveLocalIndex(onDisk);
  }

  /// Remembers the manifest rows of every track on disk (titles, object keys,
  /// category and speaker grouping). [buildLocalManifest] replays them when the
  /// audio host cannot be reached, so a hosting outage never locks a user out
  /// of the lectures they already downloaded.
  Future<void> _saveLocalIndex(List<AudioTrack> onDisk) async {
    final ids = {for (final t in onDisk) t.id};
    if (_localIndexIds != null && setEquals(ids, _localIndexIds!)) return;
    _localIndexIds = ids;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _localIndexKey,
          jsonEncode([
            for (final t in onDisk)
              {
                'id': t.id,
                'title': t.title,
                'file': t.file,
                'sizeBytes': t.sizeBytes,
                'category': _trackCategory[t.id],
                'speaker': _speakerOfTrack[t.id],
                'speakerTitle': _speakerTitlesById[_speakerOfTrack[t.id]],
              },
          ]));
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'local index write failed: $e');
    }
  }

  /// Rebuilds the library from [_saveLocalIndex], keeping only the rows whose
  /// file is still on disk. Null when nothing is stored — the caller then has
  /// no local library to show and reports the load failure instead.
  Future<AudioLibraryManifest?> buildLocalManifest() async {
    List<dynamic> rows;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localIndexKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      rows = decoded;
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'local index read failed: $e');
      return null;
    }

    // Drop rows whose file was deleted (or moved off a cleaned cache dir).
    final present = <Map<String, dynamic>>[];
    final alive = await Future.wait([
      for (final row in rows)
        if (row is Map<String, dynamic>)
          isDownloaded(row['id'] as String? ?? '')
        else
          Future<bool>.value(false),
    ]);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map<String, dynamic>) continue;
      if (alive[i]) present.add(row);
    }
    if (present.isEmpty) return null;

    // Group by category, then by speaker, in the stored order.
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final row in present) {
      byCategory
          .putIfAbsent(row['category'] as String? ?? 'misc', () => [])
          .add(row);
    }
    final categories = <AudioCategory>[];
    byCategory.forEach((categoryId, categoryRows) {
      final bySpeaker = <String, List<AudioTrack>>{};
      final speakerTitles = <String, String>{};
      final flat = <AudioTrack>[];
      for (final row in categoryRows) {
        final track = AudioTrack(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? '',
          file: row['file'] as String? ?? '',
          sizeBytes: (row['sizeBytes'] as num?)?.toInt() ?? 0,
        );
        flat.add(track);
        final speakerId = row['speaker'] as String?;
        if (speakerId == null || speakerId.isEmpty) continue;
        bySpeaker.putIfAbsent(speakerId, () => []).add(track);
        speakerTitles[speakerId] = row['speakerTitle'] as String? ?? '';
      }
      categories.add(AudioCategory(
        id: categoryId,
        tracks: flat,
        speakers: [
          for (final entry in bySpeaker.entries)
            AudioSpeaker(
              id: entry.key,
              title: speakerTitles[entry.key] ?? '',
              tracks: entry.value,
            ),
        ],
      ));
    });
    return AudioLibraryManifest(version: 0, categories: categories);
  }

  Future<bool> _syncAll() async {
    var changed = false;
    final ids = _states.keys.toList();
    for (final id in ids) {
      if (_playingId == id) continue;
      final savedPos = await _loadSavedPosition(id);
      if (savedPos <= Duration.zero) continue;
      final s = _states[id];
      if (s != null && s.position == Duration.zero) {
        _states[id] = s.copyWith(
          position: savedPos,
          duration: Duration(milliseconds: _savedDurations[id] ?? 0),
        );
        changed = true;
      }
    }
    return changed;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// True when the track's audio is already on disk.
  ///
  /// WHY a stat instead of `state.downloaded`: that flag only becomes true once
  /// `refresh()` lands, and both the per-track button and «دانلود همه» are
  /// tappable before it does — so the app re-downloaded audio the listener had
  /// already paid data for. The file is the ground truth.
  Future<bool> _isOnDisk(String id) async {
    try {
      final f = File(await localPath(id));
      return await f.exists() && await f.length() > 1024;
    } catch (e) {
      AppLogger.warning('audio_library_player', 'stat failed for $id: $e');
      return false;
    }
  }

  /// Downloads [track] into the app documents with live progress. When the
  /// track is currently streaming, playback switches to the local file at the
  /// same position once the download completes.
  Future<bool> download(AudioTrack track) async {
    final st = _states[track.id] ?? const AudioLibraryTrackState();
    if (st.downloading) return false;
    // `cancelDownload` bumps this; a failure that arrives after the bump is the
    // cancellation, not a fault.
    final gen = _downloadGeneration;
    if (await _isOnDisk(track.id)) {
      // Already here; make the badge agree and do not touch the network.
      _states[track.id] = st.copyWith(downloaded: true, received: 0);
      notifyListeners();
      return false;
    }

    final path = await localPath(track.id);
    final tmp = File('$path.part');
    final client = http.Client();
    _downloadClient = client;
    _states[track.id] = st.copyWith(
      downloading: true,
      error: null,
      received: 0,
    );
    notifyListeners();

    var ok = false;
    try {
      final req = http.Request(
        'GET',
        Uri.parse(AudioLibraryConfig.objectUrl(track.file)),
      );
      final res = await client.send(req).timeout(const Duration(minutes: 15));
      if (res.statusCode != 200) {
        throw _AudioHttpStatusException(res.statusCode);
      }
      final total = res.contentLength ?? -1;
      var received = 0;
      await tmp.parent.create(recursive: true);
      final sink = tmp.openWrite();
      // Throttle progress repaints: a multi-MB file arrives in hundreds of
      // chunks, and notifying on each one rebuilt the whole download list.
      var lastNotified = -1;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          // Always emit the final chunk so the bar lands exactly on 100%.
          final pct = total > 0 ? (received * 100) ~/ total : -1;
          if (pct != lastNotified) {
            lastNotified = pct;
            final s = _states[track.id];
            if (s != null && s.downloading) {
              _states[track.id] = s.copyWith(received: received, total: total);
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }
      final length = await tmp.exists() ? await tmp.length() : 0;
      final verdict =
          downloadVerdict(received: received, declaredTotal: total, onDisk: length);
      if (verdict == DownloadVerdict.complete) {
        await tmp.rename(path);
        ok = true;
      } else if (verdict == DownloadVerdict.truncated) {
        throw _AudioTruncatedDownloadException(received, total);
      } else {
        throw _AudioEmptyDownloadException(received);
      }
    } catch (e) {
      if (gen != _downloadGeneration) {
        // The listener cancelled. Closing the client throws, and the old code
        // painted «اتصال اینترنت را بررسی کنید» over their own decision.
        AppLogger.warning(
            'AudioLibraryPlayer', 'Download cancelled ${track.id}');
        _states[track.id] = (_states[track.id] ??
                const AudioLibraryTrackState())
            .copyWith(downloading: false, received: 0, error: null);
        notifyListeners();
        if (await tmp.exists()) {
          try {
            await tmp.delete();
          } catch (e) {
            AppLogger.warning('audio_library_player', 'part cleanup: $e');
          }
        }
        return false;
      }
      AppLogger.warning(
          'AudioLibraryPlayer', 'Download failed ${track.id}: $e');
      // A host that answers (402/403/500…) is not the listener's connection, and
      // neither is a full disk or a truncated response — only a transport
      // failure may tell them to check the internet. Mapping every non-200 to
      // "check your internet" made real failures impossible to diagnose.
      final String message;
      if (e is _AudioHttpStatusException) {
        message = 'سرور کتابخانه پاسخ نداد (کد ${e.statusCode}).';
      } else if (e is _AudioTruncatedDownloadException) {
        message = 'دانلود کامل نشد؛ فایل ناقص بود و ذخیره نشد. دوباره تلاش کنید.';
      } else if (e is _AudioEmptyDownloadException || e is FileSystemException) {
        message = 'ذخیرهٔ فایل روی حافظهٔ دستگاه ناموفق بود؛ فضای خالی را '
            'بررسی کنید.';
      } else {
        message = 'دانلود ناموفق بود؛ اتصال اینترنت را بررسی کنید.';
      }
      _states[track.id] =
          (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
        downloading: false,
        error: message,
      );
      notifyListeners();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          AppLogger.warning('audio_library_player', 'operation failed');
        }
      }
      return false;
    } finally {
      if (_downloadClient == client) _downloadClient = null;
    }

    if (ok) {
      _states[track.id] =
          (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
        downloading: false,
        downloaded: true,
        error: null,
      );
      notifyListeners();
      await _switchToLocalIfPlaying(track);
    }
    return ok;
  }

  /// Queues a whole category for offline download, one track at a time.
  /// Skips already-downloaded tracks; honours [cancelDownload] between items.
  Future<void> downloadCategory(
    String categoryId,
    List<AudioTrack> tracks,
  ) async {
    if (_downloadingCategory || tracks.isEmpty) return;
    _downloadingCategory = true;
    _downloadingCategoryId = categoryId;
    _categoryTotal = tracks.length;
    _categoryDone = 0;
    final gen = ++_downloadGeneration;
    notifyListeners();
    for (final t in tracks) {
      if (gen != _downloadGeneration) break;
      final st = _states[t.id] ?? const AudioLibraryTrackState();
      if (st.downloaded || await _isOnDisk(t.id)) {
        _categoryDone++;
        notifyListeners();
        continue;
      }
      await download(t);
      if (gen != _downloadGeneration) break;
      _categoryDone++;
      notifyListeners();
    }
    _downloadingCategory = false;
    _downloadingCategoryId = null;
    notifyListeners();
  }

  /// Stops the current download and any running batch (category) download.
  /// The `.part` file is removed.
  void cancelDownload() {
    _downloadGeneration++;
    try {
      _downloadClient?.close();
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
    _downloadClient = null;
    final ids = _states.keys.toList();
    for (final id in ids) {
      final s = _states[id];
      if (s != null && s.downloading) {
        _states[id] = s.copyWith(downloading: false);
      }
    }
    _downloadingCategory = false;
    _downloadingCategoryId = null;
    notifyListeners();
  }

  /// Deletes the downloaded file of [track]. Playback is stopped first and the
  /// saved resume point is forgotten (the file no longer exists).
  Future<void> delete(AudioTrack track) async {
    if (_playingId == track.id) await stop();
    await _clearSavedPosition(track.id);
    try {
      final f = File(await localPath(track.id));
      if (await f.exists()) await f.delete();
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'Delete failed: $e');
    }
    _states[track.id] =
        (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
      downloaded: false,
    );
    notifyListeners();
  }

  /// Total bytes occupied by downloaded library files on disk.
  Future<int> downloadedBytes() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File && (e.path.endsWith('.opus') || e.path.endsWith('.mp3'))) {
          total += await e.length();
        }
      }
      return total;
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
      return 0;
    }
  }

  /// Deletes every downloaded library file (bulk storage management). Stops
  /// playback first and forgets the resume points. Returns the number of
  /// files removed.
  Future<int> deleteAllDownloaded(List<AudioTrack> tracks) async {
    await stop();
    var removed = 0;
    for (final t in tracks) {
      final st = _states[t.id];
      final wasDownloaded = st?.downloaded ?? false;
      try {
        final f = File(await localPath(t.id));
        if (await f.exists()) {
          await f.delete();
          removed++;
        }
        await _clearSavedPosition(t.id);
      } catch (e) {
        AppLogger.warning('AudioLibraryPlayer', 'bulk delete ${t.id}: $e');
      }
      if (wasDownloaded) {
        _states[t.id] =
            (_states[t.id] ?? const AudioLibraryTrackState()).copyWith(
          downloaded: false,
        );
      }
    }
    // Stray .opus and .mp3 files no longer in the manifest (stale ids) are removed too.
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        final known = <String>{}
          ..addAll(tracks.map((t) => '${t.id}.opus'))
          ..addAll(tracks.map((t) => '${t.id}.mp3'));
        await for (final e in dir.list()) {
          if (e is File &&
              (e.path.endsWith('.opus') || e.path.endsWith('.mp3')) &&
              !known.contains(e.path.split(Platform.pathSeparator).last)) {
            await e.delete();
            removed++;
          }
        }
      }
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
    notifyListeners();
    return removed;
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    // Configure the OS audio session once (music profile: keeps playing in the
    // background and routes over bluetooth/DND properly).
    if (!_sessionConfigured) {
      _sessionConfigured = true;
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (e) {
        AppLogger.warning('AudioLibraryPlayer', 'audio session: $e');
      }
    }
    final player = AudioPlayer(playerId: 'audio_library');
    _stateSub = player.onPlayerStateChanged.listen((s) {
      if (_disposed) return;
      final id = _playingId;
      if (id == null) return;
      final playing = s == PlayerState.playing;
      final cur = _states[id] ?? const AudioLibraryTrackState();
      if (cur.playing != playing) {
        _states[id] = cur.copyWith(playing: playing);
        notifyListeners();
        try {
          if (playing) {
            AppWakelock.acquire('audio_library');
          } else {
            AppWakelock.release('audio_library');
          }
        } catch (_) {
          AppLogger.warning('audio_library_player', 'wakelock toggle failed');
        }
      }
    });
    _completeSub = player.onPlayerComplete.listen((_) {
      unawaited(_handleTrackComplete());
    });
    _posSub ??= player.onPositionChanged.listen((pos) {
      if (_disposed) return;
      final id = _playingId;
      if (id == null) return;
      final cur = _states[id] ?? const AudioLibraryTrackState();
      _states[id] = cur.copyWith(position: pos);
      final prevMax = _seenMax[id];
      if (prevMax == null || pos > prevMax) _seenMax[id] = pos;
      final last = _lastPersistedMs[id] ?? 0;
      if (pos.inMilliseconds - last >= 5000) {
        _lastPersistedMs[id] = pos.inMilliseconds;
        unawaited(_savePosition(id, pos));
      }
      _positionValue.value = pos;
    });
    _durSub ??= player.onDurationChanged.listen((d) {
      if (_disposed) return;
      final id = _playingId;
      if (id == null) return;
      final cur = _states[id] ?? const AudioLibraryTrackState();
      _states[id] = cur.copyWith(duration: d);
      if (d > Duration.zero) {
        unawaited(_saveDuration(id, d));
      }
      notifyListeners();
    });
    _player = player;
    _wireInterruption(player);
  }

  /// Pauses for transient audio interruptions (incoming call, another app
  /// taking focus) and resumes afterwards when the OS says it is safe to.
  void _wireInterruption(AudioPlayer player) {
    if (_interruptionSub != null) return;
    unawaited(() async {
      try {
        final session = await AudioSession.instance;
        _interruptionSub = session.interruptionEventStream.listen((event) {
          if (_disposed) return;
          if (event.begin) {
            if (player.state == PlayerState.playing) {
              _resumeAfterInterruption = true;
              unawaited(player.pause());
            }
          } else if (_resumeAfterInterruption) {
            _resumeAfterInterruption = false;
            try {
              unawaited(player.resume());
            } catch (e) {
              AppLogger.warning(
                  'AudioLibraryPlayer', 'resume after interruption: $e');
            }
          }
        });
      } catch (e) {
        AppLogger.warning('AudioLibraryPlayer', 'interruption wiring: $e');
      }
    }());
  }

  /// Plays (or toggles) [track]. Streams when not downloaded, plays the local
  /// file otherwise. Switching tracks persists the previous position so
  /// coming back later resumes where the listener stopped.
  Future<void> togglePlay(AudioTrack track) async {
    if (_playingId == track.id) {
      final player = _player;
      if (player == null) return;
      if (player.state == PlayerState.playing) {
        await pauseActive();
      } else {
        await resumeActive();
      }
      return;
    }
    await _playTrack(track);
  }

  /// Resumes the active (paused) track. Driven by the lock-screen card;
  /// no-op when nothing is loaded.
  @override
  Future<void> resumeActive() async {
    final player = _player;
    if (player == null || _playingId == null) return;
    try {
      await player.resume();
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'resume failed: $e');
    }
  }

  /// Pauses the active track (persisting the position) — the card's
  /// counterpart of the mini player's pause. No-op when nothing is loaded.
  @override
  Future<void> pauseActive() async {
    final player = _player;
    final id = _playingId;
    if (player == null || id == null) return;
    try {
      if (player.state == PlayerState.playing) {
        await player.pause();
        final cur = _states[id];
        if (cur != null) {
          await _savePosition(id, cur.position);
          _lastPersistedMs[id] = cur.position.inMilliseconds;
        }
      }
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'pause failed: $e');
    }
  }

  Future<void> _playTrack(AudioTrack track) async {
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;
    final token = ++_sessionToken;

    final oldId = _playingId;
    if (oldId != null) {
      final oldState = _states[oldId];
      if (oldState != null && oldState.position > Duration.zero) {
        await _savePosition(oldId, oldState.position);
        _lastPersistedMs[oldId] = oldState.position.inMilliseconds;
      }
      if (oldState != null) {
        _states[oldId] =
            oldState.copyWith(playing: false, loading: false, error: null);
      }
    }
    _states[track.id] =
        (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
      loading: true,
      error: null,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _activeTrack = track;
    _positionValue.value = Duration.zero;
    notifyListeners();

    final downloaded = await isDownloaded(track.id);
    if (_disposed || token != _sessionToken) return;

    try {
      await player.stop();
      if (_disposed || token != _sessionToken) return;
      _playingId = track.id;
      _lastPersistedMs[track.id] = 0;
      // Background listening: every play attempt rides the lock-screen
      // session (idempotent — it inits once per process and only mirrors
      // this player afterwards).
      unawaited(AudioLibraryMediaSession.instance.start(this));
      if (downloaded) {
        await player.play(DeviceFileSource(await localPath(track.id)));
      } else {
        await player.play(
          UrlSource(AudioLibraryConfig.objectUrl(track.file)),
        );
      }
      await player.setPlaybackRate(_speed);
      // Resume from the persisted position (same session, another session, or
      // after the process was killed).
      final resumePos = await _loadSavedPosition(track.id);
      // A lecture paused in its last seconds used to reopen at the end: the
      // listener tapped play, heard two seconds, and the track stopped — which
      // reads as broken. Near the end, "resume" means "start over".
      final knownDur = Duration(milliseconds: _savedDurations[track.id] ?? 0);
      final nearEnd = knownDur > const Duration(seconds: 20) &&
          resumePos >= knownDur - const Duration(seconds: 5);
      if (nearEnd) {
        unawaited(_clearSavedPosition(track.id));
      }
      if (!_disposed &&
          token == _sessionToken &&
          resumePos > Duration.zero &&
          !nearEnd) {
        try {
          await player.seek(resumePos);
          _states[track.id] =
              (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
            position: resumePos,
          );
          _positionValue.value = resumePos;
          await player.setPlaybackRate(_speed);
        } catch (e) {
          AppLogger.warning('AudioLibraryPlayer', 'resume seek failed: $e');
        }
      }
      // Some devices/networks report the streamed duration late (or never).
      // Seed the seek bar with the duration persisted from a previous session
      // so it is usable immediately.
      final savedDur = Duration(milliseconds: _savedDurations[track.id] ?? 0);
      final justStarted = _states[track.id];
      if (savedDur > Duration.zero &&
          justStarted != null &&
          !justStarted.hasDuration) {
        _states[track.id] = justStarted.copyWith(duration: savedDur);
        notifyListeners();
      }
      if (!_disposed && token == _sessionToken) {
        try {
          await AppWakelock.acquire('audio_library');
        } catch (_) {
          AppLogger.warning('audio_library_player', 'wakelock enable failed');
        }
      }
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'play failed: $e');
      if (!_disposed && token == _sessionToken) {
        _states[track.id] =
            (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
          playing: false,
          loading: false,
          error: 'پخش ناموفق بود',
        );
        if (_playingId == track.id) _playingId = null;
        _activeTrack = null;
        notifyListeners();
        // Nothing is playing after a failed start, so the card goes too —
        // otherwise it would advertise a track that never began.
        unawaited(AudioLibraryMediaSession.instance.stop());
      }
    } finally {
      if (!_disposed && token == _sessionToken) {
        _states[track.id] =
            (_states[track.id] ?? const AudioLibraryTrackState()).copyWith(
          loading: false,
        );
        notifyListeners();
      }
    }
  }

  /// Decides what to play when the current track completes, based on the
  /// repeat mode and auto-next flag.
  Future<void> _handleTrackComplete() async {
    final id = _playingId;
    if (id == null) return;
    final cur = _states[id];
    if (cur != null) {
      _states[id] = cur.copyWith(playing: false, position: Duration.zero);
      _positionValue.value = Duration.zero;
      notifyListeners();
    }
    await _clearSavedPosition(id);
    _lastPersistedMs[id] = 0;

    final current = _activeTrack;
    if (current == null) {
      await stop();
      return;
    }

    AudioTrack? next;
    switch (_repeatMode) {
      case AudioPlaybackMode.one:
        next = current;
      case AudioPlaybackMode.off:
      case AudioPlaybackMode.category:
        final String? nextId;
        if (_shuffle) {
          nextId = _shuffledNextOf(id);
        } else {
          nextId = _nextOf[id];
        }
        if (nextId != null &&
            (_autoNext || _repeatMode == AudioPlaybackMode.category)) {
          next = _trackById[nextId];
        } else if (_repeatMode == AudioPlaybackMode.category) {
          // Reached the last track of the speaker/category group → wrap to
          // the first track of the same group (never another speaker).
          final firstId = _firstOfGroup[id];
          if (firstId != null) next = _trackById[firstId];
        }
    }

    if (next == null) {
      await stop();
      return;
    }
    if (next.id == id) {
      // Repeat-one: just restart the same track.
      final player = _player;
      if (player == null) return;
      _playingId = id;
      _lastPersistedMs[id] = 0;
      try {
        final path = await localPath(id);
        final downloaded = await isDownloaded(id);
        await player.stop();
        if (downloaded) {
          await player.play(DeviceFileSource(path));
        } else {
          await player
              .play(UrlSource(AudioLibraryConfig.objectUrl(current.file)));
        }
        await player.setPlaybackRate(_speed);
      } catch (e) {
        AppLogger.warning('AudioLibraryPlayer', 'repeat-one failed: $e');
      }
      // The completed network/local source position resets by itself.
      _states[id] = (_states[id] ?? const AudioLibraryTrackState()).copyWith(
        playing: true,
        loading: false,
      );
      notifyListeners();
      return;
    }
    await _playTrack(next);
  }

  /// Stops the current remote stream and continues it from the local file at
  /// the same position. No-op when [track] is not the playing track.
  Future<bool> _switchToLocalIfPlaying(AudioTrack track) async {
    if (_playingId != track.id) return false;
    final player = _player;
    if (player == null) return false;
    final pos = _states[track.id]?.position ?? Duration.zero;
    try {
      await player.stop();
      await player.play(DeviceFileSource(await localPath(track.id)));
      await player.setPlaybackRate(_speed);
      if (pos > Duration.zero) {
        try {
          await player.seek(pos);
        } catch (_) {
          AppLogger.warning('audio_library_player', 'operation failed');
        }
      }
      return true;
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'switch to local failed: $e');
      return false;
    }
  }

  /// Seeks the currently-playing track to [position] (clamped to the reported
  /// duration when known). No-op when nothing is playing.
  @override
  Future<void> seek(Duration position) async {
    final player = _player;
    final id = _playingId;
    if (player == null || id == null) return;
    var target = position;
    final cur = _states[id] ?? const AudioLibraryTrackState();
    if (cur.hasDuration && target > cur.duration) target = cur.duration;
    if (target < Duration.zero) target = Duration.zero;
    try {
      await player.seek(target);
      _states[id] = cur.copyWith(position: target);
      _positionValue.value = target;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('AudioLibraryPlayer', 'seek failed: $e');
    }
  }

  /// Skips the playing track by [delta] (e.g. ±15s).
  Future<void> seekBy(Duration delta) async {
    final player = _player;
    final id = _playingId;
    if (player == null || id == null) return;
    final cur = _states[id] ?? const AudioLibraryTrackState();
    await seek(cur.position + delta);
  }

  /// Formats a duration as `m:ss` — or `h:mm:ss` for an hour or more.
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// Stops playback (queue end, sleep timer, or a manual stop). The current
  /// position is persisted first so the next play resumes where the listener
  /// stopped. Manual stops also disarm any running sleep timer.
  @override
  Future<void> stop() async {
    _sessionToken++;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    _sleepRemaining = null;
    final id = _playingId;
    if (id != null) {
      final s = _states[id];
      if (s != null && s.position > Duration.zero) {
        await _savePosition(id, s.position);
        _lastPersistedMs[id] = s.position.inMilliseconds;
      }
    }
    _playingId = null;
    _activeTrack = null;
    try {
      await _player?.stop();
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
    var changed = false;
    for (final entry in _states.entries.toList()) {
      final s = entry.value;
      if (s.playing || s.loading) {
        _states[entry.key] = s.copyWith(playing: false, loading: false);
        changed = true;
      }
    }
    try {
      await AppWakelock.release('audio_library');
    } catch (_) {
      AppLogger.warning('audio_library_player', 'wakelock disable failed');
    }
    if (changed) notifyListeners();
    // The card dies with the playback: nothing is loaded any more, and a
    // notification left behind would only be a control for silence.
    unawaited(AudioLibraryMediaSession.instance.stop());
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_interruptionSub?.cancel());
    _interruptionSub = null;
    _resumeAfterInterruption = false;
    _positionValue.dispose();
    _posSub = null;
    _durSub = null;
    _stateSub = null;
    _completeSub = null;
    try {
      _downloadClient?.close();
    } catch (_) {
      AppLogger.warning('audio_library_player', 'operation failed');
    }
    unawaited(() async {
      try {
        await _player?.stop();
      } catch (_) {
        AppLogger.warning('audio_library_player', 'operation failed');
      }
      try {
        await _player?.dispose();
      } catch (_) {
        AppLogger.warning('audio_library_player', 'operation failed');
      }
    }());
    _player = null;
    super.dispose();
  }
}
