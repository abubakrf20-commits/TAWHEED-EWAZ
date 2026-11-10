import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

/// Builds a plain-text settlement summary ready to paste into a chat,
/// e.g. WhatsApp/Telegram group of the trip members.
///
/// Pure and testable: no Flutter, no platform channels.
String buildSettlementShareText({
  required String groupName,
  required List<DangiMemberModel> members,
  required List<SettlementTransfer> transfers,
  required double total,
}) {
  String name(String id) =>
      members.where((m) => m.id == id).firstOrNull?.name ?? id;

  final lines = <String>[
    'تسویهٔ هزینه‌های گروه «$groupName»',
    'مجموع هزینه‌ها: ${faMoney(total)}',
    '',
  ];

  if (transfers.isEmpty) {
    lines.add('همه چیز تسویه است — بدهی‌ای نیست! ✅');
  } else {
    lines.add('پرداخت‌ها:');
    for (final t in transfers) {
      lines.add('• ${name(t.fromId)} باید به ${name(t.toId)} بپردازد: '
          '${faMoney(t.amount)}');
    }
  }

  lines
    ..add('')
    ..add('— ساخته شده با برنامهٔ توحید');
  return lines.join('\n');
}
