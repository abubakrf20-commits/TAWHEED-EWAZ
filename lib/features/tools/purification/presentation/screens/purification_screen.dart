import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    hide SectionHeader;
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/purification/data/taharah_data.dart';
import 'package:tawheeed/features/tools/purification/presentation/widgets/taharah_quote_text.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/shared/widgets/step_checklist_card.dart';

class PurificationScreen extends StatelessWidget {
  const PurificationScreen({super.key});

  static const Color _accent = TopicHues.purification;

  /// One entry per tab, in the order [SectionPage] renders them.
  static const List<String> _tabs = [
    'آشنایی',
    'وضو',
    'نواقض',
    'غسل',
    'تیمم',
    'نجاست',
    'متفرقه',
  ];

  /// The whole page, indexed for the in-section search.
  ///
  /// A reader standing inside «تیمم» who wants one ruling used to have to go
  /// back to the shell and re-enter — so in practice they scrolled. Both shapes
  /// of content are indexed: the titled rulings and the plain lists (سنن،
  /// نواقض، مکروهات), whose items are their own titles.
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
      for (final row in TaharahData.intro) ruling(0, 'آشنایی', row),
      for (final row in TaharahData.wudu) ruling(1, 'وضو', row),
      for (final row in TaharahData.wuduConditions) ruling(1, 'وضو', row),
      for (final row in TaharahData.wuduArkan) ruling(1, 'وضو', row),
      for (final text in TaharahData.wuduSunan) item(1, 'وضو', text),
      for (final row in TaharahData.nullifiers) ruling(2, 'نواقض', row),
      for (final text in TaharahData.doNotNullify) item(2, 'نواقض', text),
      for (final row in TaharahData.ghusl) ruling(3, 'غسل', row),
      for (final row in TaharahData.ghuslObligations) ruling(3, 'غسل', row),
      for (final row in TaharahData.ghuslArkan) ruling(3, 'غسل', row),
      for (final text in TaharahData.ghuslMustahabb) item(3, 'غسل', text),
      for (final text in TaharahData.ghuslSunan) item(3, 'غسل', text),
      for (final row in TaharahData.tayammum) ruling(4, 'تیمم', row),
      for (final row in TaharahData.tayammumConditions)
        ruling(4, 'تیمم', row),
      for (final row in TaharahData.tayammumArkan) ruling(4, 'تیمم', row),
      item(4, 'تیمم', TaharahData.tayammumNote),
      item(4, 'تیمم', TaharahData.tayammumNullifiers),
      for (final row in TaharahData.najasah) ruling(5, 'نجاست', row),
      for (final row in TaharahData.najasahTypes) ruling(5, 'نجاست', row),
      for (final row in TaharahData.tathir) ruling(5, 'نجاست', row),
      for (final row in TaharahData.miscellaneous) ruling(6, 'متفرقه', row),
    ].where((e) => e.title.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildSearchEntries();
    return SectionPage(
      id: 'purification',
      title: 'وضو و طهارت',
      tabs: _tabs,
      searchEntries: entries.isEmpty ? null : entries,
      children: const [
        _IntroTab(),
        _WuduTab(),
        _NullifiersTab(),
        _GhuslTab(),
        _TayammumTab(),
        _NajasahTab(),
        _MiscTab(),
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
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // Flat hero (replaces the gradient EducationHeroHeader): solid
        // card, duotone tile — title and subtitle unchanged.
        const TabIntroCard(
          accent: PurificationScreen._accent,
          icon: Icons.water_drop,
          title:
              'آشنایی با طهارت\nپاکیزگی مقدمه عبادت و شرط صحت نماز — طبق مذهب شافعی',
        ),
        const SizedBox(height: 10),
        ...TaharahData.intro.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),
        const SizedBox(height: 10),
        const InfoBox(
            text:
                'طهارت شرط صحت نماز است و بدون آن، هیچ عبادتی پذیرفته نمی‌شود. طهارت مقدمه نماز و بسیاری از عبادات است.'),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: WUDU (interactive step-by-step checklist + definition + 7 conditions + 6 arkan + sunan)
// ════════════════════════════════════════════════════════════════
class _WuduTab extends StatelessWidget {
  const _WuduTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // ── Interactive step-by-step wudu checklist (synced to daily worship) ──
        const StepChecklistCard(
          prefix: 'wudu',
          title: 'چک‌لیست قدم‌به‌قدم وضو',
          icon: Icons.water_drop_outlined,
          steps: _wuduSteps,
          worshipId: 'wudu',
          worshipLabel: 'وضو',
          worshipIcon: Icons.clean_hands,
          accent: PurificationScreen._accent,
        ),
        const SizedBox(height: 10),
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.water_drop_outlined,
            title: 'احکام کامل وضو — تعریف، شرایط، ارکان و سنن'),
        const SizedBox(height: 10),

        // ── Definition ──
        ...TaharahData.wudu.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),

        // ── Conditions (7) ──
        const SectionHeader(
            title: 'شرایط صحت وضو (شروط الصحة)',
            icon: Icons.checklist,
            accentColor: PurificationScreen._accent,
            subtitle: '7 شرط برای صحت وضو ضروری است'),
        ..._numbered(TaharahData.wuduConditions),

        // ── Arkan (6) ──
        const SectionHeader(
            title: 'ارکان وضو (6 رکن)',
            icon: Icons.auto_awesome,
            accentColor: PurificationScreen._accent,
            subtitle: 'ترک عمدی یا سهوی هر یک باعث بطلان وضو می‌شود'),
        ..._numbered(TaharahData.wuduArkan),

        // ── Sunan ──
        TaharahListCard(
          title: 'سنن و مستحبات وضو',
          items: TaharahData.wuduSunan,
        ),
      ],
    );
  }
}

/// Numbered entries for a `[{title, body}]` list, in JSON order — the
/// numbering is presentation; the text is untouched.
List<Widget> _numbered(List<Map<String, dynamic>> items) => [
      for (final (i, e) in items.indexed)
        TaharahNumberedCard(
          number: i + 1,
          title: (e['title'] ?? ''),
          body: (e['body'] ?? ''),
          total: items.length,
        ),
    ];

// ════════════════════════════════════════════════════════════════
// INTERACTIVE STEP-BY-STEP PURIFICATION CHECKLISTS (wudu / ghusl / tayammum)
// Progress is persisted per day (SharedPreferences) and a completed checklist
// is registered in today's worship (evaluationProvider 'wudu'/'ghusl'/'tayammum').
// The steps mirror assets/content/taharah.json (arkan/sunan) — the JSON is the
// authoritative fiqh source; keep both in sync when content is edited.
// ════════════════════════════════════════════════════════════════
const List<ChecklistStep> _wuduSteps = [
  ChecklistStep(
      'نیت وضو', 'نیت را در دل بیاورید و همزمان با اولین شستن آغاز کنید.',
      isRukn: true),
  ChecklistStep('شستن کف دست‌ها', 'سه بار کف دست‌ها را تا مچ بشویید.'),
  ChecklistStep('مضمضه', 'آب را در دهان بچرخانید و بیرون بریزید (سنت مؤکده).'),
  ChecklistStep(
      'استنشاق', 'آب را به بینی بکشید و با دست چپ بیرون دهید (سنت مؤکده).'),
  ChecklistStep('شستن صورت',
      'از رویش موی سر تا زیر چانه و از گوش راست تا گوش چپ، یک بار.',
      isRukn: true),
  ChecklistStep(
      'شستن دست‌ها تا آرنج', 'دست راست سپس چپ، از نوک انگشتان تا آرنج، یک بار.',
      isRukn: true),
  ChecklistStep('مسح سر', 'دست تر را بر قسمتی از سر (حداقل یک‌چهارم) بکشید.',
      isRukn: true),
  ChecklistStep('مسح گوش‌ها', 'داخل و خارج گوش‌ها را با آب تازه مسح کنید.'),
  ChecklistStep('شستن پاها تا مچ',
      'پای راست سپس چپ، یک بار، همراه با درآوردن آب بین انگشتان.',
      isRukn: true),
  ChecklistStep(
      'رعایت ترتیب', 'ترتیب بالا (صورت، دست‌ها، مسح سر، پاها) را حفظ کنید.',
      isRukn: true),
];

const List<ChecklistStep> _ghuslSteps = [
  ChecklistStep(
      'نیت غسل', 'در دل قصد رفع جنابت، حیض، نفاس یا انجام غسل مستحب کنید.',
      isRukn: true),
  ChecklistStep('تسمیه', 'با گفتن «بسم الله» آغاز کنید (سنت).'),
  ChecklistStep('شستن دست‌ها قبل از ورود',
      'قبل از ورود به غسل، سه بار دست‌ها را تا مچ بشویید (سنت).'),
  ChecklistStep('مضمضه و استنشاق',
      'آب در دهان و بینی — اگر غسل برای جنابت باشد (سنت، نه واجب).'),
  ChecklistStep('تخلیل مو', 'آب را به ریشه مو و تمام پوست سر برسانید (سنت).'),
  ChecklistStep('شستن تمام بدن',
      'از سر تا نوک پا — آب باید به تمام پوست و مو برسد (رکن).',
      isRukn: true),
  ChecklistStep('مسح بدن با دست', 'با دست، آب را بر تمام بدن بکشید (سنت).'),
];

const List<ChecklistStep> _tayammumSteps = [
  ChecklistStep('نیت تیمم', 'قصد استباحة الصلاة یا رفع حدث کنید.',
      isRukn: true),
  ChecklistStep('ضربه اول بر خاک پاک', 'دست‌ها را بر خاک یا زمین پاک بزنید.',
      isRukn: true),
  ChecklistStep(
      'مسح تمام صورت', 'با دست‌های خاکی تمام صورت را یک بار مسح کنید.',
      isRukn: true),
  ChecklistStep('ضربه دوم بر خاک پاک', 'بار دوم دست‌ها را بر خاک پاک بزنید.',
      isRukn: true),
  ChecklistStep(
      'مسح دست راست و چپ', 'دست راست تا مچ، سپس دست چپ تا مچ را مسح کنید.',
      isRukn: true),
  ChecklistStep('رعایت ترتیب', 'ترتیب «صورت، سپس دست‌ها» را حفظ کنید.',
      isRukn: true),
];

// ════════════════════════════════════════════════════════════════
// TAB 3: NULLIFIERS
// ════════════════════════════════════════════════════════════════
class _NullifiersTab extends StatelessWidget {
  const _NullifiersTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.cancel_outlined,
            title: 'چه چیزهایی وضو را باطل می‌کند؟'),

        // ── 6 Nullifiers with numbers (danger accent) ──
        ..._numbered(TaharahData.nullifiers),

        // ── What does NOT nullify (success accent) ──
        TaharahListCard(
          title: 'مواردی که وضو را باطل نمی‌کند',
          items: TaharahData.doNotNullify,
          accentColor: success,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4: GHUSL
// ════════════════════════════════════════════════════════════════
class _GhuslTab extends StatelessWidget {
  const _GhuslTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // ── Interactive step-by-step ghusl checklist (synced to daily worship) ──
        const StepChecklistCard(
          prefix: 'ghusl',
          title: 'چک‌لیست قدم‌به‌قدم غسل',
          icon: Icons.shower_outlined,
          steps: _ghuslSteps,
          worshipId: 'ghusl',
          worshipLabel: 'غسل',
          worshipIcon: Icons.shower,
          accent: PurificationScreen._accent,
        ),
        const SizedBox(height: 10),
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.shower_outlined,
            title: 'تعریف، موجبات، ارکان و سنن غسل'),

        // ── Definition ──
        ...TaharahData.ghusl.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),

        // ── 5 Obligations ──
        const SectionHeader(
            title: 'موجبات غسل',
            icon: Icons.checklist,
            accentColor: PurificationScreen._accent,
            subtitle: 'پنج چیزی که غسل را واجب می‌کند'),
        ..._numbered(TaharahData.ghuslObligations),

        // ── Mustahabb ──
        TaharahListCard(
          title: 'غسل‌های مستحب',
          items: TaharahData.ghuslMustahabb,
        ),

        // ── 3 Arkan ──
        const SectionHeader(
            title: 'ارکان غسل (3 رکن)',
            icon: Icons.auto_awesome,
            accentColor: PurificationScreen._accent),
        ..._numbered(TaharahData.ghuslArkan),

        // ── Sunan ──
        TaharahListCard(
          title: 'سنن غسل',
          items: TaharahData.ghuslSunan,
        ),

        const SizedBox(height: 8),
        const InfoBox(
            text:
                'غسل‌های واجب: جنابت، جماع، حیض، نفاس و مرگ (به‌جز شهید معرکه). غسل جمعه، عیدین و احرام مستحب هستند.',
            color: PurificationScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 5: TAYAMMUM
// ════════════════════════════════════════════════════════════════
class _TayammumTab extends StatelessWidget {
  const _TayammumTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // ── Interactive step-by-step tayammum checklist (synced to daily worship) ──
        const StepChecklistCard(
          prefix: 'tayammum',
          title: 'چک‌لیست قدم‌به‌قدم تیمم',
          icon: Icons.back_hand_outlined,
          steps: _tayammumSteps,
          worshipId: 'tayammum',
          worshipLabel: 'تیمم',
          worshipIcon: Icons.back_hand,
          accent: PurificationScreen._accent,
        ),
        const SizedBox(height: 10),
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.back_hand_outlined,
            title: 'تیمم — جایگزین وضو و غسل در شرایط خاص'),

        // ── Definition ──
        ...TaharahData.tayammum.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),

        // ── 5 Conditions ──
        const SectionHeader(
            title: 'شرایط جواز تیمم',
            icon: Icons.checklist,
            accentColor: PurificationScreen._accent,
            subtitle: '5 شرط برای مشروع بودن تیمم'),
        ..._numbered(TaharahData.tayammumConditions),

        // ── 3 Arkan ──
        const SectionHeader(
            title: 'ارکان تیمم (کیفیت)',
            icon: Icons.auto_awesome,
            accentColor: PurificationScreen._accent),
        ..._numbered(TaharahData.tayammumArkan),

        // ── Notes ──
        InfoBox(text: TaharahData.tayammumNote, icon: Icons.lightbulb_outline),
        const SizedBox(height: 8),
        InfoBox(
            text: TaharahData.tayammumNullifiers,
            icon: Icons.warning_amber_outlined,
            isWarning: true),
        const SizedBox(height: 8),
        const InfoBox(
            text:
                'تیمم فقط در صورت عدم دسترسی به آب، بیماری، یا خطر استفاده از آب مشروع است.'),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 6: NAJASAH
// ════════════════════════════════════════════════════════════════
class _NajasahTab extends StatelessWidget {
  const _NajasahTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.cleaning_services_outlined,
            title: 'طهارت از نجاست (خبث) — انواع نجاسات و روش تطهیر'),

        // ── Definition ──
        ...TaharahData.najasah.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),

        // ── Types ──
        const SectionHeader(
            title: 'مهم‌ترین نجاسات',
            icon: Icons.list,
            accentColor: PurificationScreen._accent,
            subtitle: '5 مورد از مهم‌ترین نجاسات در شرع'),
        ..._numbered(TaharahData.najasahTypes),

        // ── Tathir ──
        const SectionHeader(
            title: 'تطهیر (پاک کردن نجاست)',
            icon: Icons.cleaning_services,
            accentColor: PurificationScreen._accent),
        ...TaharahData.tathir.map((r) => TaharahRulingCard(
              title: (r['title'] ?? ''),
              body: (r['body'] ?? ''),
            )),
        const SizedBox(height: 10),
        const InfoBox(
            text:
                'پاکی بدن، لباس و محل نماز هر سه برای صحت نماز لازم هستند. نجاست باید با آب روان پاک شود.',
            color: PurificationScreen._accent),
        const SizedBox(height: 8),
        const InfoBox(
            text:
                'خون در مذهب شافعی نجس است، چه کم چه زیاد؛ و اگر خونی از غیر دو راه بیرون آید و جاری شود، وضو را نیز باطل می‌کند. نجاست باید از بدن و لباس زدوده شود.',
            icon: Icons.water_drop_outlined,
            color: PurificationScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 7: MISCELLANEOUS
// ════════════════════════════════════════════════════════════════
class _MiscTab extends StatelessWidget {
  const _MiscTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
            accent: PurificationScreen._accent,
            icon: Icons.help_outline, title: 'مسائل متفرقه و احکام خاص'),

        // ── Miscellaneous items as numbered cards ──
        ..._numbered(TaharahData.miscellaneous),

        // ── Conclusion / Disclaimer ──
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DuotoneIconTile(
                    accent: PurificationScreen._accent,
                    icon: Icons.auto_stories,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'خاتمه',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                TaharahData.disclaimer,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textSecondary,
                    height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
