import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhhab_comparison.dart';

void main() {
  group('compareMadhhabs', () {
    test('يحسب المسألة في المذاهب الخمسة', () {
      final c = compareMadhhabs(const InheritanceInput(
        estate: 6000,
        husband: 1,
        mother: 1,
        father: 1,
        daughter: 2,
      ));
      expect(c.results.length, 5);
      for (final m in MadhhabComparison.fiqhMadhhabs) {
        expect(c.resultFor(m).madhab, m);
      }
    });

    test('يمكن تقييد المذاهب', () {
      final c = compareMadhhabs(
        const InheritanceInput(estate: 1000, son: 1),
        madhhabs: [Madhab.jumhur, Madhab.hanafi],
      );
      expect(c.results.length, 2);
    });
  });

  group('crossMadhabBlockingDiffs', () {
    test('الأخ الشقيق يُحجب بالجدّ في الحنفي فقط', () {
      final diffs = crossMadhabBlockingDiffs(const InheritanceInput(
        estate: 1000,
        grandfather: 1,
        fullBrother: 1,
      ));
      final fb = diffs.firstWhere((d) => d.type == HeirType.fullBrother);
      expect(fb.differs, isTrue);
      expect(fb.blocked, contains(Madhab.hanafi));
      expect(fb.inherits, contains(Madhab.jumhur));
    });

    test('بدون خلاف → لا فروق', () {
      final diffs = crossMadhabBlockingDiffs(const InheritanceInput(
        estate: 1000,
        wife: 1,
        son: 1,
        daughter: 1,
      ));
      expect(diffs.where((d) => d.type == HeirType.son), isEmpty);
    });
  });
}
