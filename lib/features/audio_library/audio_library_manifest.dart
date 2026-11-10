import 'package:flutter/material.dart';

/// A single playable track listed in the audio-library manifest.
class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.file,
    required this.sizeBytes,
  });

  /// Stable ASCII id (e.g. `yaqeen-01`) — also used as the local file name.
  final String id;

  /// Display title (Persian).
  final String title;

  /// Object key relative to the storage bucket root
  /// (e.g. `yaqeen/01-marefat-shenasi.opus`).
  final String file;

  final int sizeBytes;

  /// Approximate size in MB, shown on the card before download/stream.
  double get approxSizeMb => sizeBytes / (1024 * 1024);

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      file: json['file'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'file': file,
        'sizeBytes': sizeBytes,
      };
}

/// A speaker group inside a category: every lecture in it shares one speaker.
/// The category keeps a flattened copy of all tracks alongside, so older app
/// versions (which only read `tracks`) still work unchanged.
class AudioSpeaker {
  const AudioSpeaker({
    required this.id,
    required this.title,
    required this.tracks,
  });

  /// Stable ASCII speaker id (e.g. `ziaei`) — never shown to the user.
  final String id;

  /// Persian display title (e.g. «شیخ ضیایی»).
  final String title;

  /// Tracks of this speaker, in display order.
  final List<AudioTrack> tracks;

  /// Total size of all tracks of this speaker.
  int get totalSizeBytes => tracks.fold(0, (sum, t) => sum + t.sizeBytes);

  factory AudioSpeaker.fromJson(Map<String, dynamic> json) {
    final tracks = <AudioTrack>[];
    final raw = json['tracks'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          tracks.add(AudioTrack.fromJson(item));
        }
      }
    }
    return AudioSpeaker(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tracks: tracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tracks': [for (final t in tracks) t.toJson()],
      };
}

/// An audio category (playlist). Future categories — «اناشید اسلامی»,
/// «سخنرانی» — arrive as additional entries in the manifest.
class AudioCategory {
  const AudioCategory({
    required this.id,
    required this.tracks,
    this.speakers = const [],
  });

  /// ASCII category id (e.g. `yaqeen`).
  final String id;

  /// Flat list of every track in the category (speakers flattened when the
  /// category is speaker-grouped) — used for playback ordering and by older
  /// clients.
  final List<AudioTrack> tracks;

  /// Optional speaker groups. When non-empty the tracks above are the
  /// concatenation of the speakers' lists, in order.
  final List<AudioSpeaker> speakers;

  bool get hasSpeakers => speakers.isNotEmpty;

  /// Total size of all tracks in this category (used for the subtitle).
  int get totalSizeBytes => tracks.fold(0, (sum, t) => sum + t.sizeBytes);

  AudioSpeaker? speakerOf(AudioTrack track) {
    for (final s in speakers) {
      if (s.tracks.any((t) => t.id == track.id)) return s;
    }
    return null;
  }

  /// Persian display title, resolved on the app side — the manifest and the
  /// upload pipeline stay ASCII (see `tool/audio_library/*.ps1`).
  String get displayTitle {
    switch (id) {
      case 'yaqeen':
        return 'رد شبهات';
      case 'anasheed':
        return 'اناشید اسلامی';
      case 'lectures':
        return 'سخنرانی';
      case 'misc':
        return 'متفرقه';
      default:
        return id;
    }
  }

  IconData get icon {
    switch (id) {
      case 'yaqeen':
        return Icons.verified_user_outlined;
      case 'anasheed':
        return Icons.music_note_outlined;
      case 'lectures':
        return Icons.graphic_eq;
      default:
        return Icons.headphones_outlined;
    }
  }

  /// Teacher/lecturer appended to every track title of this category: yaqeen
  /// lectures are all by Ustadh Murad Yusufi, the lectures category is by
  /// Sheikh Ziaei. Null when the category has no common teacher.
  static String? bylineForCategory(String? id) {
    switch (id) {
      case 'yaqeen':
        return 'استاد مراد یوسفی';
      case 'lectures':
        return 'شیخ ضیایی';
      default:
        return null;
    }
  }

  /// `«عنوان درس (نام استاد)»` — used on cards so the teacher is visible next
  /// to every file without inflating the stored manifest data. The byline is
  /// the owning speaker's title when the category is speaker-grouped,
  /// otherwise the category-wide teacher name. Language-grouped categories
  /// without a teacher (e.g. anasheed عربی/فارسی) keep the plain title.
  String trackDisplayTitle(AudioTrack track) {
    if (hasSpeakers) {
      if (bylineForCategory(id) == null) {
        return track.title;
      }
      final group = speakerOf(track);
      return group == null || group.title.isEmpty
          ? track.title
          : '${track.title} (${group.title})';
    }
    final byline = bylineForCategory(id);
    return byline == null ? track.title : '${track.title} ($byline)';
  }

  factory AudioCategory.fromJson(Map<String, dynamic> json) {
    final speakers = <AudioSpeaker>[];
    final rawSpeakers = json['speakers'];
    if (rawSpeakers is List) {
      for (final item in rawSpeakers) {
        if (item is Map<String, dynamic>) {
          speakers.add(AudioSpeaker.fromJson(item));
        }
      }
    }
    final tracks = <AudioTrack>[];
    if (speakers.isNotEmpty) {
      for (final s in speakers) {
        tracks.addAll(s.tracks);
      }
    } else {
      final raw = json['tracks'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            tracks.add(AudioTrack.fromJson(item));
          }
        }
      }
    }
    return AudioCategory(
      id: json['id'] as String? ?? '',
      tracks: tracks,
      speakers: speakers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tracks': [for (final t in tracks) t.toJson()],
        if (hasSpeakers) 'speakers': [for (final s in speakers) s.toJson()],
      };
}

/// The audio-library manifest: version + ordered categories of tracks.
class AudioLibraryManifest {
  const AudioLibraryManifest({
    required this.version,
    required this.categories,
  });

  final int version;
  final List<AudioCategory> categories;

  /// Flat list of every track across categories.
  List<AudioTrack> get allTracks => [for (final c in categories) ...c.tracks];

  factory AudioLibraryManifest.fromJson(Map<String, dynamic> json) {
    final categories = <AudioCategory>[];
    final raw = json['categories'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          categories.add(AudioCategory.fromJson(item));
        }
      }
    }
    return AudioLibraryManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      categories: categories,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'categories': [for (final c in categories) c.toJson()],
      };
}
