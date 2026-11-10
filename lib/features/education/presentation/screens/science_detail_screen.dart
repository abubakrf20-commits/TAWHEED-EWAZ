import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/features/education/presentation/widgets/branch_list.dart';
import 'package:tawheeed/features/education/presentation/widgets/term_card.dart';
import 'package:tawheeed/features/education/presentation/widgets/faq_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/related_sciences.dart';
import 'package:tawheeed/features/education/presentation/widgets/common_mistakes_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/application_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/evidence_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/chapters_section.dart';

class ScienceDetailScreen extends StatelessWidget {
  final String scienceId;
  const ScienceDetailScreen({super.key, required this.scienceId});

  @override
  Widget build(BuildContext context) {
    final science = SciencesContent.byId(scienceId);
    if (science == null) {
      // Nothing failed here: the id is simply not in the content set, so the
      // honest surface is an empty state, not an error. The old version put
      // «خطا» in the app bar and one grey line in the body.
      return const Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(title: 'علم'),
        body: AppEmptyState(
          icon: Icons.science_outlined,
          message: 'این علم پیدا نشد',
          subtitle: 'ممکن است این مدخل جابه‌جا یا حذف شده باشد.',
        ),
      );
    }
    return _ScienceDetailBody(science: science);
  }
}

class _ScienceDetailBody extends StatelessWidget {
  final ScienceData science;
  const _ScienceDetailBody({required this.science});

  @override
  Widget build(BuildContext context) {
    // The science's own identity hue: the header and every section inside
    // wear the category colour instead of the module indigo.
    final accent = SciencesContent.accentOf(science.category);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: science.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'کپی متن علم',
            onPressed: () {
              final buffer = StringBuffer();
              if (science.chapters.isNotEmpty) {
                buffer.writeln(science.title);
                buffer.writeln();
                for (final ch in science.chapters) {
                  buffer.writeln('◉ ${ch.title}');
                  if (ch.body != null && ch.body!.isNotEmpty) {
                    buffer.writeln(ch.body);
                    buffer.writeln();
                  }
                  for (final sub in ch.subsections) {
                    if (sub.title != null && sub.title!.isNotEmpty) {
                      buffer.writeln('▸ ${sub.title}');
                    }
                    if (sub.body != null && sub.body!.isNotEmpty) {
                      buffer.writeln(sub.body);
                      buffer.writeln();
                    }
                    for (final item in sub.items) {
                      buffer.writeln('• $item');
                    }
                    for (final v in sub.verses) {
                      buffer.writeln(v);
                    }
                  }
                  buffer.writeln();
                }
              } else {
                buffer.writeln(science.title);
                buffer.writeln();
                if (science.evidence.isNotEmpty) {
                  buffer.writeln('ادله:');
                  for (final e in science.evidence) {
                    buffer.writeln('• $e');
                  }
                  buffer.writeln();
                }
                if (science.subtopics.isNotEmpty) {
                  buffer.writeln('شاخه‌ها:');
                  for (final s in science.subtopics) {
                    buffer.writeln('• $s');
                  }
                  buffer.writeln();
                }
                if (science.keyTerms.isNotEmpty) {
                  buffer.writeln('اصطلاحات:');
                  for (final t in science.keyTerms) {
                    buffer.writeln('• ${t.term}: ${t.definition}');
                  }
                  buffer.writeln();
                }
                if (science.faqs.isNotEmpty) {
                  buffer.writeln('پرسش و پاسخ:');
                  for (final f in science.faqs) {
                    buffer.writeln('س: ${f.question}');
                    buffer.writeln('ج: ${f.answer}');
                  }
                }
              }
              ShareService.copyText(context, buffer.toString());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.page, vertical: 12),
        children: [
          _buildHeader(accent),
          const SizedBox(height: 16),
          if (!science.isComplete) ...[
            _buildComingSoonBanner(context, accent),
            const SizedBox(height: 16),
          ],
          if (science.chapters.isNotEmpty) ...[
            ChaptersSection(chapters: science.chapters, accent: accent),
            const SizedBox(height: 16),
          ],
          if (science.chapters.isEmpty) ...[
            if (science.evidence.isNotEmpty) ...[
              EvidenceSection(evidence: science.evidence, accent: accent),
              const SizedBox(height: 16),
            ],
            if (science.subtopics.isNotEmpty) ...[
              BranchList(subtopics: science.subtopics, accent: accent),
              const SizedBox(height: 16),
            ],
            if (science.keyTerms.isNotEmpty) ...[
              TermSection(terms: science.keyTerms, accent: accent),
              const SizedBox(height: 16),
            ],
            if (science.faqs.isNotEmpty) ...[
              FaqSection(faqs: science.faqs, accent: accent),
              const SizedBox(height: 16),
            ],
            if (science.commonMistakes.isNotEmpty) ...[
              CommonMistakesSection(mistakes: science.commonMistakes),
              const SizedBox(height: 16),
            ],
            if (science.application.isNotEmpty) ...[
              ApplicationSection(application: science.application),
              const SizedBox(height: 16),
            ],
          ],
          RelatedSciencesSection(
            relatedIds: science.relatedSciences,
            accent: accent,
            onScienceTap: (id) {
              // GoRouter keeps the pushed science inside the ambient-background
              // route; a Navigator.push would paint the bare window instead.
              context.push(RouteNames.scienceDetailPath(id));
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildComingSoonBanner(BuildContext context, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top,
              size: 20, color: accent, textDirection: TextDirection.rtl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'این علم در حال تکمیل است',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'محتوا و فصول کامل این بخش به‌زودی اضافه می‌شود؛ بخش‌های نمایش‌داده‌شده فعلی، خلاصهٔ اولیه است.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    height: 1.5,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    // The same flat intro recipe every redesigned section opens with
    // (TabIntroCard): the duotone tile carries the category's identity hue.
    // The module-indigo solid banner and the per-item emoji are gone.
    return TabIntroCard(
      icon: SciencesContent.glyphOf(science.category),
      accent: accent,
      title: science.title,
      subtitle: science.category.label,
    );
  }
}
