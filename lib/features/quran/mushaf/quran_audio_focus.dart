import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Shared platform audio-session wiring for Quran playback (talaawah and
/// translation controllers).
///
/// Configures the session for speech and pauses playback on headset-unplug
/// (`becomingNoisy`) and on phone-call / competing-audio interruptions, so a
/// call or another app never talks over the recitation.
///
/// Returns a detach callback that cancels the subscriptions (call it from
/// the controller's `dispose`). Never throws — playback must keep working
/// even when the session plugin is unavailable.
///
/// [attachVoiceNoteAudioFocus] — same interruption handling for short
/// voice notes, on a speech session so a note pauses for calls and
/// headset-unplug instead of playing into the void.
Future<void Function()> attachVoiceNoteAudioFocus({
  required Future<void> Function() onPause,
  required bool Function() isPlaying,
}) async {
  StreamSubscription? noisySub;
  StreamSubscription? interruptionSub;
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    noisySub = session.becomingNoisyEventStream.listen((_) async {
      if (isPlaying()) {
        try {
          await onPause();
        } catch (_) {
          AppLogger.warning('voice_note_audio_focus', 'operation failed');
        }
      }
    });
    interruptionSub = session.interruptionEventStream.listen((event) async {
      if (event.begin &&
          (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.duck)) {
        if (isPlaying()) {
          try {
            await onPause();
          } catch (_) {
            AppLogger.warning('voice_note_audio_focus', 'operation failed');
          }
        }
      }
    });
  } catch (_) {
    // Session unavailable — playback continues without focus handling.
  }
  return () {
    try {
      noisySub?.cancel();
    } catch (_) {
      AppLogger.warning('voice_note_audio_focus', 'operation failed');
    }
    try {
      interruptionSub?.cancel();
    } catch (_) {
      AppLogger.warning('voice_note_audio_focus', 'operation failed');
    }
  };
}

/// NOTE: this is interruption/focus handling only. True background playback
/// (lock-screen controls, surviving task killers) needs a media-session
/// stack (`just_audio + audio_service`) — tracked as a separate project.
Future<void Function()> attachQuranAudioFocus({
  required Future<void> Function() onPause,
  required bool Function() isPlaying,
}) async {
  StreamSubscription? noisySub;
  StreamSubscription? interruptionSub;
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    noisySub = session.becomingNoisyEventStream.listen((_) async {
      if (isPlaying()) {
        try {
          await onPause();
        } catch (_) {
          AppLogger.warning('quran_audio_focus', 'operation failed');
        }
      }
    });
    interruptionSub = session.interruptionEventStream.listen((event) async {
      if (event.begin &&
          (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.duck)) {
        if (isPlaying()) {
          try {
            await onPause();
          } catch (_) {
            AppLogger.warning('quran_audio_focus', 'operation failed');
          }
        }
      }
    });
  } catch (_) {
    // Session unavailable — playback continues without focus handling.
  }
  return () {
    try {
      noisySub?.cancel();
    } catch (_) {
      AppLogger.warning('quran_audio_focus', 'operation failed');
    }
    try {
      interruptionSub?.cancel();
    } catch (_) {
      AppLogger.warning('quran_audio_focus', 'operation failed');
    }
  };
}
