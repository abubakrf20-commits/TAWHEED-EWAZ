import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_comparison_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_basics_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_heirs_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_rules_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_special_cases_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_mandatory_will_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_exam_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_fraction_calculator_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_shares_calculator_tab.dart';

class InheritanceScreen extends StatelessWidget {
  const InheritanceScreen({super.key});

  static const List<String> _tabs = [
    'محاسبه',
    'ماشین حساب کسرها',
    'ماشین حساب سهام',
    'حالات خاص',
    'وصیت واجبه',
    'آزمون',
    'مقایسه',
    'مبانی',
    'ورثه',
    'قواعد',
  ];

  /// Which tab each content category is rendered in, and the label the search
  /// result card shows for it.
  static const Map<String, (int, String)> _categoryTab = {
    'basics': (7, 'مبانی'),
    'heirs': (8, 'ورثه'),
    'rules': (9, 'قواعد'),
  };

  /// The reading half of the page, indexed for the in-section search.
  ///
  /// The four calculators (محاسبه، کسرها، سهام، حالات خاص) have no prose to
  /// search, so they contribute nothing — a hit that lands on an empty form is
  /// a false promise. What is indexed is where a ruling actually lives: the
  /// section titles plus every subsection body and bullet under them.
  static List<SectionSearchEntry> _buildSearchEntries() {
    final entries = <SectionSearchEntry>[];
    for (final section in InheritanceContent.sections) {
      final target = _categoryTab[section['category'] as String? ?? ''];
      if (target == null) continue;
      final body = StringBuffer();
      final subsections = section['subsections'];
      if (subsections is List) {
        for (final raw in subsections) {
          if (raw is! Map) continue;
          body
            ..write(raw['title'] ?? '')
            ..write(' ')
            ..write(raw['body'] ?? '')
            ..write(' ');
          final items = raw['items'];
          if (items is List) body.write('${items.join(' ')} ');
        }
      }
      entries.add(SectionSearchEntry(
        tab: target.$1,
        tabLabel: target.$2,
        title: section['title'] as String? ?? '',
        body: body.toString().trim(),
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildSearchEntries();
    return SectionPage(
      id: 'inheritance',
      title: 'میراث',
      tabs: _tabs,
      searchEntries: entries.isEmpty ? null : entries,
      children: const [
        InheritanceCalculatorTab(),
        InheritanceFractionCalculatorTab(),
        InheritanceSharesCalculatorTab(),
        InheritanceSpecialCasesTab(),
        InheritanceMandatoryWillTab(),
        InheritanceExamTab(),
        InheritanceComparisonTab(),
        InheritanceBasicsTab(),
        InheritanceHeirsTab(),
        InheritanceRulesTab(),
      ],
    );
  }
}
