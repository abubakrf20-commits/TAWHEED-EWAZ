import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_rules.dart';

/// تست هم‌حوابی موتورهای مذاهب: هر مسأله در همهٔ مذاهب/قوانین اجرا و
/// واژه‌نامه‌های عمومی (بدون NaN، سهم غیرمنفی، روش معتبر، تخصیص کامل)
/// بررسی می‌شود؛ سپس پین‌های فقهی دقیق فقط در مواردی که رد/عول سهم را
/// تغییر نمی‌دهند (وجود عصبهٔ جذب‌کننده) اعمال می‌گردد.
void main() {
  const allMadhabs = Madhab.values;
  const fiqhMadhabs = [
    Madhab.jumhur,
    Madhab.hanafi,
    Madhab.maliki,
    Madhab.shafii,
    Madhab.hanbali,
  ];

  /// حالت‌های پایه: وراثت‌های پرتکرار که مرزهای الگوریتم را لمس می‌کنند.
  /// همه به‌جز مورد «دور» وارث غیرهمسر دارند، پس رد/عول باید کل ترکه را
  /// توزیع کند.
  const cases = <String, InheritanceInput>{
    'زوج + أب + أم + ابنتان (عول)': InheritanceInput(
      estate: 27000,
      husband: 1,
      father: 1,
      mother: 1,
      daughter: 2,
    ),
    'ابن + ابنت (عصبة ۲:۱)': InheritanceInput(
      estate: 3000,
      son: 1,
      daughter: 1,
    ),
    'زوج + ابنت + أم (رد)': InheritanceInput(
      estate: 48000,
      husband: 1,
      daughter: 1,
      mother: 1,
    ),
    'زوجتان + ابنتان': InheritanceInput(
      estate: 100000,
      wife: 1,
      daughter: 2,
    ),
    'أب + أم بدون فرع وارث': InheritanceInput(
      estate: 60000,
      father: 1,
      mother: 1,
    ),
    'أخت شقيقة واحدة': InheritanceInput(
      estate: 24000,
      fullSister: 1,
    ),
    'جد + أخوة أب': InheritanceInput(
      estate: 90000,
      grandfather: 1,
      paternalUncle: 2,
    ),
    'أب + ابن (عصبة)': InheritanceInput(
      estate: 50000,
      father: 1,
      son: 1,
    ),
    'وصیت ثلث + ورثه': InheritanceInput(
      estate: 90000,
      willAmount: 30000,
      wife: 1,
      son: 1,
    ),
    'دور (فقط همسر — باقی به بیت‌المال یا رد قانونی)': InheritanceInput(
      estate: 40000,
      husband: 1,
    ),
  };

  InheritanceShare? shareOf(InheritanceResult r, HeirType t) =>
      r.shares.where((s) => s.type == t).firstOrNull;

  group('هم‌حوابی همهٔ مذاهب/قوانین — واژه‌نامه‌های عمومی', () {
    for (final entry in cases.entries) {
      group(entry.key, () {
        for (final madhab in allMadhabs) {
          test('مذهب ${madhab.name}', () {
            final result = getCalculator(madhab).calculate(entry.value);

            // ۱) هیچ سهمی NaN یا منفی نیست.
            for (final s in result.shares) {
              expect(s.amount.isNaN, isFalse,
                  reason: 'سهم ${s.type.name} NaN شد');
              expect(s.amount, greaterThanOrEqualTo(0),
                  reason: 'سهم ${s.type.name} منفی شد');
            }

            // ۲) روش محاسبه از مقادیر معتبر است.
            expect(const ['normal', 'awl', 'radd', 'distantKindred', 'baytMal'],
                contains(result.method));

            // ۳) اصل مسأله صحیح مثبت است.
            expect(result.correctedAsl, greaterThan(0));

            // ۴) تخصیص هرگز از ترکهٔ قابل‌تقسیم بیشتر نمی‌شود.
            expect(result.totalAllocated,
                lessThanOrEqualTo(result.estateForMainHeirs + 0.01),
                reason: 'مجموع سهم‌ها از ترکه بیشتر شد');

            // ۵) اگر وارث غیرهمسر وجود دارد، رد/عصبه باید ترکه را کامل
            //    توزیع کند (مورد «دور» ممکن است به بیت‌المال برود).
            final hasNonSpouseHeir = entry.value.son > 0 ||
                entry.value.daughter > 0 ||
                entry.value.father > 0 ||
                entry.value.mother > 0 ||
                entry.value.grandfather > 0 ||
                entry.value.fullSister > 0 ||
                entry.value.paternalUncle > 0;
            if (hasNonSpouseHeir) {
              expect(result.totalAllocated,
                  closeTo(result.estateForMainHeirs, 0.01),
                  reason: 'مجموع سهم‌ها با ترکهٔ قابل‌تقسیم نمی‌خواند');
            } else {
              expect(result.totalAllocated, greaterThan(0));
            }
          });
        }
      });
    }
  });

  group('همسر تنها — «رد» فقط آن‌جا که بر همسر جاری می‌شود', () {
    // شوهر/همسر تنها بماند: باقی‌مانده جایی نمی‌رود مذهب‌هایی که همسر را از
    // رد مستثنی می‌کنند (اکثر) → باقی‌مانده به بیت‌المال، و فقط اردن و تونس
    // 1956 آن را بر همسر «رد» می‌کنند. نام‌گذاری روش باید همین را بگوید.
    const spouseOnly = [
      InheritanceInput(estate: 40000, husband: 1),
      InheritanceInput(estate: 40000, wife: 1),
    ];
    for (final input in spouseOnly) {
      for (final madhab in allMadhabs) {
        test('${madhab.name} — ${input.husband > 0 ? 'شوهر' : 'همسر'} تنها',
            () {
          final r =
              getCalculator(madhab).calculate(input.copyWith(madhab: madhab));
          final spouseType =
              input.husband > 0 ? HeirType.husband : HeirType.wife;
          final fardOnly = input.husband > 0 ? 0.5 : 0.25;
          if (MadhabRules.isSpouseRaddExempt(madhab)) {
            // سهم خودِ همسر دست‌نخورده می‌ماند و باقی‌مانده به بیت‌المال.
            expect(shareOf(r, spouseType)!.fraction.toDouble(),
                closeTo(fardOnly, 1e-9),
                reason: madhab.name);
            expect(r.method, 'baytMal', reason: madhab.name);
            expect(r.raddApplied, isFalse, reason: madhab.name);
            expect(r.totalAllocated, lessThan(input.estate));
          } else {
            // ردّ بر همسر جاری می‌شود: کل ترکه به او می‌رسد.
            expect(
                shareOf(r, spouseType)!.fraction.toDouble(), closeTo(1.0, 1e-9),
                reason: madhab.name);
            expect(r.method, 'radd', reason: madhab.name);
            expect(r.totalAllocated, closeTo(input.estate, 0.01));
          }
        });
      }
    }
  });

  group('پین‌های فقهی مشترک — با عصبهٔ جذب‌کننده (بدون اثر رد/عول)', () {
    test('زوج با فرع = یک‌هشتم در همهٔ مذاهب و قوانین', () {
      for (final madhab in allMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 80000,
          wife: 1,
          son: 1,
        ));
        final wife = shareOf(r, HeirType.wife)!;
        expect(wife.fraction.n, 1, reason: 'مذهب ${madhab.name}');
        expect(wife.fraction.d, 8, reason: 'مذهب ${madhab.name}');
        expect(wife.amount, closeTo(10000, 0.01),
            reason: 'مذهب ${madhab.name}');
      }
    });

    test('دو دختر کنار یک پسر: تقسیم باقی‌مانده ۲:۱ (پسر ½، دخترها جمعاً ½)',
        () {
      for (final madhab in allMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 60000,
          daughter: 2,
          son: 1,
        ));
        // دخترها در کنار پسر عصبة بالغیرند (۲:۱ برای هر فرد) —
        // پس با ۲ دختر و ۱ پسر: پسر ۲ حصه، هر دختر ۱ حصه → پسر ½ و
        // دخترها جمعاً ½ (هر دختر نصف پسر). مدل خروجی ممکن است جمعی
        // یا per-person باشد؛ جمع را می‌سنجیم.
        final daughtersTotal = r.shares
            .where((s) => s.type == HeirType.daughter)
            .fold(0.0, (m, s) => m + s.amount);
        final sonsTotal = r.shares
            .where((s) => s.type == HeirType.son)
            .fold(0.0, (m, s) => m + s.amount);
        expect(sonsTotal, closeTo(30000, 0.01), reason: 'مذهب ${madhab.name}');
        expect(daughtersTotal, closeTo(30000, 0.01),
            reason: 'مذهب ${madhab.name}');
      }
    });

    test('مادر با فرع = یک‌ششم در همهٔ مذاهب', () {
      for (final madhab in allMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 60000,
          mother: 1,
          son: 1,
        ));
        final mother = shareOf(r, HeirType.mother)!;
        expect(mother.fraction.n, 1, reason: 'مذهب ${madhab.name}');
        expect(mother.fraction.d, 6, reason: 'مذهب ${madhab.name}');
      }
    });

    test('مادر با پدر (بدون فرع) = یک‌سوم در همهٔ مذاهب (پدر عصبه)', () {
      for (final madhab in allMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 60000,
          mother: 1,
          father: 1,
        ));
        final mother = shareOf(r, HeirType.mother)!;
        expect(mother.fraction.n, 1, reason: 'مذهب ${madhab.name}');
        expect(mother.fraction.d, 3, reason: 'مذهب ${madhab.name}');
      }
    });

    test('ابنت منفرد در مذاهب فقهی: نصف فرض + رد → کل ترکه', () {
      // فرض نصف است؛ چون عصبه‌ای نیست، ردِ دختر باقی‌مانده را برمی‌گرداند.
      // (قوانین مدنی ممکن است رد همسر/تنظیم خاص داشته باشند — فقط ۵ مذهب.)
      for (final madhab in fiqhMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 50000,
          daughter: 1,
        ));
        expect(shareOf(r, HeirType.daughter)!.amount, closeTo(50000, 0.01),
            reason: 'مذهب ${madhab.name}');
        expect(r.totalAllocated, closeTo(50000, 0.01),
            reason: 'مذهب ${madhab.name}');
      }
    });
  });

  group('عول — تقلیل نسبتی مشترک', () {
    test('زوج + ۲ دختر + أب + أم: اصل ۱۲ → عول به ۱۵', () {
      // زوج ۳/۱۲ + مادر ۲/۱۲ + پدر ۲/۱۲ + دو دختر ۸/۱۲ = ۱۵/۱۲ → عول.
      for (final madhab in fiqhMadhabs) {
        final r = getCalculator(madhab).calculate(const InheritanceInput(
          estate: 30000,
          husband: 1,
          daughter: 2,
          mother: 1,
          father: 1,
        ));
        expect(r.method, 'awl', reason: 'مذهب ${madhab.name}');
        expect(r.baseAsl, 12, reason: 'مذهب ${madhab.name}');
        expect(r.correctedAsl, 15, reason: 'مذهب ${madhab.name}');
        // نسبت هر سهم از مسأله ثابت می‌ماند: زوج ۳/۱۵ از ۳۰۰۰۰ = ۶۰۰۰.
        expect(shareOf(r, HeirType.husband)!.amount, closeTo(6000, 0.01),
            reason: 'مذهب ${madhab.name}');
        // دو دختر جمعاً ۸/۱۵ از ۳۰۰۰۰ = ۱۶۰۰۰ (۸۰۰۰ برای هر یک).
        expect(shareOf(r, HeirType.daughter)!.amount, closeTo(16000, 0.01),
            reason: 'مذهب ${madhab.name}');
      }
    });
  });
}
