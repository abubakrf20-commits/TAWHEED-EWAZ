import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/services/attachment_dead_refs_scanner.dart';
import 'package:tawheeed/features/settings/presentation/providers/attachment_diagnostics_providers.dart';
import 'package:tawheeed/features/settings/presentation/screens/attachment_diagnostics_screen.dart';

/// Minimal repository stand-in — only needed to build the scanner instance.
class _FakeRepo implements PersonalInfoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Returns canned reports so the widget test stays in the fake-async zone —
/// real `dart:io` futures never complete there. The disk-touching behaviour
/// of the scanner itself is covered by attachment_dead_refs_scanner_test.dart.
class _StubScanner extends AttachmentDeadRefsScanner {
  DeadAttachmentReport scanResult;
  DeadAttachmentSweepResult? sweepResult;
  int scanCalls = 0;
  int sweepCalls = 0;

  _StubScanner(this.scanResult, {this.sweepResult})
      : super(repository: _FakeRepo());

  @override
  Future<DeadAttachmentReport> scan() async {
    scanCalls++;
    return scanResult;
  }

  @override
  Future<DeadAttachmentSweepResult> sweep() async {
    sweepCalls++;
    return sweepResult!;
  }
}

const _orphan = '/docs/app_data/attachments/document/orphan.png';
const _missing = '/docs/app_data/attachments/document/gone.png';

DeadAttachmentReport _dirtyReport() => const DeadAttachmentReport(
      orphanFiles: [_orphan],
      danglingRefs: [
        DanglingAttachmentRef(
          ownerType: 'document',
          ownerId: 'd1',
          ownerTitle: 'کارت ملی',
          field: 'imagesJson',
          path: _missing,
        ),
      ],
      errors: [],
      liveRefCount: 0,
    );

const _cleanReport = DeadAttachmentReport(
  orphanFiles: [],
  danglingRefs: [],
  errors: [],
  liveRefCount: 3,
);

void main() {
  Future<void> pump(WidgetTester tester, _StubScanner scanner) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentDeadRefsScannerProvider.overrideWithValue(scanner),
        ],
        child: const MaterialApp(home: AttachmentDiagnosticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists orphan files and dangling refs with their counts',
      (tester) async {
    await pump(tester, _StubScanner(_dirtyReport()));

    expect(find.text('2 ارجاع مرده'), findsOneWidget);
    expect(find.text('فایل‌های بی‌صاحب'), findsOneWidget);
    expect(find.text('ارجاع‌های شکسته'), findsOneWidget);
    // Both sections carry one item; the count now lives in the header chip.
    expect(find.text('(1)'), findsNWidgets(2));
    expect(find.text('پاک‌سازی (2 مورد)'), findsOneWidget);
    // Each dangling row names its owner and the column it lives in.
    expect(find.text('مدرک — کارت ملی'), findsOneWidget);
    expect(find.text('عکس‌های مدرک'), findsOneWidget);
    expect(find.text('orphan.png'), findsOneWidget);
  });

  testWidgets('confirming the sweep shows the result banner and refreshes',
      (tester) async {
    final scanner = _StubScanner(
      _dirtyReport(),
      sweepResult: const DeadAttachmentSweepResult(
        removedFiles: 1,
        prunedRefs: 1,
        reportAfter: _cleanReport,
      ),
    );
    await pump(tester, scanner);

    await tester.tap(find.text('پاک‌سازی (2 مورد)'));
    await tester.pumpAndSettle();
    expect(find.text('پاک کن'), findsOneWidget);

    await tester.tap(find.text('پاک کن'));
    await tester.pumpAndSettle();

    expect(scanner.sweepCalls, 1);
    expect(find.textContaining('پاک‌سازی انجام شد'), findsOneWidget);
    expect(find.text('همه‌چیز مرتب است'), findsOneWidget);
    expect(find.textContaining('پاک‌سازی ('), findsNothing);
  });

  testWidgets('cancelling the confirm dialog changes nothing', (tester) async {
    final scanner = _StubScanner(_dirtyReport());
    await pump(tester, scanner);

    await tester.tap(find.text('پاک‌سازی (2 مورد)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();

    expect(scanner.sweepCalls, 0);
    expect(find.text('2 ارجاع مرده'), findsOneWidget);
  });

  testWidgets('a clean store hides the sweep button', (tester) async {
    await pump(tester, _StubScanner(_cleanReport));

    expect(find.text('همه‌چیز مرتب است'), findsOneWidget);
    expect(find.textContaining('پاک‌سازی ('), findsNothing);
    // The duplicate "nothing to clean" card is gone; the summary owns it.
    expect(find.text('چیزی برای پاک‌سازی نیست.'), findsNothing);
  });
}
