import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/data/salah_data.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/shared/widgets/numbered_card.dart';
import 'package:tawheeed/shared/widgets/faq_card.dart';
import 'package:tawheeed/shared/widgets/step_checklist_card.dart';
import 'package:tawheeed/core/design_system/components/components.dart' hide SectionHeader;
class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  static const Color _accent = TopicHues.prayer;

  static const List<String> _tabs = [
    'آشنایی',
    'شرایط',
    'آموزش',
    'احکام',
    'انواع',
    'ویژه',
    'سؤالات',
  ];

  /// The whole page, indexed for the in-section search.
  ///
  /// The five lists under «احکام» (ارکان، واجبات، سنن، مکروهات، مبطلات،
  /// اشتباهات رایج) are the reason this exists: a reader who half-remembers
  /// which of the two a step belongs to had to scroll six cards to find out.
  static List<SectionSearchEntry> _buildSearchEntries() {
    SectionSearchEntry ruling(
            int tab, String label, Map<String, dynamic> row) =>
        SectionSearchEntry(
          tab: tab,
          tabLabel: label,
          title: row['title'] as String? ?? '',
          body: row['body'] as String? ?? '',
        );

    SectionSearchEntry item(int tab, String label, String text) =>
        SectionSearchEntry(tab: tab, tabLabel: label, title: text);

    return [
      for (final row in SalahData.intro) ruling(0, 'آشنایی', row),
      for (final row in SalahData.times) ruling(0, 'آشنایی', row),
      for (final row in SalahData.conditions) ruling(1, 'شرایط', row),
      for (final row in SalahData.steps) ruling(2, 'آموزش', row),
      for (final text in SalahData.arkans) item(3, 'احکام', text),
      for (final text in SalahData.wajibat) item(3, 'احکام', text),
      for (final text in SalahData.sunan) item(3, 'احکام', text),
      for (final text in SalahData.makruhat) item(3, 'احکام', text),
      for (final text in SalahData.mubtilat) item(3, 'احکام', text),
      for (final text in SalahData.commonMistakes) item(3, 'احکام', text),
      for (final row in SalahData.types) ruling(4, 'انواع', row),
      for (final row in SalahData.specialRulings) ruling(5, 'ویژه', row),
      for (final row in SalahData.faq)
        SectionSearchEntry(
          tab: 6,
          tabLabel: 'سؤالات',
          title: row['question'] as String? ?? '',
          body: row['answer'] as String? ?? '',
        ),
    ].where((e) => e.title.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildSearchEntries();
    return SectionPage(
      id: 'prayer',
      title: 'نماز',
      tabs: _tabs,
      searchEntries: entries.isEmpty ? null : entries,
      children: const [
        _IntroTab(),
        _ConditionsTab(),
        _StepsTab(),
        _RulingsTab(),
        _TypesTab(),
        _SpecialTab(),
        _FaqTab(),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 0: INTRODUCTION
// ════════════════════════════════════════════════════════════════
class _IntroTab extends StatelessWidget {
  const _IntroTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.mosque,
          accent: PrayerScreen._accent,
          title: 'آشنایی با نماز',
          subtitle:
              'شناخت جایگاه و اهمیت نماز در زندگی مسلمان — طبق مذهب شافعی',
        ),
        const SizedBox(height: 12),
        ...SalahData.intro.map((r) => RulingCard(
            title: (r['title'] ?? ''),
            body: (r['body'] ?? ''),
            icon: Icons.star_outline,
            iconColor: PrayerScreen._accent)),
        const SizedBox(height: 12),
        _buildTimesTable(context),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نماز یکی از پایه‌های ایمان است و اولین چیزی است که در قیامت از اعمال بنده رسیدگی می‌شود.'),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نماز پنج‌گانه واجب است و ترک آن به‌صورت عمدی از موارد کبیره شمرده شده.',
            icon: Icons.warning_amber_outlined,
            isWarning: true),
      ],
    );
  }

  Widget _buildTimesTable(BuildContext context) {
    final pal = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.access_time,
                size: 18, color: PrayerScreen._accent),
            const SizedBox(width: 8),
            Text('اوقات نماز',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary)),
          ]),
          const SizedBox(height: 10),
          ...SalahData.times.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: PrayerScreen._accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                          child: Text((t['name'] ?? ''),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: PrayerScreen._accent))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['rakat']} — ${t['time']}',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    color: pal.textSecondary)),
                            if ((t['note'] ?? '').isNotEmpty)
                              Text((t['note'] ?? ''),
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 11),
                                      color: pal.textMuted)),
                          ]),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 1: CONDITIONS
// ════════════════════════════════════════════════════════════════
class _ConditionsTab extends StatelessWidget {
  const _ConditionsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.checklist,
          accent: PrayerScreen._accent,
          title: 'شرایط نماز',
          subtitle: 'شرایط وجوب و صحت نماز در مذهب شافعی',
        ),
        const SizedBox(height: 12),
        ...SalahData.conditions.map((r) => RulingCard(
            title: (r['title'] ?? ''),
            body: (r['body'] ?? ''),
            icon: Icons.check_circle_outline,
            iconColor: PrayerScreen._accent)),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'بدون رعایت شرایط صحت، نماز باطل است. شرایط باید همزمان با خواندن نماز فراهم باشند.'),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: STEPS (interactive step-by-step prayer checklist, synced to daily worship)
// The 14 steps mirror assets/content/salah.json (arkans/steps) — the JSON is
// the authoritative fiqh source; keep both in sync when content is edited.
// ════════════════════════════════════════════════════════════════
const List<ChecklistStep> _prayerSteps = [
  ChecklistStep(
      'نیت نماز', 'قصد قلبی به نماز معیّن (نوع، فرض یا نفل) — همزمان با تکبیر.',
      isRukn: true),
  ChecklistStep(
      'تکبیرة الاحرام', 'گفتن «الله أکبر» به عربی صحیح برای شروع نماز.',
      isRukn: true),
  ChecklistStep(
      'ایستادن (قیام)', 'برای کسی که توانایی ایستادن دارد — در نمازهای فرض.',
      isRukn: true),
  ChecklistStep(
      'قرائت سوره حمد', 'هر هفت آیه به ترتیب و با اعراب صحیح، در هر رکعت.',
      isRukn: true),
  ChecklistStep(
      'قرائت سوره بعد از حمد', 'در دو رکعت اول، یک سوره کامل یا سه آیه (سنت).'),
  ChecklistStep('رکوع', 'خم شدن تا رسیدن کف دست‌ها به زانو، همراه با طمأنینه.',
      isRukn: true),
  ChecklistStep('اعتدال از رکوع', 'ایستادن کامل و آرام پس از رکوع.',
      isRukn: true),
  ChecklistStep('سجده اول',
      'هفت عضو بر زمین: پیشانی و بینی، دو کف، دو زانو، سر انگشتان پا.',
      isRukn: true),
  ChecklistStep('نشستن بین دو سجده', 'نشستن آرام با پشت صاف.', isRukn: true),
  ChecklistStep('سجده دوم', 'مانند سجده اول با هفت عضو و طمأنینه.',
      isRukn: true),
  ChecklistStep('تشهد پایانی', 'نشستن کامل در رکعت آخر و خواندن تشهد.',
      isRukn: true),
  ChecklistStep(
      'صلوات بر پیامبر', 'درود بر پیامبر در تشهد پایانی — رکن در مذهب شافعی.',
      isRukn: true),
  ChecklistStep(
      'سلام پایانی', 'گفتن «السَّلامُ عَلَیکُم وَرَحمةُ الله» به سمت راست.',
      isRukn: true),
  ChecklistStep('رعایت ترتیب', 'قیام ← قرائت ← رکوع ← سجود ← نشستن ← سلام.',
      isRukn: true),
];

class _StepsTab extends StatelessWidget {
  const _StepsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // ── Interactive step-by-step prayer checklist (synced to daily worship) ──
        const StepChecklistCard(
          prefix: 'prayer',
          title: 'چک‌لیست قدم‌به‌قدم نماز',
          icon: Icons.school_outlined,
          steps: _prayerSteps,
          worshipId: 'prayer',
          worshipLabel: 'نماز',
          worshipIcon: Icons.mosque,
          accent: PrayerScreen._accent,
        ),
        const SizedBox(height: 12),
        const TabIntroCard(
          icon: Icons.school_outlined,
          accent: PrayerScreen._accent,
          title: 'مراحل نماز را مرحله‌به‌مرحله دنبال کنید',
        ),
        const SizedBox(height: 12),
        ...SalahData.steps.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SalahData.steps.length,
              accentColor: PrayerScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نماز باید با طمأنینه و آرامش خوانده شود. عجله در نماز مکروه است.',
            color: PrayerScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 3: RULINGS
// ════════════════════════════════════════════════════════════════
class _RulingsTab extends StatelessWidget {
  const _RulingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.auto_awesome,
          accent: PrayerScreen._accent,
          title: 'ارکان، واجبات، سنن، مکروهات و مبطلات نماز',
        ),
        const SizedBox(height: 12),
        CategoryListCard(
            title: 'ارکان نماز',
            icon: Icons.star,
            items: SalahData.arkans,
            accentColor: PrayerScreen._accent),
        CategoryListCard(
            title: 'واجبات نماز',
            icon: Icons.check,
            items: SalahData.wajibat,
            accentColor: PrayerScreen._accent),
        CategoryListCard(
            title: 'سنن نماز',
            icon: Icons.wb_sunny_outlined,
            items: SalahData.sunan,
            accentColor: PrayerScreen._accent),
        CategoryListCard(
            title: 'مکروهات نماز',
            icon: Icons.thumb_down_outlined,
            items: SalahData.makruhat,
            accentColor: const Color(0xFFFF8F00)),
        CategoryListCard(
            title: 'مبطلات نماز',
            icon: Icons.cancel_outlined,
            items: SalahData.mubtilat,
            accentColor: AppTheme.error),
        CategoryListCard(
            title: 'اشتباهات رایج',
            icon: Icons.help_outline,
            items: SalahData.commonMistakes,
            accentColor: PrayerScreen._accent),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'مبطلات نماز باعث باطل شدن نماز می‌شوند. اگر عمداً انجام شوند، نماز باید دوباره خوانده شود.',
            icon: Icons.warning_amber_outlined,
            isWarning: true),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4: TYPES
// ════════════════════════════════════════════════════════════════
class _TypesTab extends StatelessWidget {
  const _TypesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.category_outlined,
          accent: PrayerScreen._accent,
          title: 'انواع نمازهای واجب و مستحب در اسلام',
        ),
        const SizedBox(height: 12),
        ...SalahData.types.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SalahData.types.length,
              accentColor: PrayerScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نمازهای پنج‌گانه یومیه فرض عین هستند. سایر نمازها بسته به شرایط، فرض کفایی، واجب یا مستحب هستند.',
            color: PrayerScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 5: SPECIAL RULINGS
// ════════════════════════════════════════════════════════════════
class _SpecialTab extends StatelessWidget {
  const _SpecialTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.healing_outlined,
          accent: PrayerScreen._accent,
          title: 'احکام ویژه نماز (سجده سهو، تلاوت، سفر، مریض و...)',
        ),
        const SizedBox(height: 12),
        ...SalahData.specialRulings.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SalahData.specialRulings.length,
              accentColor: PrayerScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'احکام ویژه برای موارد خاص مانند سفر، بیماری و عذرهای شرعی وضع شده‌اند تا نماز هیچ‌گاه از مسلمان ترک نشود.',
            color: PrayerScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 6: FAQ
// ════════════════════════════════════════════════════════════════
class _FaqTab extends StatelessWidget {
  const _FaqTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.help_outline,
          accent: PrayerScreen._accent,
          title: 'پرسش‌های رایج درباره نماز',
        ),
        const SizedBox(height: 12),
        ...SalahData.faq.asMap().entries.map((e) => FaqCard(
            number: e.key + 1,
            question: (e.value['question'] ?? ''),
            answer: (e.value['answer'] ?? ''),
            total: SalahData.faq.length,
            accentColor: PrayerScreen._accent)),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'خاتمه',
            icon: Icons.auto_stories,
            accentColor: PrayerScreen._accent),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.outline),
          ),
          child: SelectableText(SalahData.disclaimer,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textSecondary,
                  height: 1.6)),
        ),
      ],
    );
  }
}
