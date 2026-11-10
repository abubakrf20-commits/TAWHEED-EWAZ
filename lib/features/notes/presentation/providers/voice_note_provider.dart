import 'package:flutter_riverpod/legacy.dart';

import 'package:tawheeed/features/notes/services/voice_note_player.dart';

/// Shared voice-note playback (one clip at a time across the notes list).
/// [ChangeNotifierProvider] already disposes the notifier when the provider is
/// disposed, so the player must not be disposed a second time here.
///
/// Recording is no longer offered: the editor is title + text + color + pin.
/// Clips recorded by earlier versions stay in the database (and in the backup)
/// and remain playable from here.
final voiceNotePlayerProvider =
    ChangeNotifierProvider<VoiceNotePlayer>((ref) => VoiceNotePlayer());
