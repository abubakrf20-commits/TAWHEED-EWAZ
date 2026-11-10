import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/app/router/app_router.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';

/// The registry is the page's only list: if an entry is missing here it is
/// missing from the UI, and if a destination is wrong here the tile throws on
/// tap. Both are checked against the real router rather than a copy.
void main() {
  final routeItems = kMoreItems
      .where((i) => i.kind == MoreKind.route || i.kind == MoreKind.lockedRoute)
      .toList();

  group('registry integrity', () {
    test('ids are unique and every item is displayable', () {
      final ids = kMoreItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
      for (final item in kMoreItems) {
        expect(item.id, isNotEmpty);
        expect(item.title.trim(), isNotEmpty, reason: 'blank title');
        expect(item.destination.trim(), isNotEmpty,
            reason: 'blank destination');
        // 0x0 iconData == IconData(0) — an unset icon renders as a box.
        expect(item.icon.codePoint, isNonZero,
            reason: '${item.id} has no icon');
      }
    });

    test('no two items show the same title', () {
      final titles = kMoreItems.map((i) => normalizeMoreText(i.title)).toList();
      expect(titles.toSet().length, titles.length);
    });

    test('every item belongs to a group and no group is empty', () {
      final grouped = {for (final g in MoreGroup.values) g: moreItemsIn(g, '')};
      for (final entry in grouped.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key.name} is empty');
      }
      expect(grouped.values.map((l) => l.length).fold(0, (a, b) => a + b),
          kMoreItems.length,
          reason: 'every item is counted exactly once');
    });

    test('the section split is the one the user asked for', () {
      // Four to a row, and «قرآن و ادعیه» merged into «عبادات و مناسک»: the
      // worship grid carries the rites, the Qur'an/dua family, ماه و منازل،
      // میراث and — since the worship-move line — صله رحم، دفتر مربی قرآن و
      // کفاره و فدیه، و دفتر عادت کودک — 18 / 12 / 3 / 15 / 5. Tools stay the
      // personal-data tail (the shop ledger, the stage-1 pair خودرو + خانه,
      // and the finance books — the قضایار tracker was retired by its removal
      // commit). App is the row list.
      expect(kMoreItems.length, 53);
      expect(moreItemsIn(MoreGroup.worship, '').length, 18);
      expect(moreItemsIn(MoreGroup.hadith, '').length, 12);
      expect(moreItemsIn(MoreGroup.audio, '').length, 3);
      expect(moreItemsIn(MoreGroup.tools, '').length, 15);
      expect(moreItemsIn(MoreGroup.app, '').length, 5);
    });

    test('the Qur\'an and supplication items read inside the worship grid', () {
      // User decision: the merged section is one grid, not two cards.
      for (final id in [
        'khatm',
        'hifz',
        'mushaf-hafiz',
        'dua',
        'duas',
        'ruqyah',
      ]) {
        expect(kMoreItems.firstWhere((i) => i.id == id).group,
            MoreGroup.worship,
            reason: '$id must stay in عبادات و مناسک');
      }
      // …and the tools the user moved across with them — the kids habit
      // ledger last (2026-11-09): it counts the day's prayers and deeds.
      for (final id in ['moon', 'inheritance', 'kids-habits']) {
        expect(kMoreItems.firstWhere((i) => i.id == id).group,
            MoreGroup.worship,
            reason: '$id must stay in عبادات و مناسک');
      }
      expect(
          kMoreItems.where((i) => i.group == MoreGroup.tools).map((i) => i.id),
          isNot(contains('moon')));
    });

    test('every personal tool has exactly one door, in «ابزارها و پیشرفت»', () {
      // User decision (2026-11-05): the personal tools — the stage-1 care pair,
      // the stage-2 finance books and the stage-3 family/faith three — are
      // reachable from this section and nowhere else. «خودرو» and «خانه» had
      // routes but no tile at all; the others were listed here already.
      const owned = ['car', 'home-care'];
      for (final id in [
        ...owned,
        'finance',
        'savings',
        'shop-ledger',
      ]) {
        final item = kMoreItems.firstWhere((i) => i.id == id);
        expect(item.group, MoreGroup.tools, reason: '$id must sit in tools');
      }
      // The care pair keeps its `VaultGuard` (the section's lock) in the router,
      // so the More tile must be a plain route — not a second, weaker door.
      for (final id in owned) {
        final item = kMoreItems.firstWhere((i) => i.id == id);
        expect(item.kind, MoreKind.route, reason: '$id is guarded by the router');
      }
    });

    test('the worship grid opens with qibla, moon and طهارت', () {
      // Registry order is display order, and in RTL the first entry sits at
      // the far right: قبله، ماه و منازل، طهارت، then the rest of the rites.
      final worship = moreItemsIn(MoreGroup.worship, '').map((i) => i.id);
      expect(
          worship.take(8),
          orderedEquals([
            'qibla',
            'moon',
            'purification',
            'prayer',
            'fasting',
            'zakat',
            'hajj-umrah',
            'inheritance',
          ]));
    });

    test('every iconScale stays in the tuned 0.9–1.1 optical range', () {
      for (final item in kMoreItems) {
        expect(item.iconScale, inInclusiveRange(0.9, 1.1),
            reason: '${item.id} iconScale ${item.iconScale}');
      }
    });

    test('no item is labeled exactly like a section header', () {
      // The layout tests assert each group title shows once; a tile repeating
      // it would break them and confuse the search results.
      for (final item in kMoreItems) {
        expect(item.title, isNot(item.group.title), reason: item.id);
      }
    });

    test('only locked items carry a lock code', () {
      for (final item in kMoreItems) {
        if (item.kind == MoreKind.lockedRoute) {
          expect(item.lockCode, isNotNull, reason: '${item.id} unopenable');
        } else {
          expect(item.lockCode, isNull);
          expect(item.isLocked, isFalse);
        }
      }
    });

    test('the yaqeen lock code is build-defined, not a shipped secret',
        () {
      // U6-01: debug/test builds keep the legacy fallback so local flows and
      // the More-screen dialog test keep working. In release the code comes
      // from --dart-define=YAQEEN_LOCK_CODE; without it yaqeenLockCode is ''
      // and every entry is rejected (verified by `strings` on the release
      // APK, which must not contain the fallback literal).
      expect(yaqeenLockCode, isNotEmpty);
      final yaqeen = kMoreItems.firstWhere((i) => i.id == 'yaqeen');
      expect(yaqeen.lockCode, yaqeenLockCode);
    });

    test('every route destination resolves in the real app router', () {
      expect(routeItems, isNotEmpty);
      final router = buildAppRouter();
      final unresolved = <String>[
        for (final item in routeItems)
          if (router.configuration
                  .findMatch(Uri.parse(item.destination))
                  .error !=
              null)
            '${item.id} → ${item.destination}',
      ];
      expect(unresolved, isEmpty);
    });

    test('web items are https urls and audio items a category id', () {
      for (final item in kMoreItems) {
        switch (item.kind) {
          case MoreKind.web:
            expect(item.destination, startsWith('https://'));
          case MoreKind.audioCategory:
            expect(item.destination, isNot(contains('/')));
            expect(item.destination, isNot(contains('?')));
          default:
            break;
        }
      }
    });

    test('the sections removed by user decision never come back', () {
      // مصحف توحید / تلاوت‌یار / آمارهٔ پیشرفت were deleted from the app; the
      // registry must not re-open a door to a feature that no longer exists.
      const forbidden = ['مصحف توحید', 'تلاوت‌یار', 'ملقّن', 'آمارهٔ پیشرفت'];
      for (final word in forbidden) {
        expect(kMoreItems.any((i) => i.title.contains(word)), isFalse,
            reason: '$word must stay out of «بیشتر»');
        for (final group in MoreGroup.values) {
          expect(moreItemsIn(group, normalizeMoreText(word)), isEmpty,
              reason: '$word must stay out of ${group.name}');
        }
      }
      // The names that must remain reachable, under either spelling.
      for (final kept in ['مصحف حافظ', 'دعا', 'تنظیمات']) {
        expect(findItem(kept), isNotNull, reason: '$kept is gone');
      }
    });

    test('the app utilities are on the page, not hidden behind settings', () {
      // User decision: پشتیبان‌گیری، پیام‌های مدیریت، ارسال پیشنهاد and درباره
      // must be tappable directly from «بیشتر» — they left the settings page
      // (2026-10-17) so this is the only door.
      expect(
          moreItemsIn(MoreGroup.app, ''),
          containsAll(<String>[
            'settings',
            'backup',
            'announcements',
            'suggestions',
            'about',
          ].map((id) => kMoreItems.firstWhere((i) => i.id == id))));
      for (final id in ['backup', 'announcements', 'suggestions', 'about']) {
        final item = kMoreItems.firstWhere((i) => i.id == id);
        expect(item.kind, MoreKind.route);
        expect(item.subtitle, isNotNull, reason: '$id needs a caption');
      }
    });
  });

  group('search normalization', () {
    test('ZWNJ and spaces are both tolerated', () {
      expect(findItem('قبله‌نما'), isNotNull);
      expect(findItem('قبله نما'), isNotNull);
      expect(findItem('قبلهنما'), isNotNull);
      expect(findItem('هدفگذاری'), isNotNull);
    });

    test('Arabic letter variants find the Persian titles', () {
      // Arabic ي/ك against the Persian ی/ک in the registry.
      expect(findItem('اناشيد'), isNotNull); // اناشید اسلامی, with Arabic yeh
      expect(findItem('محرم'), isNull); // sanity: not a section name
      expect(findItem('حصن المسلم'), isNotNull);
      expect(normalizeMoreText('ي'), normalizeMoreText('ی'));
      expect(normalizeMoreText('ك'), normalizeMoreText('ک'));
    });

    test('harakat and alef variants fold', () {
      expect(findItem('حِصنَ المُسلِم'), isNotNull);
      expect(findItem('قرآن'), isNotNull); // in the ختم قرآن keywords
      expect(normalizeMoreText('آ'), normalizeMoreText('ا'));
    });

    test('Persian, Arabic-Indic and Latin digits normalize alike', () {
      expect(normalizeMoreText('۱۲'), '12');
      expect(normalizeMoreText('١٢'), '12');
      expect(normalizeMoreText('12'), '12');
    });

    test('partial words and keywords match; a foreign string matches nothing',
        () {
      expect(findItem('نماز'), isNotNull);
      expect(findItem('نما'), isNotNull); // partial of نماز / قبله‌نما
      expect(findItem('اطلاعیه'), isNotNull); // پیام‌های مدیریت keyword
      expect(findItem('namaz'), isNotNull); // latin keyword
      expect(findItem('rowzeh'), isNotNull); // keyword of روزه
      expect(findItem('zzz-not-a-section-zzz'), isNull);
    });

    test('an empty query keeps every group intact', () {
      for (final group in MoreGroup.values) {
        expect(moreItemsIn(group, ''), isNotEmpty);
      }
      expect(moreItemMatches(kMoreItems.first, ''), isTrue);
    });

    test('filtering narrows without reordering the registry', () {
      final all = moreItemsIn(MoreGroup.tools, '');
      final some = moreItemsIn(MoreGroup.tools, normalizeMoreText('یاد'));
      expect(some.length, lessThan(all.length));
      expect(some.length, greaterThan(1)); // یادداشت‌ها + یادآورها
      final order = some.map(all.indexOf).toList();
      expect(order, order.toList()..sort(), reason: 'registry order kept');
    });
  });
}

/// The first item the page would show for [rawQuery], or null.
MoreItem? findItem(String rawQuery) {
  final query = normalizeMoreText(rawQuery.trim());
  for (final group in MoreGroup.values) {
    final matches = moreItemsIn(group, query);
    if (matches.isNotEmpty) return matches.first;
  }
  return null;
}
