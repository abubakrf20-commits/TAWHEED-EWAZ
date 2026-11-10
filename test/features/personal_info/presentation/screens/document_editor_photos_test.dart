import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/document_editor_sheet.dart';
import 'package:tawheeed/features/personal_info/services/secure_cipher.dart';

/// Fake platform layer for FilePicker.pickFiles: returns the queued paths as
/// real files (and a null path as a stream-only provider file, which the
/// editor resolves to a temp copy). Constructed with the interface token so
/// FilePickerPlatform.instance accepts it.
class _FakePickerPlatform extends FilePickerPlatform {
  _FakePickerPlatform() : super();

  List<String?> queued = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return [
      for (final path in queued)
        path == null
            ? _StreamOnlyFile(name: 'stream-only.jpg')
            : _DirectFile(name: p.basename(path), path: path),
    ];
  }
}

/// Documents-dir stand-in: path_provider 2.x resolves the store root through
/// the platform interface (not the raw method channel), so the official
/// instance mock is what AttachmentStorage actually consults.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// PlatformFile with a real disk path (direct provider). `PlatformFile` is a
/// base class, so the fakes extend it; the untouched members are satisfied
/// through a noSuchMethod override that fails loudly.
base class _DirectFile extends PlatformFile {
  final String _name;
  final String _path;
  _DirectFile({required String name, required String path})
      : _name = name,
        _path = path;

  @override
  String get name => _name;
  @override
  String? get path => _path;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// PlatformFile without a path (content-stream provider): exactly the shape
/// the editor's stream-copy branch must survive.
base class _StreamOnlyFile extends PlatformFile {
  final String _name;
  _StreamOnlyFile({required String name}) : _name = name;

  @override
  String get name => _name;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The one method the editor needs; everything else fails loudly.
class _FakeRepo implements PersonalInfoRepository {
  IdentityDocumentTableCompanion? lastSaved;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<void> upsertDocument(IdentityDocumentTableCompanion entry) async {
    lastSaved = entry;
  }
}

IdentityDocumentTableData _doc({
  required String id,
  required List<String> images,
}) {
  final now = DateTime.now();
  return IdentityDocumentTableData(
    id: id,
    profileId: 'p1',
    docType: 'national_id',
    title: 'کارت ملی',
    documentNo: '',
    issuedPlace: '',
    issuedDate: '',
    expiryDate: '',
    notes: '',
    imagesJson: jsonEncode(images),
    createdAt: now,
    updatedAt: now,
  );
}

late Directory _docs;
late File _pickerSource;
late _FakeRepo _repo;
late _FakePickerPlatform _picker;

/// Real stored-attachment fixture: a file already in the store directory that
/// a persisted row references.
Future<String> _addStoredImage(String name) async {
  final dir =
      Directory(p.join(_docs.path, 'app_data', 'attachments', 'document'))
        ..createSync(recursive: true);
  final f = File(p.join(dir.path, name))..writeAsBytesSync([1, 2, 3]);
  return f.path;
}

Future<void> _pump(WidgetTester tester,
    {IdentityDocumentTableData? doc}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalInfoRepositoryProvider.overrideWithValue(_repo),
        secretVaultProvider.overrideWith(
            (ref) async => SecureCipher.fromBytes(List<int>.filled(32, 7))),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DocumentEditor(
            profileId: 'p1',
            doc: doc,
            accent: const Color(0xFF0E7A5A),
            onSaved: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Real-time window for dart:io work: widget tests run on a fake clock, so
/// each real file future (store copy, deferred delete) only completes inside
/// `runAsync`, and its fake-zone continuation only advances on a fake drain.
/// Alternate the two until [condition] holds (or ~1s of real time passes).
Future<void> _settleRealIo(
    WidgetTester tester, bool Function() condition) async {
  for (var round = 0; round < 40 && !condition(); round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pump();
  }
}

/// Lets pending real I/O finish so Windows file handles (e.g. the stalled
/// thumbnail read) are released before the store delete runs.
Future<void> _drainRealIo(WidgetTester tester) =>
    _settleRealIo(tester, () => false);

Finder get _titleField =>
    find.widgetWithText(TextField, 'عنوان مدرک (مثلاً کارت ملی جدید)');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _docs = await Directory.systemTemp.createTemp('tawheeed_doc_editor');
    _repo = _FakeRepo();
    _pickerSource = File(p.join(_docs.path, 'picker_src.jpg'))
      ..writeAsBytesSync([9, 9, 9]);
    _picker = _FakePickerPlatform();
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _picker;
    addTearDown(() => FilePickerPlatform.instance = original);

    final originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(_docs.path);
    addTearDown(() => PathProviderPlatform.instance = originalProvider);
  });

  tearDown(() async {
    // Windows can hold a just-touched file open for a while; never fail a
    // green test over cleanup.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (_docs.existsSync()) _docs.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  testWidgets('pick adds a stored copy and save persists it', (tester) async {
    await _pump(tester);
    _picker.queued = [_pickerSource.path];

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    // The pick→copy chain is real dart:io; give it real-time windows until
    // the editor actually adds the thumbnail (proof the whole chain ran).
    await _settleRealIo(
        tester, () => tester.widgetList(find.byType(Image)).isNotEmpty);
    await tester.pumpAndSettle();

    final stored =
        Directory(p.join(_docs.path, 'app_data', 'attachments', 'document'))
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path) != 'picker_src.jpg')
            .toList();
    expect(stored, hasLength(1),
        reason: 'the pick must be copied into the store');

    await tester.enterText(_titleField, 'مدرک من');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final saved = _repo.lastSaved;
    expect(saved, isNotNull);
    final images = (jsonDecode(saved!.imagesJson.value) as List).cast<String>();
    expect(images.single, stored.single.path);
    // The stored file must survive a save that keeps it.
    expect(File(images.single).existsSync(), isTrue);
  });

  testWidgets(
      'removing a persisted photo detaches only — the file is deleted after save',
      (tester) async {
    final existing = await _addStoredImage('existing.jpg');
    await _pump(tester, doc: _doc(id: 'd1', images: [existing]));
    await _drainRealIo(tester);

    // Remove the photo (detach), then save.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(File(existing).existsSync(), isTrue,
        reason: 'a detached photo must stay on disk until «ذخیره»');

    await tester.enterText(_titleField, 'کارت ملی');
    await tester.tap(find.text('ذخیره'));
    // The deferred delete is real dart:io; give it a real-time window.
    await _settleRealIo(tester, () => !File(existing).existsSync());
    await tester.pumpAndSettle();

    expect(_repo.lastSaved, isNotNull);
    expect(_repo.lastSaved!.imagesJson.value, '[]');
    expect(File(existing).existsSync(), isFalse,
        reason:
            'the deferred delete must remove the file after a successful save');
  });

  testWidgets('keeping a photo across an edit leaves the file alone',
      (tester) async {
    final existing = await _addStoredImage('keep.jpg');
    await _pump(tester, doc: _doc(id: 'd1', images: [existing]));

    await tester.enterText(_titleField, 'کارت ملی');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(_repo.lastSaved, isNotNull);
    final images =
        (jsonDecode(_repo.lastSaved!.imagesJson.value) as List).cast<String>();
    expect(images.single, existing);
    expect(File(existing).existsSync(), isTrue);
  });
}
