import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

IconData _iconFromString(String name) {
  switch (name) {
    case 'info_outline':
      return Icons.info_outline;
    case 'mosque_outlined':
      return Icons.mosque_outlined;
    case 'landscape_outlined':
      return Icons.landscape_outlined;
    case 'compare_arrows_outlined':
      return Icons.compare_arrows_outlined;
    case 'explore_outlined':
      return Icons.explore_outlined;
    case 'star_outline_rounded':
      return Icons.star_outline_rounded;
    case 'folder_outlined':
      return Icons.folder_outlined;
    case 'account_balance_wallet_outlined':
      return Icons.account_balance_wallet_outlined;
    case 'checkroom_outlined':
      return Icons.checkroom_outlined;
    case 'medical_services_outlined':
      return Icons.medical_services_outlined;
    case 'book_outlined':
      return Icons.book_outlined;
    case 'flight_takeoff_outlined':
      return Icons.flight_takeoff_outlined;
    default:
      return Icons.info_outline;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Data model classes
// ═══════════════════════════════════════════════════════════════════
class ConceptData {
  final IconData icon;
  final String title;
  final String body;
  const ConceptData(
      {required this.icon, required this.title, required this.body});

  factory ConceptData.fromJson(Map<String, dynamic> json) {
    return ConceptData(
      icon: _iconFromString(json['icon'] as String? ?? 'info_outline'),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class HajjTypeData {
  final String title;
  final String subtitle;
  final String description;
  final String note;
  const HajjTypeData(
      {required this.title,
      required this.subtitle,
      required this.description,
      required this.note});

  factory HajjTypeData.fromJson(Map<String, dynamic> json) {
    return HajjTypeData(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

/// A single ritual step (umrah or hajj day). [step] is the caller-facing
/// number sourced from the JSON `step` field — never from list order — so the
/// displayed number stays correct even if the JSON array is reordered.
class RitualStepData {
  final int step;
  final String title;
  final String subtitle;
  final String arabic;
  final String description;
  final String tip;
  const RitualStepData({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.arabic,
    required this.description,
    required this.tip,
  });

  factory RitualStepData.fromJson(Map<String, dynamic> json) {
    return RitualStepData(
      step: (json['step'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      arabic: json['arabic'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

class RulingItem {
  final String title;
  final String body;
  const RulingItem({required this.title, required this.body});

  factory RulingItem.fromJson(Map<String, dynamic> json) {
    return RulingItem(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class RulingSection {
  /// Stable identifier used for section routing. Falls back to [title] only
  /// when the JSON omits `id`, so a Persian title change never silently drops
  /// content from a tab.
  final String id;
  final String title;
  final String subtitle;
  final List<RulingItem> items;
  const RulingSection(
      {required this.id,
      required this.title,
      required this.subtitle,
      required this.items});

  factory RulingSection.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    return RulingSection(
      id: json['id'] as String? ?? title,
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
      items: (json['items'] as List? ?? const [])
          .map((e) => RulingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChecklistItem {
  final String title;
  const ChecklistItem({required this.title});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(title: json['title'] as String? ?? '');
  }
}

class ChecklistSection {
  final String title;
  final IconData icon;
  final List<ChecklistItem> items;
  const ChecklistSection(
      {required this.title, required this.icon, required this.items});

  factory ChecklistSection.fromJson(Map<String, dynamic> json) {
    return ChecklistSection(
      title: json['title'] as String? ?? '',
      icon: _iconFromString(json['icon'] as String? ?? 'info_outline'),
      items: (json['items'] as List? ?? const [])
          .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class FaqItem {
  final String question;
  final String answer;
  const FaqItem({required this.question, required this.answer});

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HajjData
// ═══════════════════════════════════════════════════════════════════
class HajjData {
  HajjData._();

  static Map<String, dynamic>? _data;
  static Object? _loadError;
  static bool get isLoaded => _data != null;
  static bool get hasLoadError => _loadError != null;

  /// Clears the cache so the next [load] re-reads the asset. Used by the
  /// in-screen retry button after a failed load.
  static void resetForRetry() {
    _data = null;
    _loadError = null;
  }

  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/hajj.json');
      _data =
          latinizeJsonDigits(json.decode(jsonString)) as Map<String, dynamic>;
      _loadError = null;
    } catch (e) {
      AppLogger.warning('hajj_content', 'failed to load hajj.json: $e');
      _loadError = e;
      // Rethrow so the surrounding LazyContent FutureBuilder can surface the
      // failure and offer a retry instead of rendering empty tabs.
      rethrow;
    }
  }

  static const Color accent = Color(0xFFC9A94E);

  static const String disclaimer =
      'تمام احکام فوق بر اساس مذهب امام شافعی (رضی الله عنه) بیان شد که برگرفته از کتاب‌های معتبر فقه شافعی است. در مسائل مورد اختلاف با سایر مذاهب، گاه به اختصار اشاره شد تا خواننده آگاه باشد.\n\nبرای هر گونه مسألهٔ خاص، مراجعه به عالم دینی مورد اعتماد توصیه می‌شود، و این نوشتار تنها جنبهٔ آموزشی و تذکری دارد.\n\n«وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ ۚ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ» [هود: 88].';

  static List<T> _list<T>(
      String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _data?[key];
    if (raw is List) {
      return raw
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  static List<ConceptData> get introConcepts =>
      _list('introConcepts', ConceptData.fromJson);

  static List<RitualStepData> get umrahSteps =>
      _list('umrahSteps', RitualStepData.fromJson);

  static List<RitualStepData> get hajjSteps =>
      _list('hajjSteps', RitualStepData.fromJson);

  static List<RulingSection> get rulings =>
      _list('rulings', RulingSection.fromJson);

  static List<HajjTypeData> get hajjTypes =>
      _list('hajjTypes', HajjTypeData.fromJson);

  static List<ChecklistSection> get checklistSections =>
      _list('checklistSections', ChecklistSection.fromJson);

  static RulingSection? _sectionById(String id) {
    for (final s in rulings) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<Map<String, String>> _itemsOf(String id) =>
      _sectionById(id)
          ?.items
          .map((i) => {'title': i.title, 'body': i.body})
          .toList() ??
      const [];

  static List<Map<String, String>> get pillars => _itemsOf('hajj-pillars');

  static List<Map<String, String>> get expiation => _itemsOf('kaffarah');

  /// Special rulings aggregate the women / contemporary / niyaba sections.
  static List<Map<String, String>> get specialRulings {
    const ids = {'women', 'contemporary', 'niyaba'};
    return rulings
        .where((s) => ids.contains(s.id))
        .expand((s) => s.items.map((i) => {'title': i.title, 'body': i.body}))
        .toList();
  }

  /// Sections shown on the "pillars & prohibitions" tab: everything except the
  /// expiation, special-rulings and hajj-types sections (types get their own
  /// richer cards) — routed by stable id, not by title.
  static List<RulingSection> get coreRulingSections {
    const excluded = {
      'kaffarah',
      'women',
      'contemporary',
      'niyaba',
      'types',
    };
    return rulings.where((s) => !excluded.contains(s.id)).toList();
  }

  /// FAQ lives in JSON like every other section; the constant below is a
  /// safety net so the tab is never empty if the asset omits `faq`.
  static List<FaqItem> get faq {
    final fromAsset = _list('faq', FaqItem.fromJson);
    return fromAsset.isNotEmpty ? fromAsset : _fallbackFaq;
  }

  static const List<FaqItem> _fallbackFaq = [
    FaqItem(
      question: 'آیا می‌توانم حج را نیابتی انجام دهم؟',
      answer:
          'بله، اگر شخص فوت کرده یا به بیماری لاعلاج مبتلاست و توانایی جسمی و مالی ندارد، می‌تواند نائب بگیرد. نائب باید مسلمان، بالغ، عاقل و خود قبلاً حجة الإسلام را انجام داده باشد.',
    ),
    FaqItem(
      question: 'حج تمتع با حج قران چه فرقی دارد؟',
      answer:
          'در حج تمتع، ابتدا عمره انجام می‌دهید و از احرام خارج می‌شوید، سپس در روز 8 ذی‌حجه برای حج محرم می‌شوید. در حج قران، با یک احرام نیت هر دو را می‌کنید و تا پایان مناسک از احرام خارج نمی‌شوید. در هر دو، قربانی واجب است.',
    ),
    FaqItem(
      question: 'حکم کسی که به عرفه نرسد چیست؟',
      answer:
          'وقوف در عرفه رکن اصلی حج است. هر کس به عرفه نرسد، حجش باطل است و باید قضا کند. پیامبر ﷺ فرمود: «الْحَجُّ عَرَفَة».',
    ),
    FaqItem(
      question: 'آیا زن بدون محرم می‌تواند حج کند؟',
      answer:
          'در مذهب شافعی، محرم (یا همراه امن و امنیت راه) شرط وجوب حج است؛ یعنی با نبودن آن، حج بر زن واجب نمی‌شود. در شرطِ صحت بودن آن میان فقها بحث است و بسیاری از شافعیه آن را شرط صحت هم دانسته‌اند. در هر حال رفتن بدون محرم یا بدون امنیت راه جایز نیست و برای هر گونه مسألهٔ خاص باید به عالم دینی مراجعه شود.',
    ),
    FaqItem(
      question: 'اگر در حال احرام عطر بزنم چه حکمی دارد؟',
      answer:
          'استفاده از عطر در حال احرام ممنوع است. اگر عمداً عطر بزنید، باید فدیه بدهید: یا یک گوسفند قربانی کنید، یا سه روز روزه بگیرید، یا به شش فقیر طعام بدهید.',
    ),
    FaqItem(
      question: 'طواف وداع چیست و بر چه کسی واجب است؟',
      answer:
          'طواف وداع آخرین عمل حج است که قبل از خروج از مکه انجام می‌شود. بر غیر اهل مکه واجب است. زنان در ایام حیض از طواف وداع معاف هستند.',
    ),
    FaqItem(
      question: 'آیا می‌توانم در حج از کارت اعتباری استفاده کنم؟',
      answer:
          'بله، در صورتی که معاملهٔ ربوی نباشد و با ضوابط شرعی مطابقت داشته باشد، استفاده از کارت‌های بانکی برای پرداخت هزینه‌ها جایز است.',
    ),
    FaqItem(
      question: 'حکم روزه گرفتن در ایام تشریق چیست؟',
      answer:
          'روزه گرفتن در ایام تشریق (11، 12 و 13 ذی‌حجه) برای حاجیان جایز نیست. اما برای غیر حاجیان، روزه در این ایام مکروه است.',
    ),
  ];

  static Map<String, List<String>> get checklists {
    return {
      for (final s in checklistSections)
        s.title: s.items.map((i) => i.title).toList()
    };
  }
}

// ═══════════════════════════════════════════════════════════════════
// HajjDetailsAndChecklistData — shares HajjData's JSON
// ═══════════════════════════════════════════════════════════════════
class HajjDetailsAndChecklistData {
  HajjDetailsAndChecklistData._();

  static List<Map<String, dynamic>> get topics {
    final v = HajjData._data?['topics'];
    if (v is List) return v.cast<Map<String, dynamic>>();
    return [];
  }
}
