/// Offline gift-idea catalogue for «صله رحم» (stage 3).
///
/// Deliberately **no AI and no network**: `assets/data/gift_ideas.json` is a
/// hand-written list of ordinary, practical gifts with one tip each. The data
/// has no prices, no brands and no ruling attached to it — the budget tiers are
/// relative labels, not amounts.
library;

import 'dart:convert';

import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// When a gift is being taken. `key` is what lives in the JSON.
///
/// Sharia note (user decision 2026-11-07): the list carries no birthday and no
/// non-Islamic festival. A newborn is not a «birthday» either — it is the
/// ordinary family joy of a new child — so [newBaby] stays and the yearly
/// birthday occasion is gone entirely.
enum GiftOccasion {
  visit('visit', 'دیدار'),
  sickVisit('sick_visit', 'عیادت'),
  hosting('hosting', 'مهمانی'),
  feast('feast', 'عید و مناسبت'),
  ramadan('ramadan', 'ماه رمضان'),
  newBaby('new_baby', 'نوزاد'),
  newlywed('newlywed', 'تازه‌عروس');

  const GiftOccasion(this.key, this.labelFa);

  final String key;
  final String labelFa;

  static GiftOccasion fromKey(String value) => GiftOccasion.values.firstWhere(
        (o) => o.key == value,
        orElse: () => GiftOccasion.visit,
      );
}

/// A relative budget tier. No amounts are attached on purpose: what is
/// «اقتصادی» for one household is not for another.
enum GiftBudget {
  economy('economy', 'اقتصادی'),
  medium('medium', 'متوسط'),
  special('special', 'ویژه');

  const GiftBudget(this.key, this.labelFa);

  final String key;
  final String labelFa;

  static GiftBudget fromKey(String value) => GiftBudget.values.firstWhere(
        (b) => b.key == value,
        orElse: () => GiftBudget.medium,
      );
}

class GiftIdea {
  const GiftIdea({
    required this.id,
    required this.title,
    required this.tip,
    required this.occasions,
    required this.budgets,
    required this.audiences,
  });

  final String id;
  final String title;
  final String tip;
  final Set<GiftOccasion> occasions;
  final Set<GiftBudget> budgets;
  final Set<GiftAudience> audiences;

  bool matches({
    required GiftOccasion occasion,
    required GiftBudget budget,
    required GiftAudience audience,
  }) {
    final audienceOk =
        audiences.contains(audience) || audiences.contains(GiftAudience.all);
    return occasions.contains(occasion) &&
        budgets.contains(budget) &&
        audienceOk;
  }
}

/// Parses the bundled catalogue. A malformed row is skipped, never fatal: a
/// missing idea must not take the relatives screen down.
List<GiftIdea> parseGiftIdeas(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['ideas'] is! List) return const [];
    final ideas = <GiftIdea>[];
    for (final row in decoded['ideas'] as List) {
      if (row is! Map) continue;
      final id = (row['id'] as String?)?.trim() ?? '';
      final title = (row['title'] as String?)?.trim() ?? '';
      final tip = (row['tip'] as String?)?.trim() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      final occasions = _keys(row['occasions'], GiftOccasion.fromKey);
      final budgets = _keys(row['budgets'], GiftBudget.fromKey);
      final audiences = _keys(row['audiences'], GiftAudience.fromKey);
      if (occasions.isEmpty || budgets.isEmpty || audiences.isEmpty) continue;
      ideas.add(GiftIdea(
        id: id,
        title: title,
        tip: tip,
        occasions: occasions,
        budgets: budgets,
        audiences: audiences,
      ));
    }
    return ideas;
  } catch (e) {
    AppLogger.warning('GiftIdeas', 'catalogue read failed: $e');
    return const [];
  }
}

Set<T> _keys<T>(Object? raw, T Function(String) map) {
  if (raw is! List) return <T>{};
  return raw.whereType<String>().map(map).toSet();
}

/// Ideas for one occasion + budget + audience, stable in catalogue order.
List<GiftIdea> filterGiftIdeas(
  List<GiftIdea> ideas, {
  required GiftOccasion occasion,
  required GiftBudget budget,
  required GiftAudience audience,
}) {
  return [
    for (final idea in ideas)
      if (idea.matches(occasion: occasion, budget: budget, audience: audience))
        idea,
  ];
}
