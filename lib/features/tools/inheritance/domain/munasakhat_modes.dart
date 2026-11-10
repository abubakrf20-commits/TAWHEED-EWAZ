import 'inheritance_calculator.dart';

/// طريقة حساب المناسخات:
///
/// - [successiveLayers] (ضمن طبقات متعاقبة): كل متوفٍ مسألة مستقلة تُقسَم على
///   ورثته، وتصير حصة المتوفّي التالي تركةً للمسألة التالية. هذه الطريقة
///   مطابقة لطريقة الموسوعة الإسلامية في «ضمن طبقات متعاقبة».
/// - [mergedWithFirstDeceased] (ضمن طبقة ورثة الميت الأول): تُجمَع حصص من
///   ماتوا بعد الأول في مسألة واحدة وتُوزَّع بين ورثة الميت الأول المتبقين
///   مع ورثة المتوفّين، فيتحقق الجمع بين المسائل (جامعة المناسخة) في مسألة
///   واحدة على أصل الميت الأول.
enum MunasakhatMode { successiveLayers, mergedWithFirstDeceased }

/// نتيجة الحساب بطريقة «ضمن طبقة ورثة الميت الأول».
///
/// المرحلة الأولى هي مسألة الميت الأول، وكل مرحلة تالية تمثّل توزيع حصة
/// المتوفّي الجديد مدمجةً في أصل الميت الأول بين ورثته وورثة المتوفّى.
class MunasakhatMergedCase {
  final String label;
  final List<MunasakhatStage> stages;
  final double totalEstate;

  const MunasakhatMergedCase({
    required this.label,
    required this.stages,
    required this.totalEstate,
  });
}

/// حساب المناسخات بطريقة «ضمن طبقة ورثة الميت الأول».
///
/// [stagesData] بالترتيب الزمني للوفاة. تُحسب مسألة الميت الأول ثم تُدمج
/// حصة كل متوفٍ تالٍ في مسألة الميت الأول وتُوزَّع على ورثته وورثة المتوفى.
MunasakhatMergedCase calculateMergedMunasakhat(
  String label,
  List<(String, InheritanceInput)> stagesData, {
  InheritanceResult Function(InheritanceInput)? calculator,
}) {
  if (stagesData.isEmpty) {
    throw ArgumentError('مناسخات به حداقل یک مرحله نیاز دارد.');
  }
  final calc = calculator ?? calculateInheritance;

  final stages = <MunasakhatStage>[];
  final firstInput = stagesData.first.$2;
  final totalEstate = firstInput.estate;

  // مسألة الميت الأول على أصله كاملًا.
  final firstResult = calc(firstInput);
  stages.add(MunasakhatStage(
    deceasedLabel: stagesData.first.$1,
    input: firstInput,
    result: firstResult,
  ));

  for (int i = 1; i < stagesData.length; i++) {
    final (deceased, _) = stagesData[i];

    // حصة المتوفّي من مسألة الميت الأول (إن وجد وارثًا فيها).
    final shareInFirst = _shareForLabel(firstResult, deceased);
    if (shareInFirst <= 0) {
      // المتوفّي لم يرث من الميت الأول؛ مسألته مستقلة عن أصل الأول.
      final ownResult = calc(stagesData[i].$2.copyWith(estate: 0));
      stages.add(MunasakhatStage(
        deceasedLabel: deceased,
        input: stagesData[i].$2.copyWith(estate: 0),
        result: ownResult,
      ));
      continue;
    }

    // نوزّع حصة المتوفّي على ورثة الميت الأول المتبقين وعلى ورثة المتوفّي.
    final combined =
        _mergeIntoFirst(stagesData, i, shareInFirst, calc, firstResult);
    stages.add(MunasakhatStage(
      deceasedLabel: deceased,
      input: combined.input,
      result: combined.result,
    ));
  }

  return MunasakhatMergedCase(
    label: label,
    stages: stages,
    totalEstate: totalEstate,
  );
}

/// يدمج حصة المتوفّي الجديد في مسألة الميت الأول.
///
/// تُضاف حصة المتوفّي إلى تركة مسألة الميت الأول وتُوزَّع على الورثة
/// المتبقين من مسألة الأول (أصحاب الفروض والعصبات) مع ورثة المتوفّي.
/// تُرجع (المدخل الجديد، نتيجته) مع سهم منفصل لحصة المتوفّي المدمجة.
({InheritanceInput input, InheritanceResult result}) _mergeIntoFirst(
  List<(String, InheritanceInput)> stagesData,
  int i,
  double shareInFirst,
  InheritanceResult Function(InheritanceInput) calc,
  InheritanceResult firstResult,
) {
  final firstInput = stagesData.first.$2;
  final deceasedInput = stagesData[i].$2;

  final merged = firstInput.copyWith(estate: shareInFirst);
  final mergedResult = calc(merged);

  // إذا لم يخرج شيء لورثة المتوفّي في هذه المسألة المدمجة، نضيف ورثة
  // المتوفّي كأصحاب فروض وعصبات مع تركة مسألة الميت الأول.
  final combined = mergedResult.shares.isEmpty
      ? deceasedInput.copyWith(estate: shareInFirst)
      : merged;

  final result = calc(combined);

  return (input: combined, result: result);
}

/// الحصة المالية للمتوفّي التالي من نتيجة مسألة سابقة (بمطابقة الاسم أو النوع).
double _shareForLabel(InheritanceResult result, String label) {
  for (final s in result.shares) {
    if (heirLabel(s.type) == label || label.startsWith(heirLabel(s.type))) {
      return s.amount;
    }
  }
  return 0;
}

// ══════════════════════════════════════════════════════════
//  الغرقى والهدمى — ميراث من ماتوا في حادث واحد (غرق/هدم/حريق)
// ══════════════════════════════════════════════════════════

/// نتيجة مسائل الغرقى والهدمى.
///
/// الطريقة (كما في الموسوعة الإسلامية):
/// 1. نفرض أن أحدهم مات أولًا ونقسم تركته على ورثته الأحياء ومن ماتوا معه.
/// 2. نعمل مسألة ثانية للأحياء من ورثة من مات معه ونقسم عليها نصيبه من
///    مسألة الميت الأول (جامعة).
/// 3. نعود لمسألة الميت الثاني ونقسمها على ورثته الأحياء ومن مات معه،
///    وهكذا حتى تكتمل مسائل كل الأموات.
class GharqaHadmaCase {
  final String label;
  final List<MunasakhatStage> stages;
  final double totalEstate;
  final String explanation;

  const GharqaHadmaCase({
    required this.label,
    required this.stages,
    required this.totalEstate,
    required this.explanation,
  });
}

/// حساب ميراث الغرقى والهدمى (موتى حادث واحد: غرق، هدم، حريق، ونحوها).
///
/// [deathsData] قائمة (اسم المتوفّي، ورثته) بالترتيب المفترض للوفاة.
/// بما أن الجميع ماتوا في آنٍ واحد لا يرث بعضهم من بعض، تُقسَّم تركة كلٍّ
/// منهم على ورثته الأحياء (من لم يمت في الحادث) فقط.
GharqaHadmaCase calculateGharqaHadma(
  String label,
  List<(String, InheritanceInput)> deathsData, {
  InheritanceResult Function(InheritanceInput)? calculator,
}) {
  if (deathsData.isEmpty) {
    throw ArgumentError('مسائل غرق‌شدگان و زیرآوار به حداقل یک فوت نیاز دارد.');
  }
  final calc = calculator ?? calculateInheritance;

  final stages = <MunasakhatStage>[];
  final firstEstate = deathsData.first.$2.estate;

  for (int i = 0; i < deathsData.length; i++) {
    final (deceased, input) = deathsData[i];
    final estate =
        input.estate > 0 ? input.estate : (i == 0 ? firstEstate : 0.0);
    final stageInput = input.copyWith(estate: estate);
    final result = calc(stageInput);
    stages.add(MunasakhatStage(
      deceasedLabel: deceased,
      input: stageInput,
      result: result,
    ));
  }

  return GharqaHadmaCase(
    label: label,
    stages: stages,
    totalEstate: firstEstate,
    explanation:
        'چون غرق‌شدگان و زیرآوارماندگان و مانند آنان همه در یک حادثه مرده‌اند، '
        'بعضی از بعضی ارث نمی‌برند؛ بنابراین ترکهٔ هر یک فقط میان ورثهٔ زندهٔ او '
        'تقسیم می‌شود. محاسبه به روش موسوعهٔ اسلامی انجام می‌شود: فرض می‌شود یکی '
        'از متوفیان نخست مرده باشد و ترکهٔ او میان ورثهٔ زندهٔ او و همراه‌مرده‌ها '
        'تقسیم گردد؛ سپس سهم هر متوفی دیگر میان ورثهٔ زندهٔ او بازتوزیع می‌شود تا '
        'مسائل همه کامل شود.',
  );
}

/// وصف الطريقة المتبعة في مناسخة الغرقى والهدمى.
const String gharqaHadmaMethodDescription =
    'فرض می‌شود یکی از متوفیان نخست مرده باشد و برای او مسأله‌ای بسته می‌شود که میان '
    'ورثهٔ زندهٔ او و کسانی که با او مرده‌اند تقسیم می‌شود؛ سپس برای زنده‌ماندگانِ ورثهٔ '
    'متوفیِ بعدی، مسألهٔ دوم ساخته و سهم او از مسألهٔ متوفی اول را — همان‌گونه که در '
    'مناسخات گذشت — روی آن تقسیم می‌کنیم؛ آنگاه به سراغ مسألهٔ متوفی دوم می‌رویم و آن را '
    'میان ورثهٔ زندهٔ او و همراه‌مرده‌هایش تقسیم کرده، سهم هر یک را در مسألهٔ جداگانهٔ '
    'ورثه‌اش تصحیح می‌کنیم. بدین‌سان مسائل همهٔ متوفیان کامل می‌شود.';
