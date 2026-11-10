import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_result.dart';

void main() {
  group('ZakatResult', () {
    test('constructor sets all fields', () {
      const result = ZakatResult(
        totalAssets: 100000000,
        totalDebts: 20000000,
        netAssets: 80000000,
        goldValue: 30000000,
        goldPureGrams: 100,
        silverValue: 5000000,
        cashAndBank: 50000000,
        businessValue: 20000000,
        nisabThreshold: 15000000,
        nisabBasis: 'طلای 18 عیار',
        zakatAmount: 2000000,
        zakatRate: 0.025,
        meetsNisab: true,
        hawlComplete: true,
        explanation: 'زکات شما واجب است',
        breakdownLines: ['طلای 18 عیار: 30,000,000 تومان'],
      );
      expect(result.totalAssets, 100000000);
      expect(result.totalDebts, 20000000);
      expect(result.netAssets, 80000000);
      expect(result.goldValue, 30000000);
      expect(result.silverValue, 5000000);
      expect(result.zakatAmount, 2000000);
      expect(result.zakatRate, 0.025);
      expect(result.meetsNisab, true);
      expect(result.hawlComplete, true);
      expect(result.breakdownLines, ['طلای 18 عیار: 30,000,000 تومان']);
    });

    group('hasZakat / hasMonetaryZakat / hasLivestockZakat', () {
      test('returns true when zakatAmount > 0', () {
        const result = ZakatResult(
          totalAssets: 100,
          totalDebts: 0,
          netAssets: 100,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 100,
          businessValue: 0,
          nisabThreshold: 50,
          nisabBasis: 'gold',
          zakatAmount: 2.5,
          zakatRate: 0.025,
          meetsNisab: true,
          hawlComplete: true,
          explanation: '',
          breakdownLines: [],
        );
        expect(result.hasMonetaryZakat, true);
        expect(result.hasLivestockZakat, false);
        expect(result.hasZakat, true);
      });

      test('returns true when livestockDescription is not empty', () {
        const result = ZakatResult(
          totalAssets: 0,
          totalDebts: 0,
          netAssets: 0,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 0,
          businessValue: 0,
          nisabThreshold: 50,
          nisabBasis: 'gold',
          zakatAmount: 0,
          zakatRate: 0.025,
          meetsNisab: false,
          hawlComplete: false,
          livestockDescription: '1 رأس گوسفند',
          explanation: 'زکات دام واجب شده',
          breakdownLines: [],
        );
        expect(result.hasMonetaryZakat, false);
        expect(result.hasLivestockZakat, true);
        expect(result.hasZakat, true);
      });

      test('returns false when zakatAmount is 0 and no livestock', () {
        const result = ZakatResult(
          totalAssets: 0,
          totalDebts: 0,
          netAssets: 0,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 0,
          businessValue: 0,
          nisabThreshold: 50,
          nisabBasis: 'gold',
          zakatAmount: 0,
          zakatRate: 0.025,
          meetsNisab: false,
          hawlComplete: false,
          explanation: 'نصاب کامل نیست',
          breakdownLines: [],
        );
        expect(result.hasZakat, false);
        expect(result.hasMonetaryZakat, false);
        expect(result.hasLivestockZakat, false);
      });
    });

    group('toSummaryText', () {
      test('returns summary with zakat amount when hasMonetaryZakat', () {
        const result = ZakatResult(
          totalAssets: 20000000,
          totalDebts: 0,
          netAssets: 20000000,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 20000000,
          businessValue: 0,
          nisabThreshold: 5000000,
          nisabBasis: 'gold',
          zakatAmount: 500000,
          zakatRate: 0.025,
          meetsNisab: true,
          hawlComplete: true,
          explanation: '',
          breakdownLines: [],
        );
        final summary = result.toSummaryText();
        expect(summary, contains('محاسبه زکات'));
        expect(summary, contains('زکات نقدی'));
        expect(summary, contains('500,000'));
      });

      test('returns summary with livestock description', () {
        const result = ZakatResult(
          totalAssets: 0,
          totalDebts: 0,
          netAssets: 0,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 0,
          businessValue: 0,
          nisabThreshold: 50,
          nisabBasis: 'gold',
          zakatAmount: 0,
          zakatRate: 0.025,
          meetsNisab: false,
          hawlComplete: false,
          livestockDescription: '2 رأس گوسفند یا بز',
          explanation: 'زکات دام واجب شده',
          breakdownLines: [],
        );
        final summary = result.toSummaryText();
        expect(summary, contains('زکات دام'));
        expect(summary, contains('2 رأس'));
      });

      test('returns summary with explanation when no zakat', () {
        const result = ZakatResult(
          totalAssets: 10,
          totalDebts: 5,
          netAssets: 5,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 10,
          businessValue: 0,
          nisabThreshold: 50,
          nisabBasis: 'gold',
          zakatAmount: 0,
          zakatRate: 0.025,
          meetsNisab: false,
          hawlComplete: false,
          explanation: 'نصاب کامل نیست',
          breakdownLines: [],
        );
        final summary = result.toSummaryText();
        expect(summary, contains('نصاب کامل نیست'));
        expect(summary, contains('دارایی کل'));
      });

      test('وقتی قیمت وارد نشده، خلاصه صریحاً می‌گوید نصاب نامعلوم است', () {
        const result = ZakatResult(
          totalAssets: 20000000,
          totalDebts: 0,
          netAssets: 20000000,
          goldValue: 0,
          goldPureGrams: 0,
          silverValue: 0,
          cashAndBank: 20000000,
          businessValue: 0,
          nisabThreshold: 0,
          nisabBasis: 'نامعلوم',
          zakatAmount: 0,
          zakatRate: 0.025,
          meetsNisab: false,
          hawlComplete: true,
          explanation: '',
          breakdownLines: [],
          priceKnown: false,
        );
        final summary = result.toSummaryText();
        expect(summary, contains('قابل محاسبه نیست'));
        expect(summary, isNot(contains('قیمت پیش‌فرض')));
      });
    });
  });
}
