import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/home/presentation/widgets/quick_actions.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';

/// The home quick-action tiles mirror the More registry: icon, title,
/// accent, glyph scale and route come from [kMoreItems] through
/// [QuickActions.quickToMoreIds], so a section keeps one definition
/// everywhere. Tab shortcuts have no registry counterpart and stay local.
///
/// Quick ids are also the persisted shape ([quickActionsProvider]) — they
/// never change, even where they differ from the registry ids.
void main() {
  test('every mapped registry entry exists and is a plain route', () {
    expect(QuickActions.quickToMoreIds, isNotEmpty);
    for (final entry in QuickActions.quickToMoreIds.entries) {
      final matches =
          kMoreItems.where((m) => m.id == entry.value).toList();
      expect(matches, hasLength(1),
          reason: '${entry.key} maps to missing registry id ${entry.value}');
      final item = matches.single;
      expect(item.kind, MoreKind.route,
          reason: '${entry.value} is not a plain route tile');
      expect(item.destination.startsWith('/'), isTrue,
          reason: '${entry.value} must carry a route path');
    }
  });

  test('persisted quick ids stay stable', () {
    // Renaming a key silently drops every user's saved tile with that id
    // (unknown ids are filtered out on load).
    expect(
      QuickActions.quickToMoreIds.keys.toSet(),
      {
        'qibla',
        'purification',
        'prayer',
        'zakat',
        'hajj_umrah',
        'fasting',
        'khatm',
        'inheritance',
        'hadith_books',
        'duas',
        'ketabkhaneh',
        'sciences',
        'study',
        'tasks',
        'expenses',
        'notes',
        'reminders',
        'period',
        'calculator',
        'pomodoro',
        'dangi',
      },
    );
  });
}
