import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_progress.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_lesson_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/widgets/yaqeen_lesson_tile.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenLevelScreen — فهرست فصل‌ها و درس‌های یک مسیر یادگیری.
/// ═══════════════════════════════════════════════════════════════

class YaqeenLevelScreen extends StatefulWidget {
  final YaqeenLevel level;

  const YaqeenLevelScreen({super.key, required this.level});

  @override
  State<YaqeenLevelScreen> createState() => _YaqeenLevelScreenState();
}

class _YaqeenLevelScreenState extends State<YaqeenLevelScreen> {
  static const Color accent = TopicHues.yaqeen;

  final YaqeenProgress _progress = YaqeenProgress();
  Set<String> _readIds = {};

  @override
  void initState() {
    super.initState();
    _loadRead();
  }

  Future<void> _loadRead() async {
    final ids = await _progress.readIds();
    if (!mounted) return;
    setState(() => _readIds = ids);
  }

  Future<void> _openLesson(YaqeenLesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YaqeenLessonScreen(
        level: widget.level,
        initialLessonId: lesson.id,
      ),
    ));
    _loadRead();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final level = widget.level;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: level.title,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 8, DsSpacing.page, 40),
        children: [
          Text(
            level.subtitle,
            style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12), color: t.textMuted),
          ),
          const SizedBox(height: 14),
          for (final chapter in level.chapters) ...[
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 14)),
                  ),
                ),
                Text(
                  '${chapter.lessons.where((l) => _readIds.contains(l.id)).length}/${chapter.lessons.length}',
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11), color: t.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final lesson in chapter.lessons)
              YaqeenLessonTile(
                lesson: lesson,
                read: _readIds.contains(lesson.id),
                subtitle:
                    '${lesson.sections.length} بخش${lesson.sections.where((s) => s.isDoubt).isNotEmpty ? ' · ${lesson.sections.where((s) => s.isDoubt).length} شبهه' : ''}',
                onTap: () => _openLesson(lesson),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
