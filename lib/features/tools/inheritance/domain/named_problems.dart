import 'inheritance_calculator.dart';
import 'madhab_rules.dart';

/// مسائل مشهور علم الفرائض (الملقّبات).
///
/// كل مسألة لها صورة خاصة من الوَرَثة تُعرف بها عند أهل العلم، ولهذا
/// أُطلقت عليها ألقاب. الكتالوج التالي منقولٌ بضوابطه من برنامج
/// «الموسوعة الإسلامية» (Maknoon) ويطابق الضوابط المعروفة في كتب
/// الفرائض (روضة الطالبين، الفقه المنهجي، كشاف القناع).
class NamedProblem {
  /// مفتاح فريد للمسألة (للبرمجة والاختبارات).
  final String key;

  /// الاسم المعروف بالعربية (مثل «المسألة العمرية»).
  final String name;

  /// أسماء/ألقاب أخرى.
  final List<String> aliases;

  /// وصف مختصر بالعربية يشرح الصورة والحكم.
  final String description;

  const NamedProblem({
    required this.key,
    required this.name,
    this.aliases = const [],
    required this.description,
  });

  /// الاسم الكامل مع الألقاب، مثل «المسألة الأكدرية (الغراء)».
  String get fullName {
    if (aliases.isEmpty) return name;
    return '$name (${aliases.join('، ')})';
  }
}

/// همهٔ مسائل مشهور به همان ترتیب موسوعهٔ اسلامی؛ نام عربی کلاسیک در
/// نام‌های دیگر حفظ شده تا با کتاب‌های فرائض قابل تطبیق باشد.
const List<NamedProblem> allNamedProblems = [
  NamedProblem(
    key: 'omariya',
    name: 'مسأله عمری',
    aliases: ['الغراوان', 'العمریتان'],
    description:
        'همسر (زن یا شوهر) + مادر + پدر، بدون فرزند وارث و بدون برادر و خواهر. '
        'نام‌گذاری به «عمریه» از عمر بن خطاب است که نخستین‌بار در آن حکم کرد. '
        'در این مسأله مادر یک‌سومِ باقی‌مانده پس از همسر را می‌گیرد (قول عمر)؛ '
        'اما گرفتن یک‌سومِ اصل ترکه مذهب مالک و احمد است (و قوانین الجزایر و '
        'عربستان).',
  ),
  NamedProblem(
    key: 'mushtarakah',
    name: 'مسأله مشترکه',
    aliases: ['المنبرية', 'الحمارية', 'المشركة'],
    description:
        'شوهر + برادر و خواهر شقی (به شرط وجود برادر شقی) + دو برادر یا خواهر '
        'مادری یا بیشتر، بدون پدر و جد و فرزند وارث؛ سهم مادر یک‌ششم است. '
        'اشقاء با برادران و خواهران مادری در یک‌سومِ آنان شریک می‌شوند (قول '
        'عمر، ابن مسعود و زید)؛ مالکی، شافعی و جمهور همین را گرفته‌اند. حنفی '
        'و حنبلی (و قانون عربستان) اشقاء را شریک نمی‌کنند و برادران مادری '
        'به‌سبب عصبه بودن اشقاء ساقط می‌شوند.',
  ),
  NamedProblem(
    key: 'akdariya',
    name: 'مسأله اکدریه',
    aliases: ['الأكدرية', 'الغراء'],
    description:
        'شوهر + مادر + جد + یک خواهر شقی یا پدری، بدون پدر و فرزند وارث و '
        'برادر و خواهر دیگر. سهم خواهر نصف و جد یک‌ششم فرض شد، سپس دو سهم جمع '
        'و میان آنان به نسبت دو‌به‌یک تقسیم شد؛ مسأله از 27 تصحیح می‌شود. به '
        'زید بن ثابت نسبت داده شد زیرا با اصل او در دو موضع مخالفت داشت. '
        'حنفی‌ها خواهر را ساقط می‌کنند.',
  ),
  NamedProblem(
    key: 'dinariya_sughra',
    name: 'مسأله دیناری صغرا',
    aliases: ['أم الأرامل', 'أم الفروج', 'السبعة عشرية'],
    description:
        'سه همسر + دو مادربزرگ + چهار خواهر مادری + هشت خواهر شقی یا پدری، با '
        'ترکه‌ای هفده دینار؛ سهم هر وارث یک دینار است. اصل مسأله 12 بود و به '
        '17 عول شد. نام «دیناریه صغرا» از آن است که متوفی هفده دینار باقی '
        'گذاشت و به هر یک یک دینار رسید.',
  ),
  NamedProblem(
    key: 'dinariya_kubra',
    name: 'مسأله دیناری کبرا',
    aliases: ['الركابية', 'الشاكية'],
    description:
        'یک همسر + مادر + دو دختر + دوازده برادر شقی + یک خواهر شقی، با ترکه‌ای '
        'ششصد دینار که سهم خواهر از آن فقط یک دینار بود. نام‌گذاری برای تمایز '
        'از صغراست؛ «رکابیه» از آن رو که خواهر رکاب علی را گرفت و از شریح '
        'شکایت کرد که از ششصد فقط یک دینار به او داده بود.',
  ),
  NamedProblem(
    key: 'kharqaa',
    name: 'مسأله خرقاء',
    description:
        'مادر + جد + یک خواهر شقی یا پدری، بدون همسر و پدر و فرزند وارث. سهم '
        'مادر یک‌سوم است و باقی‌مانده میان جد و خواهر به نسبت دوبه‌یک تقسیم '
        'می‌شود؛ مسأله از 9 تصحیح می‌شود. «خرقاء» نامیده شد زیرا صحابه در آن '
        'آراء فراوانی دادند و در آن تخرّق کردند (هفت قول).',
  ),
  NamedProblem(
    key: 'minbariya',
    name: 'مسأله منبریه',
    aliases: ['البخيلة'],
    description:
        'همسر + مادر + پدر + دو دختر، بدون فرزند وارث دیگر و برادر و خواهر. '
        'اصل مسأله 24 است و به 27 عول می‌شود. «منبریه» نامیده شد زیرا از علی '
        'هنگام خطبه بر منبر پرسیدند و فرمود: «یک‌هشتم زن، یک‌نهم شد»؛ و '
        '«بخیله» (خسیس) به‌سبب کم بودن عول آن است.',
  ),
  NamedProblem(
    key: 'ashriya',
    name: 'مسأله عشریه',
    description:
        'جد + خواهر شقی + یک برادر پدری (بدون دیگران). جد با خواهر شقی تقسیم '
        'می‌کند و برادر پدری را در تقسیم باقی‌مانده داخل می‌کند؛ مسأله از 10 '
        'تصحیح می‌شود و از این رو «عشریه» نام گرفت. در مذهب حنفی ظاهر نمی‌شود '
        'زیرا جد برادران را محجوب می‌کند.',
  ),
  NamedProblem(
    key: 'ashriniya',
    name: 'مسأله عشرینیه',
    description:
        'جد + خواهر شقی + دو خواهر پدری (بدون دیگران). خواهر شقی نصف را '
        'می‌گیرد و جد و دو خواهر پدری در باقی‌مانده شرکت می‌کنند؛ مسأله از 20 '
        'تصحیح می‌شود. در مذهب حنفی ظاهر نمی‌شود زیرا جد برادران را محجوب '
        'می‌کند.',
  ),
  NamedProblem(
    key: 'mukhtasarat_zayd',
    name: 'مختصره‌های زید',
    description:
        'مادر + جد + خواهر شقی + برادر پدری + خواهر پدری (بدون دیگران). با '
        '«بسط» اصل مسأله به 108 می‌رسد و با «اختصار» از 54 تصحیح می‌شود؛ '
        '«مختصرهٔ زید» نامیده شد زیرا زید بن ثابت در آن کار را خلاصه کرد. در '
        'مذهب حنفی ظاهر نمی‌شود.',
  ),
  NamedProblem(
    key: 'taseeniyat_zayd',
    name: 'تسعینیهٔ زید',
    description:
        'مادر + جد + خواهر شقی + دو برادر پدری + یک خواهر پدری (بدون دیگران). '
        'سهم مادر 3، جد 5 و خواهر شقی 9 می‌شود و یک سهم بر 5 باقی می‌ماند؛ '
        'اصل مسأله 90 است و از همین تصحیح می‌شود. در مذهب حنفی ظاهر نمی‌شود.',
  ),
  NamedProblem(
    key: 'that_alfurukh',
    name: 'ذات‌الفروخ',
    aliases: ['أم الفروخ', 'الشريحية'],
    description:
        'شوهر + مادر + دو خواهر مادری + دو خواهر شقی (یا یک شقی و یک پدری)، '
        'بدون پدر و جد و فرزند وارث. اصل مسأله 6 است و به 10 عول می‌شود؛ '
        '«ام‌الفروخ» نامیده شد زیرا بیشترین عول را دارد و چهار افزایش آن به '
        'جوجه‌ها (فروخ) تشبیه شد؛ و «شریحیه» زیرا قاضی شریح نخستین‌کسی بود که '
        'در آن حکم کرد.',
  ),
  NamedProblem(
    key: 'mubahala',
    name: 'مسأله مباهله',
    description:
        'شوهر + مادر + یک خواهر شقی (یا پدری)، بدون جد و پدر و فرزند وارث و '
        'دیگران. اصل مسأله 6 است و به 8 عول می‌شود. ابن عباس گفت: «هر کس '
        'خواست مسأله‌ای عول نکند، با اهل بیتش مباهله کند»؛ «مباهله» نامیده شد '
        'زیرا عمر با صحابه نزاع کرد و عباس به عول اشاره نمود و همه موافق '
        'شدند.',
  ),
  NamedProblem(
    key: 'yatamatan',
    name: 'یتیمتان',
    aliases: ['النصفية'],
    description:
        'شوهر + یک خواهر شقی یا یک خواهر پدری (بدون دیگران). هر یک نصف '
        'می‌برد و سومی میان آنان نیست؛ و در علم فرائض مسأله‌ای جز این دو نیست '
        'که مال با دو فریضهٔ برابر تقسیم شود؛ از این رو «یتیمتان» نام '
        'گرفتند.',
  ),
  NamedProblem(
    key: 'umm_alaramil',
    name: 'ام‌الارامل',
    aliases: ['الدينارية الصغرى', 'أم الفروج'],
    description:
        'سه همسر + دو مادربزرگ + چهار خواهر مادری + هشت خواهر شقی یا پدری '
        '(بدون دیگران). اصل مسأله 12 است و به 17 عول می‌شود؛ «ام‌الارامل» '
        'نامیده شد زیرا همه ورثه در آن زن‌اند.',
  ),
  NamedProblem(
    key: 'malikiya',
    name: 'مسأله مالکیه',
    description:
        'شوهر + مادر + جد + برادر پدری + برادران و خواهران مادری (بدون برادر '
        'شقی). مالکیان در این مسأله با زید و شافعی مخالفت کردند و گفتند: جد '
        'پس از صاحبان سهم، تمام باقی‌مانده را تنها می‌گیرد و سهمی برای '
        'برادران و خواهران مادری نیست؛ زیرا جد نزد آنان برادران مادری را '
        'محجوب می‌کند و چون محجوب کند سزاوارترِ باقی‌مانده است.',
  ),
  NamedProblem(
    key: 'shibh_malikiya',
    name: 'شبه‌مالکیه',
    description:
        'شوهر + مادر + جد + برادر شقی + برادران و خواهران مادری (بدون برادر '
        'پدری). مذهب زید و شافعی: جد یک‌ششم می‌گیرد و باقی‌مانده از آنِ عصبه '
        'یعنی برادران شقی است؛ مالک مخالفت کرد و آن را استثنا کرد و گفت: جد '
        'پس از صاحبان سهم، تمام باقی‌مانده را بدون برادر می‌گیرد.',
  ),
];

/// الكتالوج مرتبًا حسب ظهوره في الموسوعة الإسلامية.
const List<NamedProblem> _orderedCatalog = allNamedProblems;

/// التحقق من عدم وجود أي وارث رئيسي أو عصبة (عدا ذوي الأرحام).
bool _hasNoPrimaryHeirs(InheritanceInput i) {
  final list = <bool>[
    i.husband > 0,
    i.wife > 0,
    i.mother > 0,
    i.father > 0,
    i.grandfather > 0,
    i.greatGrandfather > 0,
    i.daughter > 0,
    i.son > 0,
    i.granddaughter > 0,
    i.grandson > 0,
    i.greatGranddaughter > 0,
    i.greatGrandson > 0,
    i.fullSister > 0,
    i.fullBrother > 0,
    i.paternalSister > 0,
    i.paternalBrother > 0,
    i.maternalSister > 0,
    i.maternalBrother > 0,
    i.nephewPaternal > 0,
    i.nephewFull > 0,
    i.nephewSonPaternal > 0,
    i.nephewSonFull > 0,
    i.paternalUnclePaternal > 0,
    i.paternalUncle > 0,
    i.paternalUncleSonPaternal > 0,
    i.paternalUncleSon > 0,
    i.paternalUncleGrandsonPaternal > 0,
    i.paternalUncleGrandson > 0,
    i.fatherUnclePaternal > 0,
    i.fatherUncleFull > 0,
    i.fatherCousinPaternal > 0,
    i.fatherCousinFull > 0,
  ];
  return !list.any((b) => b);
}

/// فروع وارثة (أولاد وأولاد أبناء وإن نزلوا).
bool _hasFar3(InheritanceInput i) =>
    i.son > 0 ||
    i.daughter > 0 ||
    i.grandson > 0 ||
    i.granddaughter > 0 ||
    i.greatGrandson > 0 ||
    i.greatGranddaughter > 0;

/// مجموع الإخوة والأخوات (سواء).
int _allSiblings(InheritanceInput i) =>
    i.fullBrother +
    i.fullSister +
    i.paternalBrother +
    i.paternalSister +
    i.maternalBrother +
    i.maternalSister;

/// مجموع الجدّات الحاضرات (من الأنواع الخمسة).
int _grandmothers(InheritanceInput i) =>
    i.maternalGrandmother +
    i.paternalGrandmother +
    i.greatMaternalGrandmother +
    i.paternalGreatGrandmotherFather +
    i.paternalGreatGrandmotherMother;

/// هل المذهب الحنفي (أو قانونٌ قائم عليه)؟
bool _isHanafi(Madhab m) => MadhabRules.baseMadhab(m) == Madhab.hanafi;

/// هل المذهب المالكي (أو قانونٌ قائم عليه)؟
bool _isMaliki(Madhab m) => MadhabRules.baseMadhab(m) == Madhab.maliki;

/// تحديد المسائل المشهورة المنطبقة على مسألةٍ ما.
///
/// تُرجع كل المسائل المطابقة بالترتيب نفسه الذي تعرضه الموسوعة الإسلامية
/// (فقد تنطبق مسألتان على نفس الصورة، كالدينارية الصغرى وأم الأرامل).
List<NamedProblem> detectNamedProblems(InheritanceInput input) {
  final i = input;
  final m = input.madhab;
  final result = <NamedProblem>[];

  // 1. العمرية: زوج/زوجة + أب + أم، بلا فرع وارث وبلا جمع إخوة.
  if (i.mother > 0 &&
      (i.husband > 0 || i.wife > 0) &&
      i.father == 1 &&
      !_hasFar3(i) &&
      i.grandfather == 0 &&
      _allSiblings(i) < 2) {
    result.add(_byKey('omariya'));
  }

  // 2. المشتركة: زوج + إخوة لأم (اثنان فأكثر) + أخ شقيق.
  if (!_isHanafi(m) && MadhabRules.baseMadhab(m) != Madhab.hanbali) {
    if (i.husband == 1 &&
        i.maternalSister + i.maternalBrother >= 2 &&
        i.fullBrother + i.fullSister > 0 &&
        i.fullBrother > 0 &&
        i.father == 0 &&
        i.grandfather == 0 &&
        !_hasFar3(i)) {
      result.add(_byKey('mushtarakah'));
    }
  }

  // 3. الأكدرية: زوج + أم + جد + أخت شقيقة أو لأب واحدة فقط.
  if (!_isHanafi(m)) {
    if (i.husband == 1 &&
        i.mother == 1 &&
        i.grandfather == 1 &&
        i.father == 0 &&
        i.fullBrother == 0 &&
        i.paternalBrother == 0 &&
        i.maternalBrother == 0 &&
        i.maternalSister == 0 &&
        !_hasFar3(i) &&
        ((i.fullSister == 1 && i.paternalSister == 0) ||
            (i.paternalSister == 1 && i.fullSister == 0))) {
      result.add(_byKey('akdariya'));
    }
  }

  // 4. الدينارية الصغرى: ثلاث زوجات + جدتان + 4 أخوات لأم + 8 أخوات
  //    شقيقات (أو لأب)، والتركة سبعة عشر.
  if (i.husband == 0 &&
      i.wife == 3 &&
      i.mother == 0 &&
      i.maternalSister == 4 &&
      i.maternalBrother == 0 &&
      i.fullBrother == 0 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      i.maternalGrandmother == 1 &&
      i.paternalGrandmother == 1 &&
      i.fullSister == 0 &&
      i.paternalBrother == 0 &&
      i.paternalSister == 8 &&
      !_hasFar3(i) &&
      i.estate == 17) {
    result.add(_byKey('dinariya_sughra'));
  }

  // 5. الدينارية الكبرى: زوجة + أم + بنتان + 12 أخًا شقيقًا + أخت شقيقة،
  //    والتركة ستمائة.
  if (i.husband == 0 &&
      i.wife == 1 &&
      i.mother == 1 &&
      i.maternalSister == 0 &&
      i.maternalBrother == 0 &&
      i.fullBrother == 12 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      i.son == 0 &&
      i.daughter == 2 &&
      i.fullSister == 1 &&
      i.estate == 600) {
    result.add(_byKey('dinariya_kubra'));
  }

  // 6. الخرقاء: أم + جد + أخت شقيقة واحدة فقط.
  if (!_isHanafi(m)) {
    if (i.husband == 0 &&
        i.wife == 0 &&
        i.mother == 1 &&
        i.maternalSister == 0 &&
        i.maternalBrother == 0 &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        i.fullSister == 1 &&
        i.paternalBrother == 0 &&
        i.paternalSister == 0 &&
        !_hasFar3(i) &&
        _grandmothers(i) == 0) {
      result.add(_byKey('kharqaa'));
    }
  }

  // 7. المنبرية: زوجة + أم + أب + بنتان.
  if (i.husband == 0 &&
      i.wife == 1 &&
      i.mother == 1 &&
      i.father == 1 &&
      i.son == 0 &&
      i.daughter == 2 &&
      i.fullBrother == 0 &&
      i.fullSister == 0 &&
      i.paternalBrother == 0 &&
      i.paternalSister == 0 &&
      i.maternalBrother == 0 &&
      i.maternalSister == 0) {
    result.add(_byKey('minbariya'));
  }

  // 8. العشرية: جد + أخت شقيقة + أخ لأب.
  if (!_isHanafi(m)) {
    if (i.husband == 0 &&
        i.wife == 0 &&
        i.mother == 0 &&
        i.maternalSister == 0 &&
        i.maternalBrother == 0 &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        _grandmothers(i) == 0 &&
        i.fullSister == 1 &&
        i.paternalBrother == 1 &&
        i.paternalSister == 0 &&
        !_hasFar3(i)) {
      result.add(_byKey('ashriya'));
    }

    // 9. العشرينية: جد + أخت شقيقة + أختان لأب.
    if (i.husband == 0 &&
        i.wife == 0 &&
        i.mother == 0 &&
        i.maternalSister == 0 &&
        i.maternalBrother == 0 &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        _grandmothers(i) == 0 &&
        i.fullSister == 1 &&
        i.paternalBrother == 0 &&
        i.paternalSister == 2 &&
        !_hasFar3(i)) {
      result.add(_byKey('ashriniya'));
    }

    // 10. مختصرات زيد: أم + جد + أخت شقيقة + أخ لأب + أخت لأب.
    if (i.husband == 0 &&
        i.wife == 0 &&
        i.mother == 1 &&
        i.maternalSister == 0 &&
        i.maternalBrother == 0 &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        i.fullSister == 1 &&
        i.paternalBrother == 1 &&
        i.paternalSister == 1 &&
        !_hasFar3(i) &&
        _grandmothers(i) == 0) {
      result.add(_byKey('mukhtasarat_zayd'));
    }

    // 11. تسعينية زيد: أم + جد + أخت شقيقة + أخوان لأب + أخت لأب.
    if (i.husband == 0 &&
        i.wife == 0 &&
        i.mother == 1 &&
        i.maternalSister == 0 &&
        i.maternalBrother == 0 &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        i.fullSister == 1 &&
        i.paternalBrother == 2 &&
        i.paternalSister == 1 &&
        !_hasFar3(i) &&
        _grandmothers(i) == 0) {
      result.add(_byKey('taseeniyat_zayd'));
    }
  }

  // 12. ذات الفروخ: زوج + أم + أختان لأم + أختان شقيقتان (أو شقيقة ولأب).
  if (i.husband == 1 &&
      i.wife == 0 &&
      i.mother == 1 &&
      i.maternalSister + i.maternalBrother == 2 &&
      i.fullBrother == 0 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      !_hasFar3(i) &&
      ((i.fullSister == 1 && i.paternalSister == 1) ||
          (i.fullSister >= 2 && i.paternalSister == 0)) &&
      i.paternalBrother == 0) {
    result.add(_byKey('that_alfurukh'));
  }

  // 13. المباهلة: زوج + أم + أخت شقيقة واحدة.
  if (i.husband == 1 &&
      i.wife == 0 &&
      i.mother == 1 &&
      i.maternalSister == 0 &&
      i.maternalBrother == 0 &&
      i.fullBrother == 0 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      !_hasFar3(i) &&
      i.fullSister == 1 &&
      i.paternalBrother == 0 &&
      i.paternalSister == 0 &&
      _grandmothers(i) == 0) {
    result.add(_byKey('mubahala'));
  }

  // 14. اليتيمتان: زوج + أخت شقيقة أو أخت لأب واحدة.
  if (i.husband == 1 &&
      i.wife == 0 &&
      i.mother == 0 &&
      i.maternalSister == 0 &&
      i.maternalBrother == 0 &&
      i.fullBrother == 0 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      _grandmothers(i) == 0 &&
      !_hasFar3(i) &&
      ((i.fullSister == 1 &&
              (i.paternalSister == 0 || i.paternalBrother > 0)) ||
          (i.fullSister == 0 &&
              i.paternalSister == 1 &&
              i.paternalBrother == 0))) {
    result.add(_byKey('yatamatan'));
  }

  // 15. أم الأرامل: ثلاث زوجات + جدتان + 4 أخوات لأم + 8 أخوات
  //     شقيقات أو لأب.
  if (i.husband == 0 &&
      i.wife == 3 &&
      i.mother == 0 &&
      i.maternalSister == 4 &&
      i.maternalBrother == 0 &&
      i.fullBrother == 0 &&
      i.father == 0 &&
      i.grandfather == 0 &&
      ((i.maternalGrandmother == 1 &&
              i.paternalGrandmother == 1 &&
              i.greatMaternalGrandmother == 0 &&
              i.paternalGreatGrandmotherFather == 0) ||
          (i.maternalGrandmother == 0 &&
              i.paternalGrandmother == 0 &&
              i.greatMaternalGrandmother == 1 &&
              i.paternalGreatGrandmotherFather == 1)) &&
      i.paternalGreatGrandmotherMother == 0 &&
      i.fullBrother == 0 &&
      i.paternalBrother == 0 &&
      !_hasFar3(i) &&
      ((i.fullSister == 8 && i.paternalSister == 0) ||
          (i.fullSister == 0 && i.paternalSister == 8))) {
    result.add(_byKey('umm_alaramil'));
  }

  // 16. المالكية: زوج + أم + جد + أخ لأب + إخوة لأم.
  if (_isMaliki(m)) {
    if (i.husband == 1 &&
        i.wife == 0 &&
        i.mother == 1 &&
        (i.maternalSister > 0 || i.maternalBrother > 0) &&
        i.fullBrother == 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        !_hasFar3(i) &&
        i.fullSister == 0 &&
        i.paternalBrother > 0 &&
        i.paternalSister == 0) {
      result.add(_byKey('malikiya'));
    }
  }

  // 17. شبه المالكية: زوج + أم + جد + أخ شقيق + إخوة لأم.
  if (_isMaliki(m)) {
    if (i.husband == 1 &&
        i.wife == 0 &&
        i.mother == 1 &&
        (i.maternalSister > 0 || i.maternalBrother > 0) &&
        i.fullBrother > 0 &&
        i.father == 0 &&
        i.grandfather == 1 &&
        !_hasFar3(i) &&
        i.fullSister == 0 &&
        i.paternalBrother == 0 &&
        i.paternalSister == 0) {
      result.add(_byKey('shibh_malikiya'));
    }
  }

  // 18. لا يوجد ورثة: كل الورثة الأساسيون غائبون → المال لبيت المال.
  if (_hasNoPrimaryHeirs(i) &&
      i.mother == 0 &&
      i.grandfather == 0 &&
      i.greatGrandfather == 0 &&
      _grandmothers(i) == 0) {
    // لا نضيف هنا مسألة ملقّبة؛ يتم التعامل مع بيت المال في مكان آخر.
  }

  return result;
}

/// إرجاع مسألة من الكتالوج بمفتاحها.
NamedProblem _byKey(String key) {
  for (final p in _orderedCatalog) {
    if (p.key == key) return p;
  }
  throw StateError('مسأله مشهوری با کلید «$key» در کاتالوگ یافت نشد.');
}

/// أول مسألة مشهورة منطبقة (للاستخدام في الحل التفصيلي والواجهات).
///
/// تُرجع null إذا لم تنطبق أي مسألة مشهورة.
String? detectNamedProblem(InheritanceInput input) {
  final problems = detectNamedProblems(input);
  if (problems.isEmpty) return null;
  return problems.first.fullName;
}
