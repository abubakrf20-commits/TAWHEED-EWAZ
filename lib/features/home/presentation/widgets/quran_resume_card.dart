import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «ادامهٔ مطالعه» — the reader already persists `quran_last_page`; this card
/// closes the loop between Home and the mushaf (upgrade wave-1 #3, user
/// request 2026-11-05: the upgrade plan was approved in order).
///
/// Hidden entirely until the reader has opened the mushaf at least once — a
/// fresh install has no «continue» to offer, and a card that says «صفحهٔ ۱»
/// would be inventing a reading history. The surah name is a courtesy: if the
/// page map is unavailable (startup load still running, corrupt asset) the
/// card still works with the page number alone, because the page is the thing
/// the reader asked to resume.
class QuranResumeCard extends ConsumerStatefulWidget {
  const QuranResumeCard({super.key});

  @override
  ConsumerState<QuranResumeCard> createState() => _QuranResumeCardState();
}

class _QuranResumeCardState extends ConsumerState<QuranResumeCard> {
  /// The SAME key `quran_mushaf_view.dart` writes on every page settle —
  /// duplicating a second key would let the two drift.
  static const String _lastPageKey = 'quran_last_page';

  /// The home shortcut's Quran-tab accent (quick_actions.dart): one identity
  /// colour for «this goes to the Quran tab», not a new hue.
  static const Color _quranAccent = Color(0xFFB8860B);

  int? _page;
  String? _surahName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_lastPageKey)) return;
    final page = (prefs.getInt(_lastPageKey) ?? 1).clamp(1, 604);
    String? name;
    try {
      await loadQuranData();
      final data = getPageData(page);
      final surah = (data.first['surah'] as int?) ?? 0;
      if (surah >= 1 && surah <= 114) name = getSurahNameArabic(surah);
    } catch (e) {
      AppLogger.warning('quran_resume_card', 'surah name unavailable: $e');
    }
    if (!mounted) return;
    setState(() {
      _page = page;
      _surahName = name;
    });
  }

  /// Same channel the global search uses: a [QuranNavRequest] the Quran tab
  /// consumes, then the shell switches to that tab (index 1). Pushing the
  /// request BEFORE the switch is what makes the jump land even on a cold
  /// tab — the reader retries delivery until its state exists.
  void _open() {
    final page = _page;
    if (page == null) return;
    ref.read(quranNavRequestProvider).value = QuranNavRequest(page);
    ref.read(shellTabIndexProvider.notifier).setIndex(1);
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) return const SizedBox.shrink();
    final t = TimeThemeKit.of(context).palette;
    // ASCII digits, like every other kit row (`normalizeDigits` folds
    // Persian/Arabic input TO ASCII — it does not produce Persian output).
    final pageText =
        'صفحهٔ ${NumberFormat.normalizeDigits('$page')} از 604';
    final subtitle = _surahName == null
        ? pageText
        : 'سورهٔ $_surahName · $pageText';
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const DuotoneIconTile(accent: _quranAccent, icon: Icons.menu_book),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ادامهٔ مطالعه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left, size: 20, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
