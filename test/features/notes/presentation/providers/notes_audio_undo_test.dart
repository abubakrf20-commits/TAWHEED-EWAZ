import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';

import '../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockNoteDao mockNoteDao;
  late Directory docs;
  late String clip;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('tawheeed_voice_undo');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
      return null;
    });
    final voiceDir = Directory(p.join(docs.path, 'app_data', 'voice_notes'));
    await voiceDir.create(recursive: true);
    clip = p.join(voiceDir.path, 'clip_test.m4a');
    await File(clip).writeAsBytes([1, 2, 3, 4]);

    mockNoteDao = MockNoteDao();
    container = ProviderContainer(overrides: [
      noteDaoProvider.overrideWithValue(mockNoteDao),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (docs.existsSync()) await docs.delete(recursive: true);
  });

  test('undo after delete keeps the clip on disk and restorable', () async {
    await container
        .read(notesProvider.notifier)
        .addNote('یادداشت', 'متن', [], audioPath: clip, audioDurationMs: 1200);
    final note = container.read(notesProvider).value!.first;
    expect(note.audioPath, clip);

    await container.read(notesProvider.notifier).deleteNote(note.id);
    expect(container.read(notesProvider).value, isEmpty);
    // Inside the undo window the file must survive: deleting it immediately
    // restored a note whose player pointed at a missing clip.
    expect(File(clip).existsSync(), isTrue);

    await container.read(notesProvider.notifier).undoLastDelete();

    final restored = container.read(notesProvider).value!;
    expect(restored, hasLength(1));
    expect(restored.first.audioPath, clip);
    expect(File(clip).existsSync(), isTrue);
  });

  test('the clip is removed once the undo window lapses', () async {
    await container
        .read(notesProvider.notifier)
        .addNote('یادداشت', 'متن', [], audioPath: clip, audioDurationMs: 1200);
    final note = container.read(notesProvider).value!.first;

    await container.read(notesProvider.notifier).deleteNote(note.id);

    // The provider waits out the 5s snackbar window plus a grace margin; allow
    // for a slow CI clock.
    for (var i = 0; i < 40 && File(clip).existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(File(clip).existsSync(), isFalse);
  });

  test('a new delete flushes the previous, un-undoable clip', () async {
    final other =
        p.join(docs.path, 'app_data', 'voice_notes', 'clip_other.m4a');
    await File(other).writeAsBytes([9, 9]);

    await container
        .read(notesProvider.notifier)
        .addNote('A', '', [], audioPath: clip);
    await container
        .read(notesProvider.notifier)
        .addNote('B', '', [], audioPath: other);
    final notes = container.read(notesProvider).value!;
    final a = notes.firstWhere((n) => n.title == 'A');
    final b = notes.firstWhere((n) => n.title == 'B');

    await container.read(notesProvider.notifier).deleteNote(a.id);
    await container.read(notesProvider.notifier).deleteNote(b.id);

    // Only one undo slot exists, so A can no longer come back.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(File(clip).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue);
  });
}
