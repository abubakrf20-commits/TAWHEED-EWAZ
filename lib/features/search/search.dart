import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/search/presentation/screens/search_screen.dart';

export 'package:tawheeed/features/search/presentation/screens/search_screen.dart';

/// Opens the global search overlay. Quran results switch to the Quran shell tab
/// and jump to the matching page (highlighting the verse).
void openGlobalSearch(BuildContext context, WidgetRef ref) {
  showSearch(
    context: context,
    delegate: GlobalSearchDelegate(
      ref,
      onQuranNavigate: (page, {int? highlightSurah, int? highlightVerse}) {
        ref.read(quranNavRequestProvider).value = QuranNavRequest(
          page,
          surah: highlightSurah,
          verse: highlightVerse,
        );
        ref.read(shellTabIndexProvider.notifier).setIndex(1);
      },
      onMoreNavigate: () {
        // «بیشتر» is the last shell tab (index 5); its own field is the search
        // that reads inside the sections this overlay does not cover.
        ref.read(shellTabIndexProvider.notifier).setIndex(5);
      },
    ),
  );
}
