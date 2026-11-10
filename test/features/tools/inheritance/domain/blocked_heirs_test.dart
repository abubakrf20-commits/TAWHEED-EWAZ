import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/blocked_heirs.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';

void main() {
  group('analyzeBlockedHeirs', () {
    test('الأخ الشقيق محجوب بوجود الابن', () {
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        wife: 1,
        son: 1,
        fullBrother: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, contains(HeirType.fullBrother));
      expect(
          blocked.firstWhere((b) => b.type == HeirType.fullBrother).count, 1);
    });

    test('ابن الأخ محجوب بوجود الأخ', () {
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        fullBrother: 1,
        nephewFull: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, contains(HeirType.nephewFull));
    });

    test('الجدّ لا يُحجب بوجود الأخ', () {
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        grandfather: 1,
        fullBrother: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, isNot(contains(HeirType.grandfather)));
    });

    test('الأخت الشقيقة محجوبة بالجد في المذهب الحنفي', () {
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        madhab: Madhab.hanafi,
        estate: 1000,
        grandfather: 1,
        fullSister: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, contains(HeirType.fullSister));
    });

    test('أقرب ذي الرحم يرث الباقي عند فقد العصبة بعد الفروض', () {
      // دختر (1/2) بدون عاصب → عمه به عنوان نزدیک‌ترین خویشاوند دور
      // باقی‌مانده (1/2) را می‌برد و محجوب نیست.
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        paternalAunt: 1,
        daughter: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, isNot(contains(HeirType.paternalAunt)));
    });

    test('ذوو الأرحام محجوبون عند وجود العصبة', () {
      // پسر عاصب است → خویشاوندان دور محجوب‌اند.
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        paternalAunt: 1,
        son: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, contains(HeirType.paternalAunt));
    });

    test('ذوي الأرحام الأبعد محجوب بوجود الأقرب فقط', () {
      // ابن الأخت أقرب من العمّة → العمّة محجوبة، ابن الأخت وارث.
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        nieceSon: 1,
        paternalAunt: 1,
      ));
      final types = blocked.map((b) => b.type).toList();
      expect(types, contains(HeirType.paternalAunt));
      expect(types, isNot(contains(HeirType.nieceSon)));
    });

    test('الزوجة والابن لا يُحجبان أبدًا', () {
      final blocked = analyzeBlockedHeirs(const InheritanceInput(
        estate: 1000,
        wife: 1,
        son: 1,
      ));
      expect(blocked, isEmpty);
    });

    test('يأخذ النتيجة الجاهزة إذا أُعطيت', () {
      final result = getCalculator(Madhab.jumhur).calculate(
        const InheritanceInput(estate: 1000, son: 1),
      );
      final blocked = analyzeBlockedHeirs(
        const InheritanceInput(estate: 1000, son: 1),
        result: result,
      );
      expect(blocked, isEmpty);
    });
  });

  group('estateGoesToBaytAlMal', () {
    test('بلا أي وارث → تركة لبيت المال', () {
      expect(
        estateGoesToBaytAlMal(
          const InheritanceInput(estate: 5000),
        ),
        isTrue,
      );
    });

    test('مع وارث → لا تذهب لبيت المال', () {
      expect(
        estateGoesToBaytAlMal(const InheritanceInput(
          estate: 5000,
          son: 1,
        )),
        isFalse,
      );
    });
  });
}
