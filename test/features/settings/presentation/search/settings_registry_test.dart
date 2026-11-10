import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/account/presentation/screens/account_screen.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart'
    show FontDisplayPage;
import 'package:tawheeed/features/settings/presentation/search/settings_registry.dart';

void main() {
  group('registry integrity', () {
    test('ids are unique', () {
      final ids = SettingsRegistry.entries.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every route is a known settings route', () {
      for (final entry in SettingsRegistry.entries) {
        final route = entry.route;
        if (route == null) continue;
        expect(settingsKnownRoutes, contains(route),
            reason: '${entry.id} points at $route');
      }
    });

    test('every preference key is covered or explicitly orphaned', () {
      final covered = <String>{
        for (final entry in SettingsRegistry.entries) ...entry.prefs,
      };
      final missing = settingsAllKeys
          .where((k) => !covered.contains(k) && !settingsOrphanKeys.containsKey(k))
          .toList();
      expect(missing, isEmpty,
          reason: 'uncovered keys without an orphan note: $missing');
    });

    test('row keys exist wherever a route is absent', () {
      // An entry with no route must address an anchor row on its own page,
      // otherwise tapping it goes nowhere.
      for (final entry in SettingsRegistry.entries) {
        if (entry.route == null) {
          expect(entry.rowKey, isNotNull, reason: entry.id);
        }
      }
    });

    test('account-page row keys land on real hub anchors', () {
      // Backup, transfer and reset rows moved off the main page into the
      // account hub; every registry entry pointing at it must name an
      // anchor the hub actually builds, or the highlight lands nowhere.
      for (final entry in SettingsRegistry.entries) {
        if (entry.page == SettingsSearchPage.account &&
            entry.rowKey != null) {
          expect(AccountScreen.accountHighlightKeys, contains(entry.rowKey),
              reason: entry.id);
        }
      }
    });

    test('font-page row keys land on real «فونت و نمایش» anchors', () {
      // «روش عرضه ماه» moved off the main page into the font/display card, so
      // the font page owns the same anchor contract as the account hub.
      for (final entry in SettingsRegistry.entries) {
        if (entry.page == SettingsSearchPage.font && entry.rowKey != null) {
          expect(FontDisplayPage.fontHighlightKeys, contains(entry.rowKey),
              reason: entry.id);
        }
      }
    });

    test('«روش عرضه ماه» is searched on the font page', () {
      expect(searchSettings('نام ماه').map((e) => e.id),
          contains('font.month_display'));
      final entry = SettingsRegistry.entries
          .firstWhere((e) => e.id == 'font.month_display');
      expect(entry.page, SettingsSearchPage.font);
      expect(entry.rowKey, 'monthDisplay');
      expect(entry.prefs, const ['month_display']);
      // …and no main-page entry still claims the row.
      expect(
          SettingsRegistry.entries.where((e) =>
              e.page == SettingsSearchPage.main &&
              e.rowKey == 'monthDisplay'),
          isEmpty);
    });

    test('«واحد پول» is one main-page row covering both currency stores', () {
      final entry =
          SettingsRegistry.entries.firstWhere((e) => e.id == 'main.currency');
      expect(entry.page, SettingsSearchPage.main);
      // Anchor row on the main page itself, so no route.
      expect(entry.route, isNull);
      expect(entry.rowKey, 'currency');
      // Two stores, two keys — neither may be dropped, or the integrity check
      // below would report the other one as uncovered.
      expect(entry.prefs,
          containsAll(<String>['app_currency_code', 'expenses_currency_code']));
      expect(searchSettings('واحد پول').map((e) => e.id), contains('main.currency'));
      expect(searchSettings('افغانی').map((e) => e.id), contains('main.currency'));
    });
  });

  group('normalizeSettingsQuery', () {
    test('folds Arabic yeh/kaf to Persian', () {
      expect(normalizeSettingsQuery('يادآوري'), 'یاداوری');
      expect(normalizeSettingsQuery('كاف'), 'کاف');
    });

    test('drops diacritics, tatweel and ZWNJ', () {
      expect(normalizeSettingsQuery('مُطالعه'), 'مطالعه');
      expect(normalizeSettingsQuery('می‌شود'), 'میشود');
    });

    test('folds all digit shapes to Latin', () {
      expect(normalizeSettingsQuery('۰۲٤'), '024');
    });
  });

  group('searchSettings ranking', () {
    test('title matches outrank keyword matches', () {
      final results = searchSettings('اذان');
      expect(results, isNotEmpty);
      // 'اذان فجر' starts with the token; pure keyword hits sort after.
      expect(results.first.title, contains('اذان'));
    });

    test('every token must match literally or through a synonym', () {
      final results = searchSettings('اذان فجر');
      expect(results.map((e) => e.id), contains('prayer.adhan.fajr'));
      for (final entry in results) {
        final haystack = normalizeSettingsQuery(
            '${entry.title} ${entry.subtitle ?? ''} ${entry.keywords.join(' ')}');
        for (final token in ['اذان', 'فجر']) {
          // A token matches the row's own text, or any term it stands for.
          // Anything else means the AND semantics leaked.
          final matched = settingsSearchAlternatives(token).any(haystack.contains);
          expect(matched, isTrue, reason: '${entry.id} did not match «$token»');
        }
      }
    });

    test('Arabic-script queries match Persian titles', () {
      final results = searchSettings('يادآوري');
      expect(results.map((e) => e.id),
          contains('prayer.notif'));
    });

    test('empty query returns nothing', () {
      expect(searchSettings('   '), isEmpty);
    });
  });

  group('synonyms', () {
    test('no term belongs to two groups', () {
      // A term in two groups would silently widen one of them; the index keeps
      // the first hit, so the second would be dead weight nobody notices.
      // Repeating a term inside ONE group is harmless — normalization folds it
      // («آپدیت»/«اپدیت», «قرآن»/«قران») and the group is a Set.
      final seen = <String, int>{};
      for (var i = 0; i < settingsSearchSynonymGroups.length; i++) {
        for (final term in settingsSearchSynonymGroups[i]) {
          final normalized = normalizeSettingsQuery(term);
          final previous = seen[normalized];
          if (previous != null) {
            expect(previous, i,
                reason: '«$term» appears in groups $previous and $i');
            continue;
          }
          seen[normalized] = i;
        }
      }
    });

    test('every group has at least two distinct normalized terms', () {
      for (final group in settingsSearchSynonymGroups) {
        final normalized = {
          for (final term in group)
            if (normalizeSettingsQuery(term).isNotEmpty)
              normalizeSettingsQuery(term),
        };
        expect(normalized.length, greaterThanOrEqualTo(2),
            reason: 'group $group collapses after normalization');
      }
    });

    test('alternatives lead with the token itself', () {
      expect(settingsSearchAlternatives('صدا').first, 'صدا');
      expect(settingsSearchAlternatives('صدا'), contains('ولوم'));
      // An unknown word is its own only alternative.
      expect(settingsSearchAlternatives('زرافه'), const ['زرافه']);
    });

    test('colloquial and Latin words find the same rows', () {
      // The words a user actually types, none of which appears in any label.
      expect(searchSettings('نوتیفیکیشن').map((e) => e.id),
          contains('main.notifications'));
      expect(searchSettings('بکاپ').map((e) => e.id), isNotEmpty);
      expect(searchSettings('ولوم اذان').map((e) => e.id),
          contains('main.adhan_volume'));
      expect(searchSettings('azan').map((e) => e.id), contains('prayer.adhan_sound'));
      expect(searchSettings('ابزارک').map((e) => e.id), contains('main.widgets'));
      expect(searchSettings('سایلنت').map((e) => e.id), isNotEmpty);
    });

    test('a literal hit outranks a synonym hit for the same token', () {
      // «رنگ» is a keyword on the widget row and only a synonym of «تم» on the
      // appearance row: the row that spells it out must come first.
      final ids = searchSettings('رنگ').map((e) => e.id).toList();
      expect(ids, containsAll(<String>['main.widgets', 'main.appearance']));
      expect(ids.indexOf('main.widgets'), lessThan(ids.indexOf('main.appearance')));
    });

    test('repeated searches return the same order (cached text)', () {
      final first = searchSettings('اذان').map((e) => e.id).toList();
      final second = searchSettings('اذان').map((e) => e.id).toList();
      expect(second, first);
    });
  });

  group('query tokens', () {
    test('trailing punctuation does not kill the match', () {
      // Mobile keyboards and autocorrect add «؟», «،», «.», «!».
      for (final query in ['اذان؟', 'اذان،', 'اذان.', 'اذان!', '(اذان)']) {
        expect(searchSettings(query).map((e) => e.id),
            searchSettings('اذان').map((e) => e.id),
            reason: query);
      }
    });

    test('filler words are dropped, not required', () {
      // A question typed in full must still reach the row.
      final asked = searchSettings('چطور اذان را خاموش کنم؟').map((e) => e.id);
      expect(asked, contains('prayer.adhan.fajr'));
      expect(settingsSearchTokens('چطور اذان را خاموش کنم'),
          const ['اذان', 'خاموش']);
    });

    test('a query of only filler words still searches them literally', () {
      expect(settingsSearchTokens('تنظیمات'), const ['تنظیمات']);
      expect(searchSettings('تنظیمات'), isNotEmpty);
    });

    test('no stop word is also a label word', () {
      // Dropping a word that appears in labels would make the query less
      // specific than the user was.
      const labels = <String>[
        'روشن', 'تاریک', 'زمان', 'اندازه', 'نمایش', 'امتیاز', 'نسخه',
        'موقعیت', 'مکان', 'صدا', 'فونت', 'تم', 'ویجت', 'نماز', 'اذان',
      ];
      for (final label in labels) {
        expect(settingsSearchStopWords, isNot(contains(label)), reason: label);
      }
    });
  });
}
