import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/settings/presentation/screens/storage_screen.dart';
import 'package:tawheeed/features/settings/services/storage_insights_service.dart';

/// Canned reports so the widget test never touches the filesystem — real
/// `dart:io` futures do not resolve inside the widget-test fake-async zone.
/// The disk behaviour itself is covered by storage_insights_service_test.
class _FakeService extends StorageInsightsService {
  _FakeService(this.report);

  StorageReport report;
  final List<String> cleared = [];
  bool clearResult = true;
  bool throwOnMeasure = false;

  @override
  Future<StorageReport> measure() async {
    if (throwOnMeasure) throw StateError('measure failed');
    return report;
  }

  @override
  Future<bool> clear(String id) async {
    cleared.add(id);
    if (!clearResult) return false;
    report = StorageReport(
      groups: [
        for (final group in report.groups)
          StorageGroupUsage(
            title: group.title,
            items: [
              for (final item in group.items)
                if (item.id == id)
                  StorageItemUsage(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    bytes: 0,
                    clearable: item.clearable,
                  )
                else
                  item,
            ],
          ),
      ],
    );
    return true;
  }
}

StorageReport _report() => const StorageReport(
      groups: [
        StorageGroupUsage(
          title: 'قرآن و تلاوت',
          items: [
            StorageItemUsage(
              id: 'quran.recitation',
              title: 'تلاوت آفلاین',
              subtitle: 'آیه‌های دانلودشدهٔ قاریان.',
              bytes: 1048576,
              clearable: true,
            ),
            StorageItemUsage(
              id: 'quran.content',
              title: 'متن، ترجمه و تفسیر',
              subtitle: 'فایل‌های محتوای مصحف.',
              bytes: 2048,
              clearable: false,
            ),
          ],
        ),
        StorageGroupUsage(
          title: 'داده‌های شخصی',
          items: [
            StorageItemUsage(
              id: 'personal.attachments',
              title: 'پیوست‌های اطلاعات من',
              subtitle: 'عکس‌ها و مدرک‌ها.',
              bytes: 4096,
              clearable: false,
            ),
          ],
        ),
      ],
    );

void main() {
  Future<void> pump(WidgetTester tester, _FakeService service) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorageScreen(service: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every group with its measured size', (tester) async {
    await pump(tester, _FakeService(_report()));

    expect(find.text('مدیریت فضا'), findsOneWidget);
    expect(find.text('فضای مصرفی برنامه'), findsOneWidget);
    expect(find.text('قرآن و تلاوت'), findsOneWidget);
    expect(find.text('داده‌های شخصی'), findsOneWidget);
    expect(find.text('تلاوت آفلاین'), findsOneWidget);
    expect(find.text('پیوست‌های اطلاعات من'), findsOneWidget);
    // 1 MB + 2 KB + 4 KB = 1030 KB → "1.0MB" for the row and the group.
    expect(find.textContaining('1.0MB'), findsWidgets);
  });

  testWidgets('only clearable rows carry a delete affordance', (tester) async {
    await pump(tester, _FakeService(_report()));

    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await tester.tap(find.text('تلاوت آفلاین'));
    await tester.pumpAndSettle();
    expect(find.text('پاک کردن «تلاوت آفلاین»؟'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(find.text('پاک کردن «تلاوت آفلاین»؟'), findsNothing);

    // A non-clearable row opens nothing.
    await tester.tap(find.text('متن، ترجمه و تفسیر'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirming a clear calls the service and reloads the page',
      (tester) async {
    final service = _FakeService(_report());
    await pump(tester, service);

    await tester.tap(find.text('تلاوت آفلاین'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاک کن'));
    await tester.pumpAndSettle();

    expect(service.cleared, ['quran.recitation']);
    expect(find.text('«تلاوت آفلاین» پاک شد.'), findsOneWidget);
    expect(find.textContaining('1.0MB'), findsNothing);
    expect(find.textContaining('0KB'), findsWidgets);
  });

  testWidgets('a failed clear reports the failure and keeps the row',
      (tester) async {
    final service = _FakeService(_report())..clearResult = false;
    await pump(tester, service);

    await tester.tap(find.text('تلاوت آفلاین'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاک کن'));
    await tester.pumpAndSettle();

    expect(find.text('پاک کردن «تلاوت آفلاین» ناموفق بود.'), findsOneWidget);
    expect(find.textContaining('1.0MB'), findsWidgets);
  });

  testWidgets('a measurement failure offers a retry that recovers',
      (tester) async {
    final service = _FakeService(_report())..throwOnMeasure = true;
    await pump(tester, service);

    // Keyed, not matched by prose: the title is a sentence and may be edited.
    expect(find.byKey(const ValueKey('failure_storage_load')), findsOneWidget);
    expect(find.text('خواندن حجم داده‌ها ممکن نشد'), findsOneWidget);

    service.throwOnMeasure = false;
    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(find.text('فضای مصرفی برنامه'), findsOneWidget);
    expect(find.text('قرآن و تلاوت'), findsOneWidget);
  });

  testWidgets('a downloaded database row clears from this page too',
      (tester) async {
    final service = _FakeService(const StorageReport(
      groups: [
        StorageGroupUsage(
          title: 'کتاب‌ها و حدیث',
          items: [
            StorageItemUsage(
              id: 'hadith.riyad',
              title: 'ریاض الصالحین',
              subtitle: 'شرح و ترجمهٔ ریاض الصالحین.',
              bytes: 2726297,
              clearable: true,
            ),
          ],
        ),
      ],
    ));
    await pump(tester, service);

    await tester.tap(find.text('ریاض الصالحین'));
    await tester.pumpAndSettle();
    expect(find.text('پاک کردن «ریاض الصالحین»؟'), findsOneWidget);
    await tester.tap(find.text('پاک کن'));
    await tester.pumpAndSettle();

    expect(service.cleared, ['hadith.riyad']);
    expect(find.text('«ریاض الصالحین» پاک شد.'), findsOneWidget);
  });

  testWidgets('a row with nothing downloaded offers no delete',
      (tester) async {
    await pump(
      tester,
      _FakeService(const StorageReport(
        groups: [
          StorageGroupUsage(
            title: 'کتاب‌ها و حدیث',
            items: [
              StorageItemUsage(
                id: 'hadith.taraghib',
                title: 'صحیح الترغیب',
                subtitle: 'صحیح الترغیب و الترهیب.',
                bytes: 0,
                clearable: true,
              ),
            ],
          ),
        ],
      )),
    );

    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    await tester.tap(find.text('صحیح الترغیب'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
