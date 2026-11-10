import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SciencesContent.load();
  });

  test('sciences.json loads and usulFiqh has the complete new content', () {
    expect(SciencesContent.isLoaded, isTrue);
    expect(SciencesContent.all, isNotEmpty);

    final usul = SciencesContent.byId('usulFiqh');
    expect(usul, isNotNull);

    // Full replacement: مقدمه + 17 فصل + خاتمه
    expect(usul!.chapters.length, 19);
    expect(usul.chapters.first.title, 'مقدمه');
    expect(usul.chapters.last.title, 'خاتمه');

    // Chapter titles cover every requested chapter
    final titles = usul.chapters.map((c) => c.title).toSet();
    expect(titles,
        contains('فصل اول: تعریف علم اصول فقه، موضوع، ثمره و ارکان آن'));
    expect(titles, contains('فصل چهارم: الأمر (فرمان)'));
    expect(titles, contains('فصل هفدهم: احکام مجتهدان'));

    // Spot-check structure: مقدمه has six subsections; فصل چهارم covers
    // تعریف، صیغهها، دلالت بر وجوب، مقتضیات و مسائل مرتبط.
    expect(usul.chapters.first.subsections.length, 6);
    final amr = usul.chapters.firstWhere((c) => c.title.contains('فصل چهارم'));
    expect(amr.subsections.length, 5);
    expect(
      amr.subsections.map((s) => s.title),
      containsAll([
        '1. تعریف امر',
        '2. صیغه‌های امر',
        '3. دلالت امر بر وجوب',
        '4. مقتضیات امر (لوازم امر)',
        '5. مسائل مرتبط با امر',
      ]),
    );

    // Arabic verses were preserved (e.g. taklif verse in رکن چهارم)
    final hasTaklifVerse = usul.chapters.any(
      (c) => c.subsections.any(
        (s) => s.verses.any((v) => v.contains('لَا يُكَلِّفُ اللَّهُ نَفْسًا')),
      ),
    );
    expect(hasTaklifVerse, isTrue);
  });

  test('familySciences has the full child-upbringing content', () {
    final family = SciencesContent.byId('familySciences');
    expect(family, isNotNull);
    expect(family!.chapters.length, 19); // مقدمه + 17 فصل + خاتمه
    expect(family.chapters.first.title, 'مقدمه');
    expect(family.chapters.last.title, 'خاتمه: توصیه‌های عملی برای والدین');
    final titles = family.chapters.map((c) => c.title).toSet();
    expect(titles, contains('فصل دوم: مشروعیت و ادله وجوب تربیت فرزندان'));
    expect(titles, contains('فصل پنجم: مراحل تربیت فرزندان'));
    expect(
        titles,
        contains(
            'فصل شانزدهم: احکام فقهی مرتبط با تربیت (نفقه، حضانت، تعلیم واجب)'));
    // مقدمه has جایگاه و اهمیت + فصل پنجم covers the three 7-year stages
    final muqaddima = family.chapters.first;
    expect(muqaddima.subsections.length, 3);
    final stages =
        family.chapters.firstWhere((c) => c.title.contains('فصل پنجم'));
    expect(stages.subsections.length, 3);
  });

  test('nawazil has the full contemporary-fiqh content', () {
    final nawazil = SciencesContent.byId('nawazil');
    expect(nawazil, isNotNull);
    // مقدمه + 14 فصل + خاتمه
    expect(nawazil!.chapters.length, 16);
    expect(nawazil.chapters.first.title, 'مقدمه');
    expect(nawazil.chapters.last.title,
        'خاتمه: توصیه‌های عملی برای فقیهان و پژوهشگران');

    final titles = nawazil.chapters.map((c) => c.title).toSet();
    expect(titles, contains('فصل اول: مفهوم و ماهیت فقه النوازل'));
    expect(titles, contains('فصل ششم: قواعد فقهیه حاکم بر نوازل'));
    expect(titles, contains('فصل نهم: فقه النوازل در مسائل پزشکی و بهداشتی'));
    expect(titles,
        contains('فصل چهاردهم: فقه النوازل و اجتهاد جمعی (دور مجامع فقهی)'));

    // منهج استنباط covers the nine ضوابط; قواعد فقهیه has the seven rules.
    final manhaj =
        nawazil.chapters.firstWhere((c) => c.title.contains('فصل چهارم'));
    expect(manhaj.subsections.length, 9);
    expect(
      manhaj.subsections.map((s) => s.title),
      containsAll([
        'رجوع به قرآن و سنت به عنوان منابع اصلی',
        'اجتهاد جمعی (الاجتهاد الجماعي)'
      ]),
    );
    final qawaid =
        nawazil.chapters.firstWhere((c) => c.title.contains('فصل ششم'));
    expect(qawaid.subsections.length, 7);
    expect(
      qawaid.subsections.map((s) => s.title),
      contains('قاعدة «الْيَقِينُ لَا يَزُولُ بِالشَّكِّ»'),
    );
  });

  test('siyasaShar3iya has the full sharia-politics content', () {
    final siyasa = SciencesContent.byId('siyasaShar3iya');
    expect(siyasa, isNotNull);
    // مقدمه + 13 فصل + خاتمه
    expect(siyasa!.chapters.length, 15);
    expect(siyasa.chapters.first.title, 'مقدمه');
    expect(siyasa.chapters.last.title, 'خاتمه');

    final titles = siyasa.chapters.map((c) => c.title).toSet();
    expect(titles, contains('فصل اول: مفهوم و ماهیت سیاست شرعی'));
    expect(titles, contains('فصل ششم: مفهوم جهاد و مشروعیت آن'));
    expect(titles, contains('فصل نهم: آداب و قواعد جنگ در اسلام'));
    expect(titles, contains('فصل سیزدهم: سیاست شرعی در عصر معاصر'));

    // مقدمه covers سیاست in language/term + the جهاد intro; فصل نهم has the
    // seven rules of war (دعوت پیش از جنگ، پرهیز از کشتن غیرنظامیان و...).
    final muqaddima = siyasa.chapters.first;
    expect(muqaddima.subsections.length, 7);
    expect(
      muqaddima.subsections.map((s) => s.title),
      containsAll(
          ['سیاست در لغت', 'سیاست در اصطلاح شرع', 'جهاد در اصطلاح شرع']),
    );
    final war = siyasa.chapters.firstWhere((c) => c.title.contains('فصل نهم'));
    expect(war.subsections.length, 7);
    expect(
      war.subsections.map((s) => s.title),
      containsAll([
        'دعوت به اسلام پیش از جنگ',
        'پرهیز از کشتن غیرنظامیان',
        'وفای به عهد و پیمان'
      ]),
    );
  });

  test('familyMarriage has the full family-and-marriage content', () {
    final fam = SciencesContent.byId('familyMarriage');
    expect(fam, isNotNull);
    // مقدمه + 13 فصل + خاتمه
    expect(fam!.chapters.length, 15);
    expect(fam.chapters.first.title, 'مقدمه');
    expect(fam.chapters.last.title, 'خاتمه');

    final titles = fam.chapters.map((c) => c.title).toSet();
    expect(titles,
        contains('فصل دوم: نکاح (ازدواج) – تعریف، مشروعیت، ارکان و شرایط'));
    expect(titles, contains('فصل پنجم: مهریه (صداق) – تعریف، انواع، احکام'));
    expect(titles, contains('فصل هفتم: طلاق – تعریف، انواع، ارکان و شرایط'));
    expect(titles, contains('فصل دهم: حضانت و نگهداری فرزندان'));
    expect(titles, contains('فصل سیزدهم: حل اختلافات خانوادگی'));

    // ارکان نکاح covers the five pillars; موانع ازدواج has the four groups
    // (نسبی/سببی/رضاعی/سایر) and the khātima preserves the closing salawat.
    final rukn = fam.chapters.firstWhere((c) => c.title.contains('فصل دوم'));
    expect(rukn.subsections.length, 4);
    final mawani = fam.chapters.firstWhere((c) => c.title.contains('فصل سوم'));
    expect(mawani.subsections.length, 4);
    expect(
      mawani.subsections.map((s) => s.title),
      containsAll(['موانع نسبی (محارم نسبی)', 'موانع رضاعی (محارم رضاعی)']),
    );
    final khatima = fam.chapters.last.subsections.single.body!;
    expect(khatima, contains('وصلی اللهم على سیدنا محمد'));
    // قرآن آیات and the مهر/nikah evidences survive.
    final hasEvidence =
        fam.evidence.any((e) => e.contains('لَا نِكَاحَ إِلَّا بِوَلِيٍّ'));
    expect(hasEvidence, isTrue);
  });

  test('creationProphets has the full creation-and-prophets content', () {
    final creation = SciencesContent.byId('creationProphets');
    expect(creation, isNotNull);
    // مقدمه + 17 فصل + خاتمه
    expect(creation!.chapters.length, 19);
    expect(creation.chapters.first.title, 'مقدمه');
    expect(creation.chapters.last.title, 'خاتمه');

    final titles = creation.chapters.map((c) => c.title).toSet();
    expect(titles, contains('فصل اول: آفرینش جهان و هدف از آن'));
    expect(
        titles,
        contains(
            'فصل هفتم: حضرت ابراهیم علیه السلام؛ خلیل الله و پدر پیامبران'));
    expect(
        titles, contains('فصل هفدهم: حضرت عیسی علیه السلام؛ مسیح و روح الله'));

    // فصل دوم (آدم) has the six subsections of the creation story
    final adam =
        creation.chapters.firstWhere((c) => c.title.contains('فصل دوم'));
    expect(adam.subsections.length, 6);
    expect(
      adam.subsections.map((s) => s.title),
      containsAll([
        '1. خلقت آدم از خاک',
        '4. سجدهٔ فرشتگان و سرپیچی ابلیس',
        '6. وسوسهٔ ابلیس و هبوط به زمین'
      ]),
    );

    // It appears in the علوم تاریخی section listing
    expect(SciencesContent.byCategory(ScienceCategory.historical),
        contains(creation));
    // The closing salawat survives
    expect(creation.chapters.last.body, contains('وصلی اللهم على سیدنا محمد'));
  });

  test('muamalat and nawazil are in علوم استنباطی (deductive)', () {
    final muamalat = SciencesContent.byId('muamalat');
    final nawazil = SciencesContent.byId('nawazil');
    expect(muamalat, isNotNull);
    expect(nawazil, isNotNull);
    expect(muamalat!.category, ScienceCategory.deductive);
    expect(nawazil!.category, ScienceCategory.deductive);
    // Both appear in the علوم استنباطی section listing
    expect(SciencesContent.byCategory(ScienceCategory.deductive),
        containsAll([muamalat, nawazil]));
  });

  test(
      'familySciences renamed to تربیت فرزندان and both family sciences are in علوم تربیتی',
      () {
    final family = SciencesContent.byId('familySciences');
    final marriage = SciencesContent.byId('familyMarriage');
    expect(family, isNotNull);
    expect(marriage, isNotNull);
    // Renamed and re-categorized into علوم تربیتی
    expect(family!.title, 'تربیت فرزندان');
    expect(family.category, ScienceCategory.educational);
    expect(marriage!.category, ScienceCategory.educational);
    // Both appear in the علوم تربیتی section listing
    expect(SciencesContent.byCategory(ScienceCategory.educational),
        containsAll([family, marriage]));
  });

  test(
      'hadithSciences (علوم حدیث) is restored while the حدیث science stays removed',
      () {
    final hadithSciences = SciencesContent.byId('hadithSciences');
    expect(hadithSciences, isNotNull,
        reason:
            'علوم حدیث was accidentally deleted with حدیث — it must be restored');
    expect(hadithSciences!.title, 'علوم حدیث');
    expect(hadithSciences.category, ScienceCategory.textual);
    // Full 22-chapter treatise survived the restore
    expect(hadithSciences.chapters.length, greaterThanOrEqualTo(22));
    expect(hadithSciences.chapters.first.title, 'مقدمه عمومی');
    expect(
      hadithSciences.chapters.map((c) => c.title),
      contains('فصل دوم: تعریف علوم حدیث (مصطلح‌الحدیث)'),
    );
    // The user asked to remove 'hadith' (حدیث), not 'hadithSciences' —
    // the حدیث science must remain gone.
    expect(SciencesContent.byId('hadith'), isNull);
    // و در فهرست علوم متنی دیده می‌شود
    expect(SciencesContent.byCategory(ScienceCategory.textual),
        contains(hadithSciences));
  });

  test('seerah / islamicHistory / akhlaq keep their expanded chapters', () {
    // These three sciences were accidentally reduced to skeletons in a stale
    // branch merge; the full detail must survive (guard against regression).
    for (final id in ['seerah', 'islamicHistory', 'akhlaq']) {
      final science = SciencesContent.byId(id);
      expect(science, isNotNull, reason: '$id missing from JSON');
      expect(
        science!.chapters.length,
        greaterThanOrEqualTo(8),
        reason: '$id lost its expanded chapters',
      );
    }
  });

  test('educational sciences are ordered by importance and logical flow', () {
    // فرد (اخلاق، تزکیه) ← خانواده (ازدواج، تربیت فرزندان) ← جامعه (دعوت):
    // ethics is the foundation, then self-purification, then forming the
    // family (marriage → raising children), then da'wah to society.
    final order = SciencesContent.byCategory(ScienceCategory.educational)
        .map((s) => s.id)
        .toList();
    expect(order, [
      'akhlaq',
      'tazkiyah',
      'familyMarriage',
      'familySciences',
      'dawaa',
    ]);
  });

  test('shafiiMadhhab remains the only «به‌زودی» placeholder', () {
    // مذهب شافعی is still a placeholder: visible so the user knows it is
    // coming, but flagged `complete: false` with no chapters so the UI shows
    // the «به‌زودی» badge.
    final shafii = SciencesContent.byId('shafiiMadhhab');
    expect(shafii, isNotNull,
        reason: 'مذهب شافعی should be listed as an incomplete placeholder');
    expect(shafii!.complete, isFalse);
    expect(shafii.chapters, isEmpty);
    expect(shafii.isComplete, isFalse);
    expect(shafii.category, ScienceCategory.deductive);

    // Every other science is complete (has chapters and the flag is true).
    for (final science in SciencesContent.all) {
      if (science.id == 'shafiiMadhhab') continue;
      expect(science.isComplete, isTrue,
          reason: '${science.id} unexpectedly flagged incomplete');
    }

    // Every relatedSciences reference must point to an existing science.
    final ids = SciencesContent.all.map((s) => s.id).toSet();
    for (final science in SciencesContent.all) {
      for (final ref in science.relatedSciences) {
        expect(ids.contains(ref), isTrue,
            reason: '${science.id} references missing science: $ref');
      }
    }
  });

  test('tawheed has the full monotheism (توحید) content', () {
    // Full replacement: مقدمه + ۶ فصل + خاتمه و توصیه‌های نهایی.
    final tawheed = SciencesContent.byId('tawheed');
    expect(tawheed, isNotNull);
    expect(tawheed!.complete, isTrue);
    expect(tawheed.isComplete, isTrue);
    expect(tawheed.category, ScienceCategory.foundational);
    expect(tawheed.chapters.length, 8);
    expect(tawheed.chapters.first.title, 'مقدمه');
    expect(tawheed.chapters.last.title, 'خاتمه و توصیه‌های نهایی');

    final titles = tawheed.chapters.map((c) => c.title).toSet();
    expect(titles, contains('فصل اول: مفهوم و اهمیت توحید'));
    expect(titles, contains('فصل دوم: ادله توحید'));
    expect(titles, contains('فصل سوم: اقسام توحید'));
    expect(titles, contains('فصل چهارم: لا إله إلا الله (کلمهٔ توحید)'));
    expect(titles, contains('فصل پنجم: آثار توحید در زندگی'));
    expect(titles, contains('فصل ششم: موانع توحید'));

    // فصل اول covers لغت/اصطلاح + اهمیت; فصل سوم has the three divisions.
    final concept =
        tawheed.chapters.firstWhere((c) => c.title.contains('فصل اول'));
    expect(concept.subsections.length, 2);
    expect(
      concept.subsections.map((s) => s.title),
      containsAll(['1. توحید در لغت و اصطلاح', '2. اهمیت توحید']),
    );
    final types =
        tawheed.chapters.firstWhere((c) => c.title.contains('فصل سوم'));
    expect(types.subsections.length, 3);
    expect(
      types.subsections.map((s) => s.title),
      containsAll([
        '1. توحید ربوبیت',
        '2. توحید الوهیت (عبودیت)',
        '3. توحید اسماء و صفات'
      ]),
    );

    // The seven conditions of لا إله إلا الله and the six نواقض survive.
    final kalima =
        tawheed.chapters.firstWhere((c) => c.title.contains('فصل چهارم'));
    expect(kalima.subsections.length, 3);
    expect(kalima.subsections[1].items.length, 7);
    expect(kalima.subsections[2].items.length, 6);

    // Arabic verses were preserved (e.g. the فاتحه verse in توحید الوهیت).
    final hasVerse = tawheed.chapters.any(
      (c) => c.subsections.any(
        (s) => s.verses
            .any((v) => v.contains('إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ')),
      ),
    );
    expect(hasVerse, isTrue);

    // The closing salawat survives.
    final hasSalawat = tawheed.chapters.any(
      (c) =>
          (c.body?.contains('وصلی اللهم على سیدنا محمد') ?? false) ||
          c.subsections.any(
            (s) => s.body?.contains('وصلی اللهم على سیدنا محمد') ?? false,
          ),
    );
    expect(hasSalawat, isTrue);

    // It appears in the علوم بنیادین section listing.
    expect(SciencesContent.byCategory(ScienceCategory.foundational),
        contains(tawheed));
  });
}
