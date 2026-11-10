import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_form_sheets.dart';

class _FakeDangiNotifier extends DangiNotifier {
  @override
  DangiState build() => const DangiState();
}

/// باز کردن مستقیم شیت ویرایش هزینه — مستقل از چیدمان صفحهٔ گروه.
class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.members, required this.expense});

  final List<DangiMemberModel> members;
  final DangiExpenseModel expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDangiExpenseSheet(
            context,
            ref,
            'g1',
            members,
            expense: expense,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  final t = DateTime(2025, 1, 10);
  final members = [
    for (var i = 1; i <= 8; i++)
      DangiMemberModel(id: 'm$i', groupId: 'g1', name: 'نفر $i', createdAt: t),
  ];
  final expense = DangiExpenseModel(
    id: 'e1',
    groupId: 'g1',
    payerId: 'm1',
    title: 'شام',
    category: 'food',
    amount: 300,
    date: DateTime(2025, 1, 5),
    createdAt: t,
  );

  Widget build() => ProviderScope(
        overrides: [dangiProvider.overrideWith(_FakeDangiNotifier.new)],
        child: MaterialApp(
          home: _SheetHost(members: members, expense: expense),
        ),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش هزینه'), findsOneWidget);
  }

  // فیلدهای سهم مصرف‌کننده با هینت «0» (استاندارد ارقام لاتین) از فیلد مبلغ
  // اصلی («مثلاً 250000») قابل تفکیک‌اند.
  final consumerField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0');

  testWidgets(
      'activating consumers reveals member fields right below the switch',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0; // 360x780 منطقی
    addTearDown(tester.view.reset);

    await openSheet(tester);

    // قبل از فعال‌سازی: هنوز فیلدی نیست.
    expect(consumerField, findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // هشت فیلد برای هشت عضو ساخته شده است.
    expect(consumerField, findsNWidgets(8));

    // فاصلهٔ سوییچ تا اولین فیلد کم است (دیگر متن راهنمای بلند وسط نیست).
    final switchRect = tester.getRect(find.byType(Switch));
    final firstField = tester.getRect(consumerField.first);
    expect(firstField.top - switchRect.bottom, lessThan(60));

    // آخرین فیلد بعد از فعال‌سازی بدون اسکرول دستی زیر خط دید است
    // (اسکرول خودکار ensureVisible انجام شده).
    final lastField = tester.getRect(consumerField.last);
    expect(lastField.bottom, lessThanOrEqualTo(780.5));

    // اسکرول خودکار نباید سوییچ را هم از بالای دید خارج کند.
    expect(switchRect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('equal-split button activates consumers and fills amounts',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openSheet(tester);

    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'مثلاً 250000'),
        '800');
    await tester.tap(find.text('تقسیم برابری'));
    await tester.pumpAndSettle();

    // دکمه خودش حالت مصرف‌کننده را فعال می‌کند و سهم‌ها را می‌نویسد.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(consumerField, findsNWidgets(8));
    // سهم هر نفر 100 (800 / 8).
    final first = tester.widget<TextField>(consumerField.first);
    expect(first.controller!.text, '100');
  });
}
