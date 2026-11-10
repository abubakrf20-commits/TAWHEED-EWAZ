import 'package:flutter/material.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';

/// One heir row of the picker: its Persian display label, its glyph, and how
/// deep it sits in the family tree (0 = closest, nested under its ancestor,
/// e.g. پدر → پدربزرگ → پدرِپدربزرگ).
///
/// This is the single table both the محاسبه tab and the مناسخات sheet draw
/// from, so the two can never offer a different set of heirs.
class HeirOption {
  final HeirType type;
  final String label;
  final IconData icon;
  final int indent;

  const HeirOption(this.type, this.label, this.icon, {this.indent = 0});

  int get maxCount => heirMaxCount(type);
}

/// Display order: spouse, then the paternal line, the maternal line, the
/// descendants, siblings and the distant relatives.
const List<HeirOption> kHeirOptions = [
  HeirOption(HeirType.husband, 'شوهر', Icons.man),
  HeirOption(HeirType.wife, 'همسر', Icons.woman),
  HeirOption(HeirType.father, 'پدر', Icons.elderly),
  HeirOption(HeirType.grandfather, 'پدربزرگ پدری (پدرِ پدر)', Icons.elderly,
      indent: 1),
  HeirOption(
      HeirType.greatGrandfather, 'پدرِ پدربزرگ (پدرِ پدرِ پدر)', Icons.elderly,
      indent: 2),
  HeirOption(HeirType.mother, 'مادر', Icons.elderly_woman),
  HeirOption(
      HeirType.maternalGrandmother, 'مادربزرگ مادری (مادرِ مادر)',
      Icons.elderly_woman,
      indent: 1),
  HeirOption(
      HeirType.paternalGrandmother, 'مادربزرگ پدری (مادرِ پدر)',
      Icons.elderly_woman,
      indent: 1),
  HeirOption(HeirType.greatMaternalGrandmother, 'مادرِ مادرِ مادر',
      Icons.elderly_woman,
      indent: 2),
  HeirOption(HeirType.paternalGreatGrandmotherFather, 'مادرِ پدرِ پدر',
      Icons.elderly_woman,
      indent: 2),
  HeirOption(HeirType.paternalGreatGrandmotherMother, 'مادرِ مادرِ پدر',
      Icons.elderly_woman,
      indent: 2),
  HeirOption(HeirType.son, 'پسر', Icons.boy, indent: 1),
  HeirOption(HeirType.grandson, 'پسرِ پسر', Icons.boy, indent: 2),
  HeirOption(HeirType.greatGrandson, 'پسرِ پسرِ پسر', Icons.boy, indent: 3),
  HeirOption(HeirType.daughter, 'دختر', Icons.girl, indent: 1),
  HeirOption(HeirType.granddaughter, 'دخترِ پسر', Icons.girl, indent: 2),
  HeirOption(HeirType.greatGranddaughter, 'دخترِ پسرِ پسر', Icons.girl,
      indent: 3),
  HeirOption(HeirType.fullBrother, 'برادر (پدری و مادری)', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.fullSister, 'خواهر (پدری و مادری)', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.paternalBrother, 'برادر پدری', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.paternalSister, 'خواهر پدری', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.maternalBrother, 'برادر مادری', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.maternalSister, 'خواهر مادری', Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.nephewFull, 'پسرِ برادرِ پدری و مادری',
      Icons.diversity_1,
      indent: 1),
  HeirOption(HeirType.nephewPaternal, 'پسرِ برادرِ پدری', Icons.diversity_1,
      indent: 2),
  HeirOption(HeirType.nephewSonFull, 'پسرِ پسرِ برادرِ پدری و مادری',
      Icons.diversity_1,
      indent: 3),
  HeirOption(HeirType.nephewSonPaternal, 'پسرِ پسرِ برادرِ پدری',
      Icons.diversity_1,
      indent: 3),
  HeirOption(HeirType.paternalUncle, 'عمو (برادر پدر)', Icons.elderly,
      indent: 1),
  HeirOption(HeirType.paternalUnclePaternal, 'عموی پدری (برادر پدریِ پدر)',
      Icons.elderly,
      indent: 1),
  HeirOption(HeirType.paternalUncleSon, 'پسر عمو (پسر برادر پدر)',
      Icons.diversity_1,
      indent: 2),
  HeirOption(HeirType.paternalUncleSonPaternal, 'پسر عموی پدری',
      Icons.diversity_1,
      indent: 2),
  HeirOption(HeirType.paternalUncleGrandson, 'پسرِ پسرِ عمو', Icons.diversity_1,
      indent: 2),
  HeirOption(HeirType.paternalUncleGrandsonPaternal, 'پسرِ پسرِ عمویِ پدری',
      Icons.diversity_1,
      indent: 3),
  HeirOption(HeirType.fatherUncleFull, 'عمویِ پدر (برادرِ پدربزرگ)',
      Icons.elderly,
      indent: 1),
  HeirOption(
      HeirType.fatherUnclePaternal, 'عموی پدریِ پدر (برادرِ پدریِ پدربزرگ)',
      Icons.elderly,
      indent: 2),
  HeirOption(HeirType.fatherCousinFull, 'پسرِ عمویِ پدر', Icons.diversity_1,
      indent: 2),
  HeirOption(HeirType.fatherCousinPaternal, 'پسرِ عمویِ پدریِ پدر',
      Icons.diversity_1,
      indent: 3),
  HeirOption(HeirType.nieceSon, 'پسرِ خواهر', Icons.boy, indent: 1),
  HeirOption(HeirType.nieceFull, 'دخترِ برادرِ پدری و مادری', Icons.girl,
      indent: 1),
  HeirOption(HeirType.niecePaternal, 'دخترِ برادرِ پدری', Icons.girl,
      indent: 1),
  HeirOption(HeirType.maternalUncle, 'دایی (برادرِ مادر)', Icons.elderly,
      indent: 1),
  HeirOption(HeirType.maternalAunt, 'خاله (خواهرِ مادر)', Icons.elderly_woman,
      indent: 1),
  HeirOption(HeirType.paternalAunt, 'عمه (خواهرِ پدر)', Icons.elderly_woman,
      indent: 1),
  HeirOption(HeirType.uncleDaughter, 'دخترِ عمو', Icons.girl, indent: 1),
];

/// The heir itself, looked up from the shared table.
HeirOption? heirOptionOf(HeirType type) {
  for (final o in kHeirOptions) {
    if (o.type == type) return o;
  }
  return null;
}

/// A man never has a husband and a woman never has more than four wives, so
/// the spouse row of the opposite gender is not offered.
List<HeirOption> visibleHeirOptions({required bool isMale}) => kHeirOptions
    .where((o) => o.type != (isMale ? HeirType.husband : HeirType.wife))
    .toList(growable: false);
