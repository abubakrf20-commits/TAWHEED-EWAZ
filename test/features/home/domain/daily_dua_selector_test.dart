import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/home/domain/daily_dua_selector.dart';

void main() {
  final items = [
    for (var i = 0; i < 75; i++)
      HesnItem(
        id: i + 1,
        chapterId: 1,
        seq: i + 1,
        arabic: 'دعا $i',
      ),
  ];

  test('selects only from the first 60 Dua-section items', () {
    final selected = DailyDuaSelector.select(items, DateTime(2026));
    expect(selected, isNotNull);
    expect(selected!.id, inInclusiveRange(1, 60));
  });

  test('repeats the first item after a 60-day cycle', () {
    final firstDate = DateTime(2026);
    expect(
      DailyDuaSelector.select(items, firstDate)!.id,
      DailyDuaSelector.select(items, firstDate.add(const Duration(days: 60)))!
          .id,
    );
  });

  test('different days rotate through the sequence', () {
    final first = DailyDuaSelector.select(items, DateTime(2026));
    final second = DailyDuaSelector.select(items, DateTime(2026, 1, 2));
    expect(first!.id, isNot(second!.id));
  });
}
