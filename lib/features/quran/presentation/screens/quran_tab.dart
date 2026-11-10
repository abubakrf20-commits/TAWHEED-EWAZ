import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/features/quran/mushaf/quran_mushaf_view.dart';

/// Quran tab — hosts the mushaf reader (server-hosted KFQC pages, talaawah
/// playback via mp3quran, translations/tafsirs from the bundled content).
class QuranTab extends ConsumerStatefulWidget {
  const QuranTab({super.key});

  @override
  ConsumerState<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends ConsumerState<QuranTab> {
  final GlobalKey<QuranMushafViewState> _mushafKey =
      GlobalKey<QuranMushafViewState>();

  late ValueNotifier<QuranNavRequest?> _navRequests;

  @override
  void initState() {
    super.initState();
    _navRequests = ref.read(quranNavRequestProvider);
    _navRequests.addListener(_consumeNavRequest);
    // The reader has public endpoint fallbacks and can render immediately;
    // configuration loading must not hold the Quran tab behind a spinner.
    unawaited(QuranApiConfig.load());
    // The search can push a request *before* this tab was ever built (the
    // shell builds tabs lazily). Consume any pending value right away — and
    // again after the first frame, once the mushaf state is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumeNavRequest();
    });
  }

  @override
  void dispose() {
    _navRequests.removeListener(_consumeNavRequest);
    super.dispose();
  }

  /// Global search (any tab → verse match) pushes a page request here.
  void _consumeNavRequest({int retriesLeft = 30}) {
    final req = _navRequests.value;
    if (req == null) return;
    final state = _mushafKey.currentState;
    if (state == null) {
      // Tab (or mushaf) not built yet — retry after the next frame instead
      // of dropping the request. Bounded so a permanently-missing mushaf
      // doesn't spin forever.
      if (retriesLeft <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _consumeNavRequest(retriesLeft: retriesLeft - 1);
      });
      return;
    }
    // Deliver before clearing: clearing first meant a request the reader
    // could not act on was already gone. The clear stays guarded by identity
    // so it can only drop the request it just delivered — a newer one that
    // arrived meanwhile (same verse tapped twice; ValueNotifier suppresses
    // equal values, so it arrives as a fresh object) is never swallowed.
    state.goToPage(
      req.page,
      surah: req.surah,
      verse: req.verse,
      previewOnly: req.previewOnly,
    );
    if (identical(_navRequests.value, req)) _navRequests.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return QuranMushafView(key: _mushafKey);
  }
}
