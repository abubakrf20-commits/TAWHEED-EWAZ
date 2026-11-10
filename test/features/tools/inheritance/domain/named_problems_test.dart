import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/named_problems.dart';

void main() {
  group('detectNamedProblems', () {
    test('العمرية: زوج + أم + أب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        estate: 1200,
        husband: 1,
        mother: 1,
        father: 1,
      )).map((p) => p.key);
      expect(keys, contains('omariya'));
    });

    test('العمرية لا تنطبق مع جمع الإخوة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        father: 1,
        fullBrother: 2,
      )).map((p) => p.key);
      expect(keys, isNot(contains('omariya')));
    });

    test('المشتركة: زوج + أم + أخوان لأم + أخ شقيق (عند الجمهور)', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        maternalBrother: 2,
        fullBrother: 1,
      )).map((p) => p.key);
      expect(keys, contains('mushtarakah'));
    });

    test('المشتركة لا تنطبق على مذهب الحنفية', () {
      final keys = detectNamedProblems(const InheritanceInput(
        madhab: Madhab.hanafi,
        husband: 1,
        mother: 1,
        maternalBrother: 2,
        fullBrother: 1,
      )).map((p) => p.key);
      expect(keys, isNot(contains('mushtarakah')));
    });

    test('الأكدرية: زوج + أم + جد + أخت شقيقة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('akdariya'));
    });

    test('الأكدرية لا تنطبق على الحنفية', () {
      final keys = detectNamedProblems(const InheritanceInput(
        madhab: Madhab.hanafi,
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, isNot(contains('akdariya')));
    });

    test('الدينارية الصغرى: 3 زوجات + جدتان + 4 أخوات لأم + 8 لأب، تركة 17',
        () {
      final keys = detectNamedProblems(const InheritanceInput(
        estate: 17,
        wife: 3,
        maternalSister: 4,
        maternalGrandmother: 1,
        paternalGrandmother: 1,
        paternalSister: 8,
      )).map((p) => p.key);
      expect(keys, contains('dinariya_sughra'));
      // تنطبق أيضًا أم الأرامل على نفس الصورة.
      expect(keys, contains('umm_alaramil'));
    });

    test('الدينارية الكبرى: زوجة + أم + بنتان + 12 أخًا شقيقًا + أخت، تركة 600',
        () {
      final keys = detectNamedProblems(const InheritanceInput(
        estate: 600,
        wife: 1,
        mother: 1,
        daughter: 2,
        fullBrother: 12,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('dinariya_kubra'));
    });

    test('الخرقاء: أم + جد + أخت شقيقة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('kharqaa'));
    });

    test('المنبرية: زوجة + أم + أب + بنتان', () {
      final keys = detectNamedProblems(const InheritanceInput(
        wife: 1,
        mother: 1,
        father: 1,
        daughter: 2,
      )).map((p) => p.key);
      expect(keys, contains('minbariya'));
    });

    test('العشرية: جد + أخت شقيقة + أخ لأب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        grandfather: 1,
        fullSister: 1,
        paternalBrother: 1,
      )).map((p) => p.key);
      expect(keys, contains('ashriya'));
    });

    test('العشرينية: جد + أخت شقيقة + أختان لأب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        grandfather: 1,
        fullSister: 1,
        paternalSister: 2,
      )).map((p) => p.key);
      expect(keys, contains('ashriniya'));
    });

    test('مختصرات زيد: أم + جد + أخت شقيقة + أخ لأب + أخت لأب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        mother: 1,
        grandfather: 1,
        fullSister: 1,
        paternalBrother: 1,
        paternalSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('mukhtasarat_zayd'));
    });

    test('تسعينية زيد: أم + جد + أخت شقيقة + أخوان لأب + أخت لأب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        mother: 1,
        grandfather: 1,
        fullSister: 1,
        paternalBrother: 2,
        paternalSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('taseeniyat_zayd'));
    });

    test('ذات الفروخ: زوج + أم + أختان لأم + أخت شقيقة وأخت لأب', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        maternalBrother: 1,
        maternalSister: 1,
        fullSister: 1,
        paternalSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('that_alfurukh'));
    });

    test('المباهلة: زوج + أم + أخت شقيقة واحدة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('mubahala'));
    });

    test('اليتيمتان: زوج + أخت شقيقة واحدة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        fullSister: 1,
      )).map((p) => p.key);
      expect(keys, contains('yatamatan'));
    });

    test('أم الأرامل: 3 زوجات + جدتان + 4 أخوات لأم + 8 شقيقات', () {
      final keys = detectNamedProblems(const InheritanceInput(
        wife: 3,
        maternalSister: 4,
        maternalGrandmother: 1,
        paternalGrandmother: 1,
        fullSister: 8,
      )).map((p) => p.key);
      expect(keys, contains('umm_alaramil'));
    });

    test('المالكية: زوج + أم + جد + أخ لأب + إخوة لأم (عند المالكية فقط)', () {
      final keys = detectNamedProblems(const InheritanceInput(
        madhab: Madhab.maliki,
        husband: 1,
        mother: 1,
        grandfather: 1,
        maternalBrother: 1,
        paternalBrother: 1,
      )).map((p) => p.key);
      expect(keys, contains('malikiya'));

      // لا تنطبق على الجمهور.
      final jumhurKeys = detectNamedProblems(const InheritanceInput(
        husband: 1,
        mother: 1,
        grandfather: 1,
        maternalBrother: 1,
        paternalBrother: 1,
      )).map((p) => p.key);
      expect(jumhurKeys, isNot(contains('malikiya')));
    });

    test('شبه المالكية: زوج + أم + جد + أخ شقيق + إخوة لأم (عند المالكية فقط)',
        () {
      final keys = detectNamedProblems(const InheritanceInput(
        madhab: Madhab.maliki,
        husband: 1,
        mother: 1,
        grandfather: 1,
        maternalBrother: 1,
        fullBrother: 1,
      )).map((p) => p.key);
      expect(keys, contains('shibh_malikiya'));
    });

    test('مسألة عادية بلا لقب → قائمة فارغة', () {
      final keys = detectNamedProblems(const InheritanceInput(
        estate: 100,
        wife: 1,
        son: 1,
        daughter: 1,
      )).map((p) => p.key);
      expect(keys, isEmpty);
    });
  });

  group('detectNamedProblem', () {
    test('يرجع الاسم الكامل لأول مسألة منطبقة', () {
      final name = detectNamedProblem(const InheritanceInput(
        estate: 1200,
        husband: 1,
        mother: 1,
        father: 1,
      ));
      expect(name, startsWith('مسأله عمری'));
    });

    test('يرجع null لمسألة عادية', () {
      expect(
        detectNamedProblem(const InheritanceInput(
          estate: 100,
          wife: 1,
          son: 1,
        )),
        isNull,
      );
    });
  });
}
