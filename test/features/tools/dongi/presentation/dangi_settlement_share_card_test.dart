import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_settlement_share_card.dart';

final _members = [
  DangiMemberModel(id: 'a', groupId: 'g1', name: 'علی', createdAt: _t),
  DangiMemberModel(id: 'b', groupId: 'g1', name: 'رضا', createdAt: _t),
];

final _t = DateTime(2025);

void main() {
  Widget build(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('renders header, group name and transfer rows', (tester) async {
    await tester.pumpWidget(build(DangiSettlementShareCard(
      groupName: 'سفر مشهد',
      members: _members,
      transfers: const [
        SettlementTransfer(fromId: 'a', toId: 'b', amount: 150000),
      ],
      total: 450000,
    )));
    await tester.pumpAndSettle();

    expect(find.text('تسویهٔ هزینه‌ها'), findsOneWidget);
    expect(find.text('گروه: سفر مشهد'), findsOneWidget);
    // 150,000 → «150,000»; total 450,000.
    expect(find.text('150,000'), findsOneWidget);
    expect(find.text('450,000'), findsOneWidget);
    expect(find.textContaining('علی'), findsWidgets);
    expect(find.textContaining('رضا'), findsWidgets);
  });

  testWidgets('empty transfers show the all-settled message', (tester) async {
    await tester.pumpWidget(build(DangiSettlementShareCard(
      groupName: 'س',
      members: _members,
      transfers: const [],
      total: 0,
    )));
    await tester.pumpAndSettle();

    expect(find.text('همه چیز تسویه است — بدهی‌ای نیست!'), findsOneWidget);
    expect(find.text('ساخته شده با برنامهٔ توحید'), findsOneWidget);
  });
}
