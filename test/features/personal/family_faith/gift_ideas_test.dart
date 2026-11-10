import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_gift_ideas.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';

void main() {
  late List<GiftIdea> ideas;

  setUpAll(() {
    final raw = File('assets/data/gift_ideas.json').readAsStringSync();
    ideas = parseGiftIdeas(raw);
  });

  group('catalogue integrity', () {
    test('parses between forty and sixty ideas', () {
      expect(ideas.length, inInclusiveRange(40, 60));
    });

    test('ids are unique and every idea has a title and a tip', () {
      final ids = ideas.map((idea) => idea.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final idea in ideas) {
        expect(idea.title.trim(), isNotEmpty, reason: idea.id);
        expect(idea.tip.trim(), isNotEmpty, reason: idea.id);
      }
    });

    test('every occasion, budget and audience has at least one idea', () {
      for (final occasion in GiftOccasion.values) {
        expect(
          ideas.any((idea) => idea.occasions.contains(occasion)),
          isTrue,
          reason: 'occasion ${occasion.key} is unreachable',
        );
      }
      for (final budget in GiftBudget.values) {
        expect(
          ideas.any((idea) => idea.budgets.contains(budget)),
          isTrue,
          reason: 'budget ${budget.key} is unreachable',
        );
      }
      for (final audience in GiftAudience.values) {
        expect(
          ideas.any((idea) => idea.audiences.contains(audience)),
          isTrue,
          reason: 'audience ${audience.key} is unreachable',
        );
      }
    });

    test('the catalogue carries no price, brand or forbidden item', () {
      // Guard rails for a hand-written data file: a number followed by a
      // currency word would read as a price claim, and the list must stay
      // free of the items this app must never suggest.
      final forbidden = <String>['الکل', 'مشروب', 'شراب', 'تنباکو', 'سیگار'];
      for (final idea in ideas) {
        for (final word in forbidden) {
          expect(
            '${idea.title} ${idea.tip}'.contains(word),
            isFalse,
            reason: '${idea.id} mentions $word',
          );
        }
        expect(
          RegExp(r'\d+\s*(تومان|ریال|هزار|میلیون)').hasMatch(idea.tip),
          isFalse,
          reason: '${idea.id} states a price',
        );
      }
    });

    test('no birthday and no non-Islamic festival (2026-11-07 decision)', () {
      // The user asked for sharia-appropriate occasions. The parsed enum has
      // no birthday member, and the raw file must not smuggle one back in as
      // an unknown key that `fromKey` would quietly drop.
      final raw = File('assets/data/gift_ideas.json').readAsStringSync();
      final occasions = RegExp(r'"occasions": \[([^\]]*)\]')
          .allMatches(raw)
          .expand((match) => match.group(1)!.split(','))
          .map((key) => key.trim().replaceAll('"', ''))
          .toSet();
      expect(occasions, isNot(contains('birthday')));
      for (final forbidden in const [
        'christmas',
        'new_year',
        'valentine',
        'halloween',
      ]) {
        expect(occasions, isNot(contains(forbidden)));
      }
      final known = GiftOccasion.values.map((o) => o.key).toSet();
      expect(occasions.difference(known), isEmpty,
          reason: 'every occasion key must map to an enum member');
    });

    test('a malformed document degrades to an empty list', () {
      expect(parseGiftIdeas('{not json'), isEmpty);
      expect(parseGiftIdeas('{"ideas": []}'), isEmpty);
    });
  });

  group('filtering', () {
    test('narrows by occasion, budget and audience together', () {
      final filtered = filterGiftIdeas(
        ideas,
        occasion: GiftOccasion.sickVisit,
        budget: GiftBudget.economy,
        audience: GiftAudience.all,
      );
      expect(filtered, isNotEmpty);
      for (final idea in filtered) {
        expect(idea.occasions, contains(GiftOccasion.sickVisit));
        expect(idea.budgets, contains(GiftBudget.economy));
      }
    });

    test('an idea tagged «همه» appears for a child as well', () {
      final filtered = filterGiftIdeas(
        ideas,
        occasion: GiftOccasion.visit,
        budget: GiftBudget.economy,
        audience: GiftAudience.child,
      );
      expect(filtered, isNotEmpty);
      for (final idea in filtered) {
        expect(
          idea.audiences.contains(GiftAudience.child) ||
              idea.audiences.contains(GiftAudience.all),
          isTrue,
        );
      }
    });

    test('a filter never returns an idea outside the chosen occasion or budget',
        () {
      for (final occasion in GiftOccasion.values) {
        for (final budget in GiftBudget.values) {
          for (final idea
              in filterGiftIdeas(ideas,
                  occasion: occasion,
                  budget: budget,
                  audience: GiftAudience.child)) {
            expect(idea.occasions, contains(occasion));
            expect(idea.budgets, contains(budget));
          }
        }
      }
    });

    test('an empty catalogue filters to an empty list, not an error', () {
      expect(
        filterGiftIdeas(
          const [],
          occasion: GiftOccasion.visit,
          budget: GiftBudget.medium,
          audience: GiftAudience.all,
        ),
        isEmpty,
      );
    });

    test('order is the catalogue order, so the list does not jump around', () {
      final first = filterGiftIdeas(
        ideas,
        occasion: GiftOccasion.visit,
        budget: GiftBudget.medium,
        audience: GiftAudience.all,
      );
      final second = filterGiftIdeas(
        ideas,
        occasion: GiftOccasion.visit,
        budget: GiftBudget.medium,
        audience: GiftAudience.all,
      );
      expect(first.map((i) => i.id), second.map((i) => i.id));
    });
  });
}
