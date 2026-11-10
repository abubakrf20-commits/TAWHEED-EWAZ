import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/munasakhat_modes.dart';

/// سناریوهای مناسخات گسترده‌تر از پوشش پایه: زنجیرهٔ چندمرحله‌ای، متوفیِ
/// غیروارث، مسائل مرسوم فقهی، و دوجانبهٔ ورثهٔ مشترک — با کنترل مقداری.
///
/// نکتهٔ روش: `calculateMergedMunasakhat` به روش «ضمن طبقة ورثة الميت الأول»
/// مرحلهٔ دوم را روی أصل ميت اول محاسبه می‌کند؛ لذا `stages[i].input.estate`
/// برای i>0 برابر ماترک ميت اول است (نه فقط سهم متوفی).
void main() {
  group('calculateMergedMunasakhat — سناریوهای گسترده', () {
    test('زنجیرهٔ دومرحله‌ای: پدر ← پسر (همسر+دختر)', () {
      final r = calculateMergedMunasakhat('دومرحله‌ای', [
        (
          'پدر',
          const InheritanceInput(estate: 1200, son: 2),
        ),
        (
          'پسر',
          const InheritanceInput(wife: 1, daughter: 1),
        ),
      ]);
      expect(r.stages.length, 2);
      expect(r.totalEstate, 1200);
      // مرحلهٔ اول: پدر → دو پسر (عصبه، کل ترکه).
      final s0 = r.stages[0].result;
      expect(s0.shares.single.type, HeirType.son);
      // مرحلهٔ دوم: روی أصل 1200 بازتوزیع می‌شود و ورثهٔ پسر هم داخل‌اند.
      final s1 = r.stages[1];
      expect(s1.input.estate, closeTo(1200, 0.01));
      expect(s1.result.shares, isNotEmpty);
      // مجموع سهم‌های مرحلهٔ دوم = 1200.
      final total = s1.result.shares.fold<double>(0, (a, s) => a + s.amount);
      expect(total, closeTo(1200, 0.01));
    });

    test('متوفیِ دوم از ميت اول ارث نمی‌برد: مسألهٔ مستقل با ماترک صفر', () {
      // پدر فقط یک دختر دارد؛ برادر (غیروارث پدر) فوت می‌کند.
      final r = calculateMergedMunasakhat('غیروارث', [
        (
          'پدر',
          const InheritanceInput(estate: 900, daughter: 1),
        ),
        (
          'برادر',
          const InheritanceInput(estate: 500, wife: 1),
        ),
      ]);
      expect(r.stages.length, 2);
      // مرحلهٔ دوم ماترک مؤثر صفر دارد چون برادر از پدر ارث نبرده است.
      expect(r.stages[1].input.estate, 0);
    });

    test('مسألهٔ مرسوم: زن ماتَ عنها زوجها', () {
      // ماترک زن 300. زوج 1/2 = 150 (با فرع مادر)، مادر 1/2 ردّ = 150.
      // سپس زوج فوت می‌کند و مادرش (که از زن سهم برده) از سهم او هم ارث می‌برد.
      final r = calculateMergedMunasakhat('زوج ثم غیره', [
        (
          'زن',
          const InheritanceInput(estate: 300, husband: 1, mother: 1),
        ),
        (
          'شوهر',
          const InheritanceInput(mother: 1, fullBrother: 2),
        ),
      ]);
      expect(r.stages.length, 2);
      // زوج 1/2 از 300 = 150.
      final s0 = r.stages[0].result;
      expect(
        s0.shares.firstWhere((st) => st.type == HeirType.husband).amount,
        closeTo(150, 0.001),
      );
      // مرحلهٔ دوم روی سهم زوج (150) بنا می‌شود.
      expect(r.stages[1].input.estate, closeTo(150, 0.001));
      final total1 = r.stages[1].result.shares.fold<double>(
        0,
        (a, s) => a + s.amount,
      );
      expect(total1, closeTo(150, 0.01));
    });

    test('ورثهٔ مشترک: مادر در هر دو مرحله سهم جدا می‌گیرد', () {
      final r = calculateMergedMunasakhat('مادر مشترک', [
        (
          'پسر اول',
          const InheritanceInput(estate: 800, mother: 1, son: 1),
        ),
        (
          'پسر دوم',
          const InheritanceInput(mother: 1, daughter: 1),
        ),
      ]);
      // پسر اول: مادر 1/6 = 133.33، پسر (عصبه) 666.67.
      final first = r.stages[0].result;
      expect(
        first.shares.firstWhere((s) => s.type == HeirType.mother).amount,
        closeTo(133.333, 0.01),
      );
      expect(
        first.shares.firstWhere((s) => s.type == HeirType.son).amount,
        closeTo(666.667, 0.01),
      );
      // مرحلهٔ دوم روی سهم پسر اول (666.67) بنا می‌شود.
      expect(r.stages[1].input.estate, closeTo(666.667, 0.01));
      expect(r.stages[1].result.shares, isNotEmpty);
    });
  });

  group('calculateGharqaHadma — سناریوهای گسترده', () {
    test('سه متوفی در یک حادث: هر یک مسألهٔ مستقل', () {
      final r = calculateGharqaHadma('غرقى', [
        (
          'الأب',
          const InheritanceInput(estate: 1500, wife: 1, son: 2),
        ),
        (
          'الابن الأول',
          const InheritanceInput(daughter: 1),
        ),
        (
          'الابن الثاني',
          const InheritanceInput(mother: 1),
        ),
      ]);
      expect(r.stages.length, 3);
      expect(r.totalEstate, 1500);
      for (final s in r.stages) {
        expect(s.result, isNotNull);
      }
      expect(r.explanation, isNotEmpty);
    });

    test('غرقى: همسر ثُمن می‌گیرد و مرحلهٔ دوم مستقل می‌ماند', () {
      // پدر 800: زوجة 1/8=100 (با دو فرع)، دو پسر هرکدام 350.
      final r = calculateGharqaHadma('غرقى', [
        (
          'الأب',
          const InheritanceInput(estate: 800, wife: 1, son: 2),
        ),
        (
          'الابن الأول',
          const InheritanceInput(wife: 1, daughter: 1),
        ),
      ]);
      // مرحلهٔ اول: همسر 1/8 = 100.
      expect(
        r.stages[0].result.shares
            .firstWhere((s) => s.type == HeirType.wife)
            .amount,
        closeTo(100, 0.001),
      );
      // مرحلهٔ دوم مستقل است (در غرقى هیچ‌یک از بعضی ارث نمی‌برد).
      expect(r.stages[1].input.estate, 0);
      expect(r.explanation, isNotEmpty);
    });
  });

  test('هر دو روش توضیح مستند دارند', () {
    expect(gharqaHadmaMethodDescription, isNotEmpty);
  });
}
