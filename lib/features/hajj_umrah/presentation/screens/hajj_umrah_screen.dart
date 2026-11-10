import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    hide SectionHeader;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_content.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_trip.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/widgets/rite_counter_sheet.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/widgets/ritual_steps_view.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/shared/widgets/numbered_card.dart';
import 'package:tawheeed/shared/widgets/faq_card.dart';
import 'package:tawheeed/shared/widgets/checklist_card.dart';

class HajjUmrahScreen extends StatelessWidget {
  const HajjUmrahScreen({super.key});

  static const Color _accent = TopicHues.hajjUmrah;

  static const List<String> _tabs = [
    'آشنایی',
    'مناسک عمره',
    'مناسک حج',
    'ارکان و محرمات',
    'فدیه و کفارات',
    'احکام ویژه',
    'پرسش‌ها',
  ];

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      id: 'hajj',
      title: 'حج و عمره',
      tabs: _tabs,
      searchEntries: hajjSearchEntries(),
      children: const [
        _IntroTab(),
        _UmrahTab(),
        _HajjTab(),
        _PillarsTab(),
        _ExpiationTab(),
        _SpecialTab(),
        _FaqChecklistTab(),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 1: INTRODUCTION
// ════════════════════════════════════════════════════════════════
class _IntroTab extends StatelessWidget {
  const _IntroTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const TabIntroCard(
          icon: Icons.mosque_outlined,
          accent: HajjUmrahScreen._accent,
          title: 'آشنایی با حج و عمره',
          subtitle: 'شناخت جایگاه و اهمیت حج و عمره در اسلام — طبق مذهب شافعی',
        ),
        const SizedBox(height: 12),
        ...HajjData.introConcepts.map((c) => RulingCard(
            title: c.title,
            body: c.body,
            icon: c.icon,
            iconColor: HajjUmrahScreen._accent)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Icon(Icons.auto_stories,
                  size: 28, color: HajjUmrahScreen._accent),
              const SizedBox(height: 8),
              Text(
                '«وَلِلَّهِ عَلَى النَّاسِ حِجُّ الْبَيْتِ مَنِ اسْتَطَاعَ إِلَيْهِ سَبِيلًا»',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 1.6,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text('آل عمران - 97',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: UMRAH RITUALS
// ════════════════════════════════════════════════════════════════
class _UmrahTab extends StatelessWidget {
  const _UmrahTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_walk_outlined,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('مناسک عمره مرحله به مرحله — از احرام تا حلق',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _RiteCounterRow(),
        const SizedBox(height: 12),
        RitualStepsView(
          storageKey: 'umrah',
          steps: HajjData.umrahSteps,
          accentColor: HajjUmrahScreen._accent,
          progressLabel: 'پیشرفت عمره',
        ),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'عمره در هر زمان از سال قابل انجام است (به جز ایام تشریق برای حاجیان در منی). ارکان عمره: احرام، طواف، سعی، حلق/تقصیر.',
            color: HajjUmrahScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 3: HAJJ RITUALS
// ════════════════════════════════════════════════════════════════
class _HajjTab extends ConsumerWidget {
  const _HajjTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The guide knows which rite belongs to which Hijri day; the calendar
    // knows today's Hijri day. Put together they answer the only question a
    // traveller in Mina has — «الان باید چه کار کنم؟» — on the first screen.
    final offset = ref.watch(hijriOffsetProvider);
    final now = DateTime.now();
    final today =
        HijriUtils.hijriFromGreg(now.year, now.month, now.day, offset: offset);
    final stepToday = hajjStepForHijri(today.month, today.day);
    final nightStep = now.hour >= 18
        ? hajjNightStepForHijri(today.month, today.day)
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('مناسک حج روزبه‌روز — از 8 تا 13 ذی‌حجه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        if (stepToday != null) ...[
          const SizedBox(height: 10),
          _TripDayBanner(
            hijriDay: today.day,
            step: stepToday,
            nightStep: nightStep,
            steps: HajjData.hajjSteps,
          ),
        ],
        const SizedBox(height: 10),
        const _RiteCounterRow(),
        const SizedBox(height: 12),
        RitualStepsView(
          storageKey: 'hajj',
          steps: HajjData.hajjSteps,
          accentColor: HajjUmrahScreen._accent,
          progressLabel: 'پیشرفت حج',
          highlightStep: stepToday,
        ),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'رکن اصلی حج، وقوف در عرفه است. پیامبر ﷺ فرمود: «الْحَجُّ عَرَفَةُ». هر کس به عرفه نرسد، حجش باطل است.',
            color: HajjUmrahScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4: PILLARS, OBLIGATIONS & PROHIBITIONS
// ════════════════════════════════════════════════════════════════
class _PillarsTab extends StatelessWidget {
  const _PillarsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('شرایط، ارکان، واجبات، محرمات و انواع حج',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Hajj types (تمتع / قران / افراد) — richer cards than the plain list.
        ..._buildHajjTypes(context),
        const SizedBox(height: 12),
        // Sections routed by stable id (excludes expiation / special / types).
        ..._buildRulingsSections(context, HajjData.coreRulingSections),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'ارکان در صورت ترک (عمدی یا سهوی) موجب بطلان حج/عمره می‌شوند. واجبات در صورت ترک نیاز به فدیه دارند.',
            color: HajjUmrahScreen._accent),
      ],
    );
  }

  List<Widget> _buildHajjTypes(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final types = HajjData.hajjTypes;
    if (types.isEmpty) return const [];
    final widgets = <Widget>[
      const _SectionTitle(
          title: 'انواع حج',
          subtitle: 'تمتع، قران و افراد',
          accentColor: HajjUmrahScreen._accent),
    ];
    for (var i = 0; i < types.length; i++) {
      final ht = types[i];
      widgets.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HajjUmrahScreen._accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w800,
                        color: HajjUmrahScreen._accent,
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    ht.title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (ht.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                ht.subtitle,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: HajjUmrahScreen._accent,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SelectableText(
              ht.description,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textSecondary,
                height: 1.6,
              ),
            ),
            if (ht.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star_outline_rounded,
                        size: 15, color: HajjUmrahScreen._accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        ht.note,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _buildRulingsSections(
      BuildContext context, List<RulingSection> sections) {
    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(_SectionTitle(
          title: section.title,
          subtitle: section.subtitle,
          accentColor: HajjUmrahScreen._accent));
      for (var i = 0; i < section.items.length; i++) {
        widgets.add(NumberedCard(
          number: i + 1,
          title: section.items[i].title,
          body: section.items[i].body,
          total: section.items.length,
          accentColor: HajjUmrahScreen._accent,
        ));
      }
    }
    return widgets;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 8),
          Text(title,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              )),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(subtitle,
                  textDirection: TextDirection.rtl,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 5: EXPIATION (فدیه و کفارات)
// ════════════════════════════════════════════════════════════════
class _ExpiationTab extends StatelessWidget {
  const _ExpiationTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.gavel_outlined,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('فدیه و کفارات — جبران نقصان در حج',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
            title: 'انواع فدیه و کفارات',
            icon: Icons.scale_outlined,
            accentColor: HajjUmrahScreen._accent,
            subtitle: '5 دسته از جریمه‌های حج'),
        const SizedBox(height: 8),
        ...HajjData.expiation.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: HajjData.expiation.length,
              accentColor: HajjUmrahScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'در مذهب شافعی، جماع (رابطهٔ زناشویی) در حال احرام و پیش از تحلّل، حج را باطل می‌کند؛ باید آن را تمام کرد، سال بعد قضا نمود و کفاره‌اش یک شتر (یا گاو) است. تفکیک میان پیش و پس از وقوف عرفه دیدِ حنفی است، نه شافعی. کفارهٔ سایر محرمات: یک گوسفند یا سه روز روزه یا اطعام شش مسکین.',
            color: HajjUmrahScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 6: SPECIAL RULINGS
// ════════════════════════════════════════════════════════════════
class _SpecialTab extends StatelessWidget {
  const _SpecialTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.healing_outlined,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'احکام ویژه (زنان، کودکان، بیماران) و مسائل معاصر',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...HajjData.specialRulings.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: HajjData.specialRulings.length,
              accentColor: HajjUmrahScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'حج نیابتی برای میت و بیمار لاعلاج جایز است. نائب باید مسلمان، بالغ، عاقل و خود قبلاً حج انجام داده باشد.',
            color: HajjUmrahScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 7: FAQ & CHECKLIST
// ════════════════════════════════════════════════════════════════
class _FaqChecklistTab extends StatelessWidget {
  const _FaqChecklistTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── FAQ Header ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.help_outline,
                  size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('پرسش‌های رایج درباره حج و عمره',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── FAQ Items ──
        ...HajjData.faq.asMap().entries.map((e) => FaqCard(
            number: e.key + 1,
            question: e.value.question,
            answer: e.value.answer,
            total: HajjData.faq.length,
            accentColor: HajjUmrahScreen._accent)),
        const SizedBox(height: 16),

        // ── Checklists ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: HajjUmrahScreen._accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('چک‌لیست سفر حج و عمره',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: HajjUmrahScreen._accent))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...HajjData.checklistSections.map((section) => ChecklistCard(
              sectionKey: section.title,
              title: section.title,
              icon: section.icon,
              items: section.items.map((i) => i.title).toList(),
            )),

        const SizedBox(height: 12),

        // ── Conclusion / Disclaimer ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HajjUmrahScreen._accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories,
                      size: 18, color: HajjUmrahScreen._accent),
                  const SizedBox(width: 10),
                  Text('خاتمه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: HajjUmrahScreen._accent)),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(HajjData.disclaimer,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textSecondary,
                      height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED — the rite counter and the day banner
// ════════════════════════════════════════════════════════════════

/// Two entry points to the tawaf/sa'i counter. They sit above the step list
/// because the counter is used *during* the rite, when the guide's long cards
/// are the last thing anyone wants to scroll through.
class _RiteCounterRow extends StatelessWidget {
  const _RiteCounterRow();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    Widget button(CounterKind kind, IconData icon, String label) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: () => showRiteCounterSheet(context, kind: kind),
          style: OutlinedButton.styleFrom(
            foregroundColor: HajjUmrahScreen._accent,
            side: BorderSide(
                color: HajjUmrahScreen._accent.withValues(alpha: 0.35)),
            backgroundColor: HajjUmrahScreen._accent.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 17),
          label: Text(
            label,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(CounterKind.tawaf, Icons.filter_7_outlined, 'شمارنده طواف'),
        const SizedBox(width: 8),
        button(CounterKind.sai, Icons.swap_horiz_rounded, 'شمارنده سعی'),
      ],
    );
  }
}

/// «امروز ۹ ذی‌حجه — یوم عرفه», with the rite that day belongs to.
///
/// Only rendered inside the five days of hajj: outside them there is nothing
/// true to say, and a permanent «حالت سفر» switch would be one more thing to
/// turn off.
class _TripDayBanner extends StatelessWidget {
  const _TripDayBanner({
    required this.hijriDay,
    required this.step,
    required this.nightStep,
    required this.steps,
  });

  final int hijriDay;
  final int step;
  final int? nightStep;
  final List<RitualStepData> steps;

  RitualStepData? get _data {
    for (final s in steps) {
      if (s.step == step) return s;
    }
    return null;
  }

  RitualStepData? get _nightData {
    for (final s in steps) {
      if (s.step == nightStep) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = HajjUmrahScreen._accent;
    final data = _data;
    final night = _nightData;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'امروز $hijriDay ${DateConstants.hijriMonths[11]}'
                  ' · ${hajjDayLabel(hijriDay)}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'مرحله $step از ${steps.length}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (data != null) ...[
            const SizedBox(height: 6),
            Text(
              data.subtitle.isEmpty ? data.title : data.subtitle,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
              ),
            ),
          ],
          if (night != null) ...[
            const SizedBox(height: 6),
            Text(
              'امشب: ${night.subtitle.isEmpty ? night.title : night.subtitle}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                color: t.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH — the guide's own index
// ════════════════════════════════════════════════════════════════

List<SectionSearchEntry>? _searchCache;

/// Every piece of the guide that can be searched, tagged with the tab it came
/// from. Built once per process: the content is static after [HajjData.load],
/// and rebuilding a few hundred folded keys per keystroke would make the sheet
/// feel worse than scrolling did.
List<SectionSearchEntry> hajjSearchEntries() {
  final cached = _searchCache;
  if (cached != null) return cached;
  if (!HajjData.isLoaded) return const [];

  const intro = 0, umrah = 1, hajj = 2, pillars = 3;
  const expiationTab = 4, special = 5, faqTab = 6;
  final entries = <SectionSearchEntry>[
    for (final c in HajjData.introConcepts)
      SectionSearchEntry(
          tab: intro, tabLabel: 'آشنایی', title: c.title, body: c.body),
    for (final t in HajjData.hajjTypes)
      SectionSearchEntry(
        tab: intro,
        tabLabel: 'آشنایی',
        title: t.title,
        body: '${t.subtitle} ${t.description} ${t.note}',
      ),
    for (final s in HajjData.umrahSteps)
      SectionSearchEntry(
        tab: umrah,
        tabLabel: 'مناسک عمره',
        title: 'عمره · ${s.title}',
        body: '${s.subtitle} ${s.description} ${s.tip}',
      ),
    for (final s in HajjData.hajjSteps)
      SectionSearchEntry(
        tab: hajj,
        tabLabel: 'مناسک حج',
        title: 'حج · ${s.title}',
        body: '${s.subtitle} ${s.description} ${s.tip}',
      ),
    for (final sec in HajjData.coreRulingSections)
      for (final item in sec.items)
        SectionSearchEntry(
          tab: pillars,
          tabLabel: 'ارکان و محرمات',
          title: '${sec.title} · ${item.title}',
          body: item.body,
        ),
    for (final item in HajjData.expiation)
      SectionSearchEntry(
        tab: expiationTab,
        tabLabel: 'فدیه و کفارات',
        title: item['title'] ?? '',
        body: item['body'] ?? '',
      ),
    for (final item in HajjData.specialRulings)
      SectionSearchEntry(
        tab: special,
        tabLabel: 'احکام ویژه',
        title: item['title'] ?? '',
        body: item['body'] ?? '',
      ),
    for (final f in HajjData.faq)
      SectionSearchEntry(
        tab: faqTab,
        tabLabel: 'پرسش‌ها',
        title: f.question,
        body: f.answer,
      ),
    for (final c in HajjData.checklistSections)
      SectionSearchEntry(
        tab: faqTab,
        tabLabel: 'پرسش‌ها',
        title: 'چک‌لیست · ${c.title}',
        body: c.items.map((i) => i.title).join(' · '),
      ),
  ];
  _searchCache = entries;
  return entries;
}
