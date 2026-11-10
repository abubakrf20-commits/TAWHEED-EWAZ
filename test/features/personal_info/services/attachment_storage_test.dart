import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';

/// Documents-dir stand-in so [AttachmentStorage] exercises its real copy /
/// guard logic against a temp directory (no platform channels involved).
class _FakePathProvider extends PathProviderPlatform {
  final String documentsPath;
  _FakePathProvider(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory docsDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    docsDir = await Directory.systemTemp.createTemp('attachment_storage_test');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDownAll(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  group('storeFile', () {
    test('copies the source into the store and returns an internal path',
        () async {
      final src = File('${docsDir.path}/pick_cache/photo.jpg');
      await src.create(recursive: true);
      await src.writeAsBytes(List<int>.filled(1024, 9));

      final stored = await AttachmentStorage.storeFile(src.path, 'document');

      // The path points inside our attachments root (never at the picker
      // cache), and the copy holds the same bytes.
      expect(stored, isNotEmpty);
      expect(stored, contains('attachments'));
      expect(stored, contains('document'));
      expect(stored, isNot(equals(src.path)));
      expect(await File(stored).exists(), isTrue);
      expect(await File(stored).length(), 1024);
    });

    test('falls back to [fallbackExt] when the source has no extension',
        () async {
      final src = File('${docsDir.path}/pick_cache/scan');
      await src.create(recursive: true);
      await src.writeAsBytes(const [1, 2, 3]);

      final stored = await AttachmentStorage.storeFile(src.path, 'generic',
          fallbackExt: '.pdf');

      expect(stored, endsWith('.pdf'));
      expect(await File(stored).exists(), isTrue);
    });

    test('rejects a missing source with an empty path', () async {
      final stored = await AttachmentStorage.storeFile(
          '${docsDir.path}/nope.png', 'asset');
      expect(stored, isEmpty);
    });

    test('rejects an oversized file with an empty path (no cache path leak)',
        () async {
      final src = File('${docsDir.path}/pick_cache/big.png');
      await src.create(recursive: true);
      // One byte over the 10 MB cap.
      await src.writeAsBytes(
          List<int>.filled(AttachmentStorage.maxAttachmentBytes + 1, 0));

      final stored = await AttachmentStorage.storeFile(src.path, 'asset');

      expect(stored, isEmpty);
    });
  });

  group('deleteStoredFile', () {
    test(
        'deletes a file stored in a kind subfolder (regression: the old '
        'basename guard silently no-op-d those)', () async {
      final src = File('${docsDir.path}/pick_cache/doc.png');
      await src.create(recursive: true);
      await src.writeAsBytes(const [7]);
      final stored = await AttachmentStorage.storeFile(src.path, 'document');
      expect(await File(stored).exists(), isTrue);

      await AttachmentStorage.deleteStoredFile(stored);

      expect(await File(stored).exists(), isFalse);
    });

    test('never touches files outside the attachments root', () async {
      final outside = File('${docsDir.path}/user_photo.png');
      await outside.writeAsBytes(const [1]);

      await AttachmentStorage.deleteStoredFile(outside.path);

      expect(await outside.exists(), isTrue);
    });

    test('ignores an empty path', () async {
      // Must not throw.
      await AttachmentStorage.deleteStoredFile('');
    });
  });

  group('deleteStoredList', () {
    test('deletes every listed stored file and skips foreign paths', () async {
      final aSrc = File('${docsDir.path}/a.png')..writeAsBytesSync(const [1]);
      final bSrc = File('${docsDir.path}/b.png')..writeAsBytesSync(const [2]);
      final a = await AttachmentStorage.storeFile(aSrc.path, 'document');
      final b = await AttachmentStorage.storeFile(bSrc.path, 'document');
      final outside = File('${docsDir.path}/keep_me.png')
        ..writeAsBytesSync(const [3]);

      await AttachmentStorage.deleteStoredList([a, b, outside.path]);

      expect(await File(a).exists(), isFalse);
      expect(await File(b).exists(), isFalse);
      expect(await outside.exists(), isTrue);
    });
  });

  group('storedPathExists', () {
    test('is true for a live stored file, false for foreign or missing ones',
        () async {
      final src = File('${docsDir.path}/pick_cache/live.png');
      await src.create(recursive: true);
      await src.writeAsBytes(const [5]);
      final stored = await AttachmentStorage.storeFile(src.path, 'asset');

      expect(await AttachmentStorage.storedPathExists(stored), isTrue);
      // A picker cache path is not part of the store.
      expect(await AttachmentStorage.storedPathExists(src.path), isFalse);
      expect(await AttachmentStorage.storedPathExists(''), isFalse);

      await AttachmentStorage.deleteStoredFile(stored);
      expect(await AttachmentStorage.storedPathExists(stored), isFalse);
    });
  });
}
