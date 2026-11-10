import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_quiz_data.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_quiz_screen.dart';

/// YaqeenLessonScreen — خوانشگر حرفه‌ای درس «یقین»
///
/// • هر شبهه در کادر مجزا با عنوان، نشان عدد و بخش‌های شرح/پاسخ/نتیجه
/// • بدون نمایش «دقیقه مطالعه»
/// • کارت‌های گفتار عادی با طراحی مینیمال و خوانا
class YaqeenLessonScreen extends StatefulWidget {
  final YaqeenLevel level;
  final String initialLessonId;

  const YaqeenLessonScreen({
    super.key,
    required this.level,
    required this.initialLessonId,
  });

  @override
  State<YaqeenLessonScreen> createState() => _YaqeenLessonScreenState();
}

class _YaqeenLessonScreenState extends State<YaqeenLessonScreen> {
  static const Color accent = TopicHues.yaqeen;

  final YaqeenProgress _progress = YaqeenProgress();
  final ScrollController _scrollCtrl = ScrollController();

  late final List<YaqeenLesson> _ordered;
  late int _index;
  bool _read = false;
  double _fontSize = YaqeenProgress.defaultFontSize;
  Set<int> _expandedDoubts = {0};

  @override
  void initState() {
    super.initState();
    _ordered = widget.level.lessons;
    _index = _ordered.indexWhere((l) => l.id == widget.initialLessonId);
    if (_index < 0) _index = 0;
    _loadState();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final lesson = _ordered[_index];
    final read = await _progress.isRead(lesson.id);
    final size = await _progress.fontSize();
    await _progress.setLastLesson(lesson.id);
    if (!mounted) return;
    setState(() {
      _read = read;
      _fontSize = size;
      // بسته‌بندی: فقط اولین شبهه باز، بقیه بسته تا صفحه خلوت باشد
      _expandedDoubts = {0};
    });
  }

  void _toggleDoubt(int idx) {
    setState(() {
      if (_expandedDoubts.contains(idx)) {
        _expandedDoubts.remove(idx);
      } else {
        _expandedDoubts.add(idx);
      }
    });
  }

  void _toggleAllDoubts(int count) {
    setState(() {
      if (_expandedDoubts.length == count) {
        _expandedDoubts = {};
      } else {
        _expandedDoubts = {for (int i = 0; i < count; i++) i};
      }
    });
  }

  YaqeenLesson get _lesson => _ordered[_index];

  Future<void> _toggleRead() async {
    final newValue = !_read;
    await _progress.setRead(_lesson.id, read: newValue);
    if (!mounted) return;
    setState(() => _read = newValue);
  }

  Future<void> _changeFont(double delta) async {
    final next = (_fontSize + delta)
        .clamp(YaqeenProgress.minFontSize, YaqeenProgress.maxFontSize);
    await _progress.setFontSize(next);
    if (!mounted) return;
    setState(() => _fontSize = next);
  }

  void _goTo(int newIndex) {
    if (newIndex < 0 || newIndex >= _ordered.length) return;
    if (newIndex > _index && !_read) {
      _progress.setRead(_lesson.id, read: true);
    }
    setState(() {
      _index = newIndex;
      _expandedDoubts = {0};
    });
    _loadState();
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final lesson = _lesson;
    final quiz = YaqeenQuizData.forLesson(lesson.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'درس ${_index + 1} از ${_ordered.length}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'کوچک‌تر',
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () => _changeFont(-1.5),
          ),
          IconButton(
            tooltip: 'بزرگ‌تر',
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () => _changeFont(1.5),
          ),
          if (quiz.isNotEmpty)
            IconButton(
              tooltip: 'آزمون — ${quiz.length} سؤال',
              icon: Badge(
                label: Text('${quiz.length}',
                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 10))),
                backgroundColor: accent,
                child: const Icon(Icons.quiz_outlined, size: 21),
              ),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      YaqeenQuizScreen(lesson: _lesson, questions: quiz),
                ));
                _loadState();
              },
            ),
          IconButton(
            tooltip: _read ? 'خوانده شد' : 'علامت‌گذاری',
            icon: Icon(
              _read ? Icons.check_circle : Icons.check_circle_outline,
              color: _read ? success : t.textMuted,
            ),
            onPressed: _toggleRead,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 10, DsSpacing.page, 24),
              children: [
                _buildHeader(context, lesson, quiz.length),
                const SizedBox(height: 16),
                // ── بسته‌بندی شبهات ──
                Builder(builder: (context) {
                  final doubts = [
                    for (final s in lesson.sections)
                      if (s.isDoubt) s
                  ];
                  // تقسیم ساده: بخش‌های غیرشبههٔ ابتدای درس جدا، شبهات وسط، بقیه انتها
                  // فعلاً همهٔ شبهات را یک‌جا بسته‌بندی می‌کنیم تا صفحه طولانی و خسته‌کننده نباشد
                  if (doubts.length > 1) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in lesson.sections.where((x) =>
                            !x.isDoubt &&
                            (x.title == null ||
                                !x.title!.startsWith('شبهه')))) ...[
                          _SectionCard(section: s, fontSize: _fontSize),
                          const SizedBox(height: 14),
                        ],
                        _DoubtsPackage(
                          doubts: doubts,
                          fontSize: _fontSize,
                          expandedIndices: _expandedDoubts,
                          onToggle: _toggleDoubt,
                          onToggleAll: _toggleAllDoubts,
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  }
                  // درس بدون بسته‌بندی (1 شبهه یا بدون شبهه)
                  return Column(
                    children: [
                      for (final section in lesson.sections) ...[
                        if (section.isDoubt)
                          _DoubtCard(
                            section: section,
                            fontSize: _fontSize,
                            expanded: _expandedDoubts
                                .contains(lesson.sections.indexOf(section)),
                            onToggle: () =>
                                _toggleDoubt(lesson.sections.indexOf(section)),
                          )
                        else
                          _SectionCard(section: section, fontSize: _fontSize),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                }),
                if (quiz.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _QuizCTA(lesson: lesson, questions: quiz),
                ],
              ],
            ),
          ),
          _buildNavBar(context),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, YaqeenLesson lesson, int quizCount) {
    final doubtsCount = lesson.sections.where((s) => s.isDoubt).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: TopicHues.yaqeen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_stories_outlined,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 5),
                    Text(widget.level.title,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: AppTheme.scaledFontSize(context, 11))),
                  ],
                ),
              ),
              const Spacer(),
              if (_read)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('خوانده شد',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lesson.title,
            style: TextStyle(
                color: Colors.white,
                fontSize: AppTheme.scaledFontSize(context, 19),
                fontWeight: FontWeight.bold,
                height: 1.5),
          ),
          if (lesson.excerpt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lesson.excerpt,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  height: 1.7),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderChip(
                  icon: Icons.article_outlined,
                  label: '${lesson.sections.length} بخش'),
              if (doubtsCount > 0) ...[
                const SizedBox(width: 8),
                _HeaderChip(
                    icon: Icons.help_outline, label: '$doubtsCount شبهه'),
              ],
              if (quizCount > 0) ...[
                const SizedBox(width: 8),
                _HeaderChip(
                    icon: Icons.quiz_outlined, label: '$quizCount سؤال'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final hasPrev = _index > 0;
    final hasNext = _index < _ordered.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(
            top: BorderSide(color: t.divider.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(0, 44),
              ),
              onPressed: hasPrev ? () => _goTo(_index - 1) : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text('درس قبلی', style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(0, 44),
              ),
              onPressed: hasNext
                  ? () {
                      if (!_read) _toggleRead();
                      _goTo(_index + 1);
                    }
                  : () {
                      if (!_read) _toggleRead();
                      Navigator.of(context).pop();
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(hasNext ? 'درس بعدی' : 'پایان مسیر ✓',
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13))),
                  const SizedBox(width: 8),
                  Icon(hasNext ? Icons.arrow_forward : Icons.task_alt,
                      size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// چیپ کوچک در هدر درس
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// کارت گفتار عادی (غیر شبهه)
class _SectionCard extends StatelessWidget {
  final YaqeenSection section;
  final double fontSize;
  const _SectionCard({required this.section, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final body = <Widget>[];
    if (section.title != null) {
      body.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                  color: _YaqeenLessonScreenState.accent,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                section.title!,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 15), height: 1.6),
              ),
            ),
          ],
        ),
      );
      body.add(const SizedBox(height: 12));
    }
    for (final p in section.paragraphs) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SelectableText(
            p,
            style: TextStyle(
                fontSize: fontSize,
                height: 1.95,
                color: t.textPrimary),
          ),
        ),
      );
    }
    if (section.title == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: body),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: t.divider.withValues(alpha: 0.18)),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
    );
  }
}

/// کارت حرفه‌ای شبهه — هر شبهه در کادر مجزا (تاشو)
class _DoubtCard extends StatelessWidget {
  final YaqeenSection section;
  final double fontSize;
  final bool expanded;
  final VoidCallback? onToggle;
  const _DoubtCard(
      {required this.section,
      required this.fontSize,
      this.expanded = true,
      this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final doubt = section.doubt;
    final number = doubt?.number ?? 0;
    final question = (doubt?.question.isNotEmpty == true
            ? doubt!.question
            : (section.title ?? ''))
        .replaceAll(RegExp(r'^شبههٔ? ?\d+[:\-—]*\s*«?'), '')
        .replaceAll(RegExp(r'»$'), '')
        .trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                color:
                    mix(AppTheme.error, Colors.black, 0.18).withValues(alpha: 0.96),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      number > 0 ? '$number' : '؟',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.scaledFontSize(context, 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                number > 0 ? 'شبههٔ $number' : 'شبهه',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTheme.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.help_outline,
                                color: Colors.white70, size: 14),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '«$question»',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTheme.scaledFontSize(context, 14),
                              fontWeight: FontWeight.bold,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
          if (!expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: t.textMuted),
                  const SizedBox(width: 6),
                  Text('برای دیدن پاسخ ضربه بزنید',
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12), color: t.textMuted)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (doubt != null && doubt.explanation.isNotEmpty) ...[
                    const _DoubtLabel(
                        icon: Icons.chat_bubble_outline,
                        text: 'شرح شبهه',
                        color: AppTheme.warning),
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningBg
                            .withValues(alpha: isDark ? 0.18 : 1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                mix(AppTheme.warning, Colors.white, 0.62).withValues(alpha: 0.7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in doubt.explanation)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SelectableText(
                                p,
                                style: TextStyle(
                                    fontSize: fontSize - 0.5,
                                    height: 1.9,
                                    color: t.textPrimary.withValues(alpha: 0.92)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _DoubtLabel(
                      icon: Icons.verified_outlined,
                      text: 'پاسخ تفصیلی',
                      color: AppTheme.success),
                  const SizedBox(height: 8),
                  for (final p in (doubt != null && doubt.body.isNotEmpty
                      ? doubt.body
                      : section.paragraphs
                          .where((x) =>
                              !(doubt?.explanation.contains(x) ?? false) &&
                              !(doubt?.conclusion.contains(x) ?? false))
                          .toList()))
                    _ParagraphBlock(text: p, fontSize: fontSize),
                  if (doubt != null && doubt.conclusion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successBg
                            .withValues(alpha: isDark ? 0.22 : 1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                mix(AppTheme.success, Colors.white, 0.62).withValues(alpha: 0.8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16, color: success),
                              const SizedBox(width: 6),
                              Text('نتیجه',
                                  style: TextStyle(
                                      color: success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppTheme.scaledFontSize(context, 12))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final p in doubt.conclusion)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText(
                                p,
                                style: TextStyle(
                                    fontSize: fontSize - 0.5,
                                    height: 1.9,
                                    color: t.textPrimary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// بسته‌بندی شبهات — فهرست افقی + باز/بسته همه + کارت‌های تاشو
class _DoubtsPackage extends StatelessWidget {
  final List<YaqeenSection> doubts;
  final double fontSize;
  final Set<int> expandedIndices;
  final void Function(int) onToggle;
  final void Function(int) onToggleAll;
  const _DoubtsPackage(
      {required this.doubts,
      required this.fontSize,
      required this.expandedIndices,
      required this.onToggle,
      required this.onToggleAll});

  @override
  Widget build(BuildContext context) {
    final allExpanded = expandedIndices.length == doubts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _YaqeenLessonScreenState.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _YaqeenLessonScreenState.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_outlined,
                      size: 16, color: _YaqeenLessonScreenState.accent),
                  const SizedBox(width: 6),
                  Text('${doubts.length} شبهه — بسته‌بندی شده',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: _YaqeenLessonScreenState.accent,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => onToggleAll(doubts.length),
                    icon: Icon(
                        allExpanded ? Icons.unfold_less : Icons.unfold_more,
                        size: 16),
                    label: Text(allExpanded ? 'بستن همه' : 'باز کردن همه',
                        style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11))),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < doubts.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            left: i < doubts.length - 1 ? 6 : 0),
                        child: ChoiceChip(
                          label: Text(
                              'شبهه ${doubts[i].doubt?.number ?? i + 1}',
                              style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11))),
                          selected: expandedIndices.contains(i),
                          onSelected: (_) => onToggle(i),
                          selectedColor: _YaqeenLessonScreenState.accent
                              .withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                              color: expandedIndices.contains(i)
                                  ? _YaqeenLessonScreenState.accent
                                  : null,
                              fontWeight: expandedIndices.contains(i)
                                  ? FontWeight.bold
                                  : FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < doubts.length; i++) ...[
          _DoubtCard(
              section: doubts[i],
              fontSize: fontSize,
              expanded: expandedIndices.contains(i),
              onToggle: () => onToggle(i)),
          if (i < doubts.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DoubtLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DoubtLabel(
      {required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    // Call sites pass the shared status inks (AppTheme.success / .warning),
    // which are tuned for the light wash and read dark-on-dark at night; lift
    // them toward white when the theme is dark so the label stays legible.
    final c = Theme.of(context).brightness == Brightness.dark
        ? (Color.lerp(color, Colors.white, 0.45) ?? color)
        : color;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 13, color: c),
        ),
        const SizedBox(width: 7),
        Text(text,
            style: TextStyle(
                color: c, fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 12))),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(color: c.withValues(alpha: 0.18), thickness: 1)),
      ],
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  final String text;
  final double fontSize;
  const _ParagraphBlock({required this.text, required this.fontSize});

  bool get _isListItem {
    final t = text.trim();
    return t.startsWith('اولاً:') ||
        t.startsWith('ثانیاً:') ||
        t.startsWith('ثالثاً:') ||
        t.startsWith('رابعاً:') ||
        t.startsWith('خامساً:') ||
        t.startsWith('سادساً:') ||
        t.startsWith('•') ||
        t.startsWith('-') ||
        RegExp(r'^\d+[\.\)]').hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isList = _isListItem;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isList)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 10, left: 8),
              decoration: const BoxDecoration(
                  color: _YaqeenLessonScreenState.accent,
                  shape: BoxShape.circle),
            ),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.95,
                color: t.textPrimary,
                fontWeight: isList ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCTA extends StatelessWidget {
  final YaqeenLesson lesson;
  final List<YaqeenQuizQuestion> questions;
  const _QuizCTA({required this.lesson, required this.questions});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.success.withValues(alpha: 0.08),
        border:
            Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.quiz_outlined,
                color: AppTheme.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('آزمون این درس — ${questions.length} سؤال',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        color: AppTheme.success)),
                const SizedBox(height: 2),
                Text('دانش خود را بسنجید و امتیاز بگیرید',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11), color: t.textMuted)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    YaqeenQuizScreen(lesson: lesson, questions: questions))),
            child: Text('شروع', style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13))),
          ),
        ],
      ),
    );
  }
}
