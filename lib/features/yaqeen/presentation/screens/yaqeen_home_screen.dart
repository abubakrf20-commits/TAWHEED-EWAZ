import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_gamification.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_level_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_lesson_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/widgets/yaqeen_lesson_tile.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenHomeScreen — «یقین» (تثبیت اعتقادی و پاسخ به شبهات)
///
/// نقشهٔ محتوایی از yaqeen.docx: 4 مسیر یادگیری، 22 درس گام‌به‌گام.
/// فلسفه: «بهترین دفاع، هجوم است» — 80٪ تثبیت یقین، 20٪ رد شبهات.
/// ═══════════════════════════════════════════════════════════════

class YaqeenHomeScreen extends StatefulWidget {
  const YaqeenHomeScreen({super.key});

  @override
  State<YaqeenHomeScreen> createState() => _YaqeenHomeScreenState();
}

class _YaqeenHomeScreenState extends State<YaqeenHomeScreen> {
  static const Color accent = TopicHues.yaqeen;

  final YaqeenRepository _repo = YaqeenRepository();
  final YaqeenProgress _progress = YaqeenProgress();
  final TextEditingController _searchCtrl = TextEditingController();

  List<YaqeenLevel>? _levels;
  Set<String> _readIds = {};
  Map<String, int> _quizScores = {};
  YaqeenSearchHit? _daily;

  /// The thrown object, not its text: the panel renders it in debug builds
  /// only, so a reader never meets a table name where an explanation belongs.
  Object? _error;

  // search
  bool _searching = false;
  List<YaqeenSearchHit>? _results;

  /// The search threw. Without it `_searching` stayed true and `_results` null,
  /// so the spinner below never resolved and only leaving the screen cleared
  /// it.
  bool _searchFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // A retry must clear the previous failure before it starts, or the panel
    // stays on screen on top of the loading state it was replaced by.
    if (_error != null) setState(() => _error = null);
    try {
      final levels = await _repo.levels();
      final read = await _progress.readIds();
      final quiz = await _progress.quizScores();
      final all = await _repo.allLessons();
      YaqeenSearchHit? daily;
      if (all.isNotEmpty) {
        // «درس امروز» = ادامه از جایی که متوقف شده (lastLesson)، وگرنه اولین نخوانده، وگرنه روزانهٔ چرخشی
        final lastId = await _progress.lastLessonId();
        if (lastId != null) {
          try {
            daily = all.firstWhere((h) => h.lesson.id == lastId);
          } catch (_) {
            AppLogger.warning('yaqeen_home_screen', 'operation failed');
          }
        }
        // `read` — not `_readIds`: the field still holds the previous load's
        // set until setState below, so reading it here would offer the lesson
        // the reader has just finished as the next unread one.
        daily ??= all.cast<YaqeenSearchHit?>().firstWhere(
              (h) => !read.contains(h!.lesson.id),
              orElse: () => null,
            );
        daily ??= all[YaqeenGamification.dailyLessonIndex(DateTime.now(),
            totalLessons: all.length)];
      }
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _readIds = read;
        _quizScores = quiz;
        _daily = daily;
      });
    } catch (e) {
      AppLogger.warning('yaqeen_home_screen', 'error: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _onSearchChanged() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _results = null;
          _searching = false;
          _searchFailed = false;
        });
      }
      return;
    }
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final hits = await _repo.search(q);
      if (!mounted) return;
      setState(() {
        _results = hits;
        _searching = false;
      });
    } catch (e) {
      AppLogger.warning('yaqeen', 'search failed: $e');
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  int get _totalLessons =>
      _levels == null ? 0 : _levels!.fold(0, (n, lv) => n + lv.lessons.length);

  int get _correctAnswers => _quizScores.values.fold(0, (n, v) => n + v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'یقین'),
      body: _error != null
          ? FailureView(
              id: 'yaqeen_levels_load',
              title: 'درس‌های یقین باز نشدند',
              detail: 'پیشرفت خوانده‌شدهٔ شما پاک نشده است؛ فقط فهرست درس‌ها '
                  'خوانده نشد.',
              onRetry: _load,
              layout: FailureLayout.page,
              error: _error,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 8, DsSpacing.page, 40),
              children: [
                _buildHero(context),
                const SizedBox(height: 16),
                _buildProgressCard(context),
                const SizedBox(height: 16),
                if (_daily != null) ...[
                  _buildDailyCard(context, _daily!),
                  const SizedBox(height: 16),
                ],
                _buildSearchField(context),
                const SizedBox(height: 16),
                if (_searchCtrl.text.trim().isNotEmpty)
                  _buildSearchResults(context)
                else ...[
                  if (_levels == null)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    for (var i = 0; i < _levels!.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildLevelCard(context, i, _levels![i]),
                    ],
                ],
                const SizedBox(height: 20),
                _buildBadgesCard(context),
              ],
            ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF37474F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تثبیت ایمان، پیش از رسیدن شبهه',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppTheme.scaledFontSize(context, 17),
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '«وَاعْتَصِمُوا بِحَبْلِ اللَّهِ جَمِيعًا وَلَا تَفَرَّقُوا»',
            style: TextStyle(
                color: Colors.white,
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'آل عمران: 103 — «و همگی به ریسمان خدا چنگ زنید و پراکنده نشوید»',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: AppTheme.scaledFontSize(context, 12)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'بهترین دفاع، هجوم است؛ با فطرت، عقل و وحی به یقین برس.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: AppTheme.scaledFontSize(context, 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress ─────────────────────────────────────────────────

  Widget _buildProgressCard(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final total = _totalLessons;
    final done = _readIds.where((id) {
      // only count ids that belong to the curriculum
      if (_levels == null) return false;
      return _levels!.any((lv) => lv.lessons.any((l) => l.id == id));
    }).length;
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پیشرفت شما: $done از $total درس',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.scaledFontSize(context, 14)),
                ),
              ),
              Text(
                '$_totalLessons درس',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                '${YaqeenGamification.points(done, _correctAnswers)} امتیاز',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 12)),
              ),
              const Spacer(),
              Text(
                'سطح: ${YaqeenGamification.userLevel(done, totalLessons: total)}',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Daily lesson ─────────────────────────────────────────────

  Widget _buildDailyCard(BuildContext context, YaqeenSearchHit hit) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final done = _readIds.contains(hit.lesson.id);
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openLesson(context, hit.level, hit.lesson),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline,
                            size: 15, color: accent),
                        const SizedBox(width: 5),
                        Text('ادامه مطالعه',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: accent)),
                        if (done) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, color: success, size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(hit.lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(hit.level.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Badges ───────────────────────────────────────────────────

  Widget _buildBadgesCard(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final badges = YaqeenGamification.badges(_readIds, _quizScores);
    final earned = badges.where((b) => b.earned).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('نشان‌ها: $earned از ${badges.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 13))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in badges) _BadgeChip(badge: b),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Search ───────────────────────────────────────────────────

  Widget _buildSearchField(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'جستجو در درس‌ها و شبهات…',
        prefixIcon: const Icon(Icons.search, color: accent),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'پاک کردن جستجو',
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _results = null);
                },
              ),
        filled: true,
        fillColor: t.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    if (_searchFailed) {
      return FailureView(
        id: 'yaqeen_search',
        title: 'جست‌وجو انجام نشد',
        detail: 'نتیجه‌ای که می‌بینید ناقص است، نه اینکه چیزی پیدا نشده باشد.',
        onRetry: _onSearchChanged,
        layout: FailureLayout.page,
        icon: Icons.cloud_off,
      );
    }
    if (_searching && _results == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final results = _results ?? const <YaqeenSearchHit>[];
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child:
              Text('نتیجه‌ای یافت نشد', style: TextStyle(color: t.textMuted)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text('${results.length} نتیجه',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        for (final hit in results)
          YaqeenLessonTile(
            lesson: hit.lesson,
            read: _readIds.contains(hit.lesson.id),
            subtitle: '${hit.level.title} · ${hit.lesson.sections.length} بخش',
            onTap: () => _openLesson(context, hit.level, hit.lesson),
          ),
      ],
    );
  }

  // ─── Levels ───────────────────────────────────────────────────

  Widget _buildLevelCard(BuildContext context, int index, YaqeenLevel level) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final lessons = level.lessons;
    final done = lessons.where((l) => _readIds.contains(l.id)).length;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => YaqeenLevelScreen(level: level),
          ));
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 17),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    AppTheme.scaledFontSize(context, 15))),
                        const SizedBox(height: 2),
                        Text(level.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: t.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: accent),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${lessons.length} درس',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted)),
                  const Spacer(),
                  Text(
                    done == lessons.length
                        ? '✓ تکمیل شده'
                        : '$done/${lessons.length}',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.bold,
                        color: done == lessons.length ? success : accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: lessons.isEmpty ? 0 : done / lessons.length,
                  minHeight: 5,
                  backgroundColor: accent.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLesson(
      BuildContext context, YaqeenLevel level, YaqeenLesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YaqeenLessonScreen(
        level: level,
        initialLessonId: lesson.id,
      ),
    ));
    _load();
  }
}

/// چیپ نشان — روشن وقتی کسب شده، خاکستری با قفل وقتی نه.
class _BadgeChip extends StatelessWidget {
  final YaqeenBadge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.yaqeen;
    final earned = badge.earned;
    final color = earned ? accent : t.textMuted;
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: earned ? accent.withValues(alpha: 0.10) : t.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: earned
                ? accent.withValues(alpha: 0.4)
                : t.divider.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(earned ? badge.icon : Icons.lock_outline,
                size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              badge.title,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: earned ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
