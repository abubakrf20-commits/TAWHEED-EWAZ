import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show AppCard, IconTile, SectionPage, SectionSearchEntry, TabIntroCard;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/fasting/data/fasting_content.dart';
import 'package:tawheeed/features/fasting/presentation/tabs/ramadan_tracker_tab.dart';
import 'package:tawheeed/features/fasting/presentation/tabs/fitr_zakat_tab.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/shared/widgets/numbered_card.dart';
import 'package:tawheeed/shared/widgets/faq_card.dart';

class FastingScreen extends StatelessWidget {
  const FastingScreen({super.key});

  static const Color _accent = TopicHues.fasting;

  /// One entry per tab, in the order [SectionPage] renders them.
  static const List<String> _tabs = [
    'رمضان',
    'زکات فطر',
    'آشنایی',
    'ارکان و مبطلات',
    'قضا و کفاره',
    'سنن و آداب',
    'موارد خاص',
    'پرسش\u200cها',
  ];

  /// The whole reading half of the page, indexed for the in-section search.
  ///
  /// The two trackers (رمضان، زکات فطر) are absent on purpose: they hold
  /// counters and a form, not prose, and a hit that lands on an empty field is a
  /// false promise. Everything a reader would go looking for is here — including
  /// مکروهات, which lives under «قضا و کفاره» and is easy to miss by scrolling.
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
      for (final row in SawmData.intro) ruling(2, 'آشنایی', row),
      for (final row in SawmData.conditions) ruling(2, 'آشنایی', row),
      for (final row in SawmData.arkan) ruling(3, 'ارکان و مبطلات', row),
      for (final row in SawmData.nullifiers) ruling(3, 'ارکان و مبطلات', row),
      for (final text in SawmData.doesNotNullify)
        item(3, 'ارکان و مبطلات', text),
      for (final row in SawmData.qadaKaffarah) ruling(4, 'قضا و کفاره', row),
      for (final row in SawmData.makruhatDetails) ruling(4, 'قضا و کفاره', row),
      for (final text in SawmData.sunan) item(5, 'سنن و آداب', text),
      for (final row in SawmData.specialCases) ruling(6, 'موارد خاص', row),
      for (final row in SawmData.contemporaryIssues)
        ruling(6, 'موارد خاص', row),
      for (final row in SawmData.faq)
        SectionSearchEntry(
          tab: 7,
          tabLabel: 'پرسش\u200cها',
          title: row['question'] as String? ?? '',
          body: row['answer'] as String? ?? '',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildSearchEntries();
    return SectionPage(
      id: 'fasting',
      title: 'روزه و رمضان',
      tabs: _tabs,
      searchEntries: entries.isEmpty ? null : entries,
      children: const [
        RamadanTrackerTab(),
        FitrZakatTab(),
        _IntroTab(),
        _ArkanNullifiersTab(),
        _QadaTab(),
        _SunanTab(),
        _SpecialTab(),
        _FaqTab(),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: INTRODUCTION
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
          icon: Icons.nights_stay_rounded,
          accent: FastingScreen._accent,
          title: 'آشنایی با روزه',
          subtitle:
              'شناخت جایگاه و اهمیت روزه در زندگی مسلمان — طبق مذهب شافعی',
        ),
        const SizedBox(height: 12),
        ...SawmData.intro.map((r) => RulingCard(
            title: (r['title'] ?? ''),
            body: (r['body'] ?? ''),
            icon: Icons.info_outline,
            iconColor: FastingScreen._accent)),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 28, color: FastingScreen._accent),
              const SizedBox(height: 8),
              Text(
                '«يَا أَيُّهَا الَّذِينَ آمَنُوا كُتِبَ عَلَيْكُمُ الصِّيَامُ كَمَا كُتِبَ عَلَى الَّذِينَ مِن قَبْلِكُمْ لَعَلَّكُمْ تَتَّقُونَ»',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 1.6,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text('بقره - 183',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'شرایط وجوب روزه',
            icon: Icons.checklist,
            accentColor: FastingScreen._accent,
            subtitle: '6 شرط برای وجوب روزه'),
        const SizedBox(height: 8),
        ...SawmData.conditions.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.conditions.length,
              accentColor: FastingScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'روزه بر هر مسلمانی واجب است که دارای شش شرط باشد. اگر کسی عمداً یکی از این شرایط را نقض کند، روزه‌اش باطل است.',
            color: FastingScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 3: ARKAN & NULLIFIERS
// ════════════════════════════════════════════════════════════════
class _ArkanNullifiersTab extends StatelessWidget {
  const _ArkanNullifiersTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const TabIntroCard(
          accent: FastingScreen._accent,
          icon: Icons.auto_awesome,
          title: 'ارکان و مبطلات روزه — هر آنچه باید در مورد ارکان و مفطرات بدانید',
        ),
        const SizedBox(height: 12),

        // ── 2 Arkan ──
        const SectionHeader(
            title: 'ارکان روزه (2 رکن)',
            icon: Icons.auto_awesome,
            accentColor: FastingScreen._accent,
            subtitle: 'ترک هر یک باعث بطلان روزه می‌شود'),
        const SizedBox(height: 8),
        ...SawmData.arkan.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.arkan.length,
              accentColor: FastingScreen._accent,
            )),
        const SizedBox(height: 16),

        // ── 7 Nullifiers ──
        const SectionHeader(
            title: 'مبطلات روزه (7 مُفطِر)',
            icon: Icons.cancel_outlined,
            accentColor: AppTheme.error,
            subtitle: 'کارهایی که روزه را باطل می‌کنند'),
        const SizedBox(height: 8),
        ...SawmData.nullifiers.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.nullifiers.length,
              accentColor: FastingScreen._accent,
              boxColor: AppTheme.error,
            )),
        const SizedBox(height: 12),

        // ── What does NOT nullify ──
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                      icon: Icons.check_circle_outline,
                      color: success,
                      size: 34),
                  const SizedBox(width: 10),
                  Text('مواردی که روزه را باطل نمی‌کنند',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: success)),
                ],
              ),
              const SizedBox(height: 10),
              ...SawmData.doesNotNullify.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: success)),
                        Expanded(
                            child: Text(item,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    color: t.textSecondary,
                                    height: 1.5))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'هر یک از مبطلات، اگر از روی فراموشی، اکراه، یا جهل انجام شود، روزه باطل نمی‌شود و قضا و کفاره واجب نیست.',
            color: FastingScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4: QADA, KAFFARAH, FIDYAH, MAKRUHAT
// ════════════════════════════════════════════════════════════════
class _QadaTab extends StatelessWidget {
  const _QadaTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const TabIntroCard(
          accent: FastingScreen._accent,
          icon: Icons.gavel_outlined,
          title: 'قضا، کفاره، فدیه و مکروهات روزه',
        ),
        const SizedBox(height: 12),

        // ── Qada, Kaffarah, Fidyah ──
        const SectionHeader(
            title: 'قضا و کفاره و فدیه',
            icon: Icons.scale_outlined,
            accentColor: FastingScreen._accent),
        const SizedBox(height: 8),
        ...SawmData.qadaKaffarah.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.qadaKaffarah.length,
              accentColor: FastingScreen._accent,
            )),
        const SizedBox(height: 16),

        // ── Makruhat ──
        const SectionHeader(
            title: 'مکروهات روزه',
            icon: Icons.thumb_down_outlined,
            accentColor: AppTheme.warning,
            subtitle: '8 مورد از مکروهات روزه'),
        const SizedBox(height: 8),
        ...SawmData.makruhatDetails.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.makruhatDetails.length,
              accentColor: AppTheme.warning,
              boxColor: AppTheme.warning,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'مکروهات کارهایی هستند که اگر روزه‌دار انجام دهد، ثواب روزه کاهش می‌یابد، ولی روزه باطل نمی‌شود.',
            color: FastingScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 5: SUNAN & ETIQUETTE
// ════════════════════════════════════════════════════════════════
class _SunanTab extends StatelessWidget {
  const _SunanTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const TabIntroCard(
          accent: FastingScreen._accent,
          icon: Icons.auto_awesome_outlined,
          title: 'سنن، مستحبات و آداب روزه — چگونه از رمضان بیشترین بهره را ببریم',
        ),
        const SizedBox(height: 12),
        const SectionHeader(
            title: 'سنن و مستحبات روزه',
            icon: Icons.star_outline,
            accentColor: FastingScreen._accent,
            subtitle: '11 سنت برای بهره‌برداری بیشتر'),
        const SizedBox(height: 8),
        CategoryListCard(
          title: 'آداب فردی و اجتماعی روزه',
          icon: Icons.auto_awesome_outlined,
          items: SawmData.sunan,
          accentColor: FastingScreen._accent,
        ),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                '«مَنْ صَامَ رَمَضَانَ إِيمَانًا وَاحْتِسَابًا غُفِرَ لَهُ مَا تَقَدَّمَ مِنْ ذَنْبِهِ» — پیامبر ﷺ',
            icon: Icons.auto_awesome,
            color: FastingScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 6: SPECIAL & CONTEMPORARY
// ════════════════════════════════════════════════════════════════
class _SpecialTab extends StatelessWidget {
  const _SpecialTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const TabIntroCard(
          accent: FastingScreen._accent,
          icon: Icons.healing_outlined,
          title: 'معذوران شرعی، مسائل معاصر، انواع روزه و اعتکاف',
        ),
        const SizedBox(height: 12),

        // ── Special Cases (Excused) ──
        const SectionHeader(
            title: 'معذوران شرعی',
            icon: Icons.healing_outlined,
            accentColor: FastingScreen._accent,
            subtitle: '8 گروه از معذوران در روزه'),
        const SizedBox(height: 8),
        ...SawmData.specialCases.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.specialCases.length,
              accentColor: FastingScreen._accent,
            )),
        const SizedBox(height: 16),

        // ── Contemporary Issues ──
        const SectionHeader(
            title: 'مسائل معاصر و نوظهور',
            icon: Icons.new_releases_outlined,
            accentColor: FastingScreen._accent,
            subtitle: 'احکام روزه در دنیای امروز'),
        const SizedBox(height: 8),
        ...SawmData.contemporaryIssues.asMap().entries.map((e) => NumberedCard(
              number: e.key + 1,
              title: (e.value['title'] ?? ''),
              body: (e.value['body'] ?? ''),
              total: SawmData.contemporaryIssues.length,
              accentColor: FastingScreen._accent,
            )),
        const SizedBox(height: 12),
        const InfoBox(
            text:
                'شب قدر از شب‌های دههٔ آخر رمضان است. عبادت در آن از هزار ماه بهتر است: «لَيْلَةُ الْقَدْرِ خَيْرٌ مِّنْ أَلْفِ شَهْرٍ»',
            icon: Icons.nightlight_round,
            color: FastingScreen._accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 7: FAQ
// ════════════════════════════════════════════════════════════════
class _FaqTab extends StatelessWidget {
  const _FaqTab();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        ...SawmData.faq.asMap().entries.map((e) => FaqCard(
            number: e.key + 1,
            question: (e.value['question'] ?? ''),
            answer: (e.value['answer'] ?? ''),
            total: SawmData.faq.length,
            accentColor: FastingScreen._accent)),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(
                      icon: Icons.auto_stories,
                      color: FastingScreen._accent,
                      size: 34),
                  const SizedBox(width: 10),
                  Text('خاتمه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: FastingScreen._accent)),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(SawmData.disclaimer,
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
