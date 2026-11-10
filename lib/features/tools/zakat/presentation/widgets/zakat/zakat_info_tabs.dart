import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart' hide SectionHeader;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_data.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/shared/widgets/numbered_card.dart';
import 'package:tawheeed/shared/widgets/faq_card.dart';

class IntroTab extends StatelessWidget {
  const IntroTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.volunteer_activism,
          accent: TopicHues.zakat,
          title: 'آشنایی با زکات',
          subtitle: 'شناخت جایگاه و اهمیت زکات در اسلام — طبق مذهب شافعی',
        ),
        const SizedBox(height: 12),
        ...ZakatContent.intro.map((r) => RulingCard(
            title: (r['title'] ?? ''),
            body: (r['body'] ?? ''),
            icon: Icons.info_outline,
            iconColor: TopicHues.zakat)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Icon(Icons.auto_stories, size: 28, color: TopicHues.zakat),
              const SizedBox(height: 8),
              Text('«نماز را برپا دارید و زکات بدهید.»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      height: 1.6,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
              const SizedBox(height: 6),
              Text('سوره بقره — آیه 43',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: TimeThemeKit.of(context).palette.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: CONDITIONS & ASSETS
// ════════════════════════════════════════════════════════════════
class ConditionsTab extends StatelessWidget {
  const ConditionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('شرایط وجوب زکات و انواع اموال زکات‌پذیر',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Count is derived (was a hardcoded «7 شرط») and the subtitle no
        // longer claims all listed items are strict conditions of وجوب —
        // that absolute wording contradicted the Shafi'i note below, since
        // بلوغ/عقل/حول are treated differently in that school.
        SectionHeader(
            title: 'شرایط وجوب زکات (${ZakatContent.conditions.length} شرط)',
            icon: Icons.checklist,
            accentColor: TopicHues.zakat,
            subtitle: 'توضیح و تخصیص هر شرط در متن خودش و در یادداشت پایین'),
        const SizedBox(height: 8),
        ...ZakatContent.conditions.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.conditions.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'انواع اموال زکات‌پذیر (5 نوع)',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: TopicHues.zakat,
            subtitle: 'در مذهب شافعی زکات در این پنج نوع مال واجب است'),
        const SizedBox(height: 8),
        ...ZakatContent.assetTypes.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.assetTypes.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'توجه: این احکام بر اساس قول مشهور مذهب شافعی است. در شافعی، بلوغ و عقل شرط وجوب زکات نیستند (زکات حقی بر خودِ مال است) — برای تفصیل پرسش‌های رایج را ببینید. طلا و نقرهٔ زینتی نیز زکات دارند.',
            color: TopicHues.zakat),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 3: NISAB
// ════════════════════════════════════════════════════════════════
class NisabTab extends StatelessWidget {
  const NisabTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on_outlined,
                  size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('نصاب‌ها و مقادیر دقیق زکات بر اساس مذهب شافعی',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...ZakatContent.nisab.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.nisab.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نصاب پول نقد: ارزش 85 گرم طلای خالص یا 595 گرم نقره خالص. در تب «محاسبه» میتوانید مذهب را برگزینید؛ حنابله و احناف کمترین دو نصاب را اعمال میکنند.',
            color: TopicHues.zakat),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4: RECIPIENTS
// ════════════════════════════════════════════════════════════════
class RecipientsTab extends StatelessWidget {
  const RecipientsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('مصارف هشت‌گانه زکات بر اساس آیه 60 سوره توبه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
              '«زکات‌ها مخصوص فقیران و مستمندان و کارگزارانِ (جمع‌آوری) آن و دلجویی‌شدگان و آزادی بردگان و بدهکاران و در راه خدا و در راه‌ماندگان است.»',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  height: 1.8,
                  color: TimeThemeKit.of(context).palette.textPrimary)),
        ),
        const SizedBox(height: 12),
        ...ZakatContent.recipients.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.recipients.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'نمیتوان به کسی که نفقه‌اش واجب است (پدر، مادر، فرزند، همسر) زکات داد؛ به غیرمسلمان هم جز گروه مؤلفةالقلوب داده نمیشود. پرداخت به خویشاوندان نیازمند افضل از غیرخویشاوندان است.',
            color: TopicHues.zakat),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 5: CONTEMPORARY & SPECIAL
// ════════════════════════════════════════════════════════════════
class ContemporaryTab extends StatelessWidget {
  const ContemporaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.new_releases_outlined,
                  size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('اموال مستحدثه و مسائل معاصر زکات + احکام ویژه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
            title: 'اموال مستحدثه و معاصر',
            icon: Icons.trending_up_outlined,
            accentColor: TopicHues.zakat),
        const SizedBox(height: 8),
        ...ZakatContent.contemporary.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.contemporary.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'احکام ویژه زکات',
            icon: Icons.gavel_outlined,
            accentColor: TopicHues.zakat,
            subtitle:
                'حول، دین، نیت، تقدیم، توزیع، زکات فطر و احکام زکات کشاورزی'),
        const SizedBox(height: 8),
        ...ZakatContent.specialRulings.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: ZakatContent.specialRulings.length,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'زکات فطر: یک صاع ≈ 2.5 تا 3 کیلوگرم از غلهٔ غالب منطقه، بر هر مسلمان (حتی کودک). زمان آن: از غروب آخرین روز رمضان؛ افضل صبح عید پیش از نماز.',
            color: TopicHues.zakat),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 6: FAQ & CHECKLIST
// ════════════════════════════════════════════════════════════════
class FaqTab extends StatelessWidget {
  const FaqTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.help_outline, size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('پرسش‌های رایج درباره زکات',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...ZakatContent.faq.asMap().entries.map((e) => FaqCard(
            accentColor: TopicHues.zakat,
            number: e.key + 1,
            question: (e.value['question'] ?? ''),
            answer: (e.value['answer'] ?? ''),
            total: ZakatContent.faq.length)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: TopicHues.zakat),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('چک‌لیست محاسبه و پرداخت زکات',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TopicHues.zakat))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...ZakatContent.checklists.entries.map((entry) => CategoryListCard(
              title: entry.key,
              icon: Icons.check_circle_outline,
              items: entry.value,
              accentColor: TopicHues.zakat,
            )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TopicHues.zakat.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TopicHues.zakat.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories,
                      size: 18, color: TopicHues.zakat),
                  const SizedBox(width: 10),
                  Text('خاتمه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: TopicHues.zakat)),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(ZakatContent.disclaimer,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: TimeThemeKit.of(context).palette.textSecondary,
                      height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
