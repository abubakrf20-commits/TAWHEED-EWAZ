import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';

void main() {
  const hadith = HadeethEncHadith(
    id: 300,
    titleAr: 'عن ابن عمر...',
    title: 'متن عربی',
    textAr: 'نص عربی',
    text: 'متن فارسی',
  );

  test('bare hadith extra decodes as hadith with no sequence', () {
    expect(hadithFromRouteExtra(hadith), hadith);
    expect(sequenceFromRouteExtra(hadith), isNull);
  });

  test('positional record (hadith, sequence) decodes correctly', () {
    const extra = (hadith, 300);
    expect(hadithFromRouteExtra(extra), hadith);
    expect(sequenceFromRouteExtra(extra), 300);
  });

  test('positional record with null sequence decodes correctly', () {
    const extra = (hadith, null);
    expect(hadithFromRouteExtra(extra), hadith);
    expect(sequenceFromRouteExtra(extra), isNull);
  });

  test('named-field record (the old broken form) is rejected', () {
    const extra = (hadith: hadith, sequence: 300);
    expect(hadithFromRouteExtra(extra), isNull);
  });

  test('null and unrelated extras are rejected', () {
    expect(hadithFromRouteExtra(null), isNull);
    expect(hadithFromRouteExtra('not a hadith'), isNull);
    expect(hadithFromRouteExtra(42), isNull);
  });
}
