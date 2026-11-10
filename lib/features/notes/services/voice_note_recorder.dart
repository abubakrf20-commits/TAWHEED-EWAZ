import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Voice-note recording + file store for the notes feature.
///
/// Recording uses the `record` plugin (AAC/m4a). Files are saved under
/// `<documents>/app_data/voice_notes/` so the portable backup can include
/// them. The plugin's permissions are requested on first record.
class VoiceNoteRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String _currentPath = '';
  DateTime? _startedAt;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Whether the microphone is currently granted (requests it if not).
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts recording into the voice-notes dir and returns the file path.
  /// Throws if the microphone permission is denied or recording already
  /// active.
  Future<String> start() async {
    if (_isRecording) return _currentPath;
    if (!await _recorder.hasPermission()) {
      throw StateError('microphone permission denied');
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'app_data', 'voice_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final path =
        p.join(dir.path, 'vn_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(
      const RecordConfig(),
      path: path,
    );
    _currentPath = path;
    _startedAt = DateTime.now();
    _isRecording = true;
    return path;
  }

  /// Stops recording. Returns the finished file path and its duration in ms.
  Future<(String?, int)> stop() async {
    if (!_isRecording) return (null, 0);
    _isRecording = false;
    final start = _startedAt ?? DateTime.now();
    _startedAt = null;
    final path = _currentPath;
    _currentPath = '';
    final durationMs =
        DateTime.now().difference(start).inMilliseconds.clamp(0, 1 << 30);
    try {
      final stopped = await _recorder.stop();
      // plugin resolves the path we passed in; trust our own for consistency
      return (stopped ?? path, durationMs);
    } catch (e) {
      // Stop can fail if the file was already closed; keep the path anyway.
      return (path, durationMs);
    }
  }

  /// Cancels the current recording and deletes its partial file.
  Future<void> cancel() async {
    if (!_isRecording) return;
    _isRecording = false;
    _startedAt = null;
    final path = _currentPath;
    _currentPath = '';
    try {
      await _recorder.cancel();
    } catch (e) {
      AppLogger.warning('voice_note_recorder', 'cancel failed: $e');
    }
    if (path.isNotEmpty) {
      final f = File(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (e) {
          AppLogger.warning('voice_note_recorder', 'partial file delete: $e');
        }
      }
    }
  }

  /// Deletes a stored voice-note file if it lives under our root dir.
  static Future<void> deleteStored(String path) async {
    if (path.isEmpty) return;
    final docs = await getApplicationDocumentsDirectory();
    final root = p.joinAll([docs.path, 'app_data', 'voice_notes']);
    if (!p.equals(
        p.normalize(path), p.normalize(p.join(root, p.basename(path))))) {
      return;
    }
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (e) {
        AppLogger.warning('voice_note_recorder', 'stored file delete: $e');
      }
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
