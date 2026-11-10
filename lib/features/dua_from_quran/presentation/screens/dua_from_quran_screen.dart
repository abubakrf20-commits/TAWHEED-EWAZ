import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/dua_from_quran/data/dua_from_quran_data.dart';
import 'package:tawheeed/features/dua_from_quran/domain/entities/dua_from_quran_entity.dart';
import 'package:tawheeed/features/dua_from_quran/presentation/screens/dua_from_quran_share_screen.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/shared/utils/favorites_store.dart';

/// Fixed green accent for «دعا» — never follows the theme preset.
Color _accentFor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? Color.lerp(TopicHues.dua, Colors.white, 0.35) ?? TopicHues.dua
      : TopicHues.dua;
}

class DuaFromQuranScreen extends StatelessWidget {
  const DuaFromQuranScreen({super.key});

  static const List<String> _tabs = [
    'دعاها',
    'احکام و آداب و فضیلت',
  ];

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      id: 'dua',
      title: 'دعا',
      tabs: _tabs,
      children: const [
        _DuasTab(),
        _RulingsEtiquetteVirtueTab(),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  Tab 1: دعاها
// ═══════════════════════════════════════════
class _DuasTab extends StatefulWidget {
  const _DuasTab();

  @override
  State<_DuasTab> createState() => _DuasTabState();
}

class _DuasTabState extends State<_DuasTab> {
  static const _favKey = 'dua_quran_favorite_keys';

  Set<String> _favorites = {};
  bool _favOnly = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    FavoritesStore.load(_favKey).then((ids) {
      if (mounted) setState(() => _favorites = ids);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(String key) async {
    final next = await FavoritesStore.toggle(_favKey, key);
    if (mounted) setState(() => _favorites = next);
  }

  bool _matches(DuaFromQuran d) {
    final q = normalizeForSearch(_query.trim().toLowerCase());
    if (q.isEmpty) return true;
    return normalizeForSearch(d.arabic.toLowerCase()).contains(q) ||
        normalizeForSearch(d.persian.toLowerCase()).contains(q) ||
        normalizeForSearch(d.source.toLowerCase()).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;

    bool keep(String key) => !_favOnly || _favorites.contains(key);

    final quranMatch = DuaFromQuranData.quranDuas.where(_matches).toList();
    final sunnahMatch = DuaFromQuranData.sunnahDuas.where(_matches).toList();
    final searching = _query.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bannerCard(context, isDark, 'دعاهای از قرآن کریم و سنت نبوی',
            Icons.auto_awesome),
        const SizedBox(height: 16),
        // جستجو در متن عربی، ترجمه و منبع.
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'جستجو در دعاها...',
            hintTextDirection: TextDirection.rtl,
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: searching
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'پاک کردن جستجو',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14)),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        // علاقه‌مندی‌ها filter.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChip(
            label: Text('علاقه‌مندی‌ها (${_favorites.length})',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700)),
            selected: _favOnly,
            onSelected: (v) => setState(() => _favOnly = v),
            selectedColor: TopicHues.dua.withValues(alpha: 0.2),
            checkmarkColor: TopicHues.dua,
          ),
        ),
        const SizedBox(height: 10),
        if (searching && quranMatch.isEmpty && sunnahMatch.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('نتیجه‌ای یافت نشد',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      color: t.textMuted)),
            ),
          ),
        if (quranMatch.isNotEmpty) ...[
          _duaSectionHeader(context, isDark, 'دعاهایی از قرآن کریم',
              Icons.menu_book, '${quranMatch.length} دعا'),
          const SizedBox(height: 10),
          ...quranMatch.asMap().entries.map((entry) {
            final key = 'q_${entry.value.stableId}';
            if (!keep(key)) return const SizedBox.shrink();
            return _buildDuaCard(context, isDark, entry.value, entry.key + 1,
                isFavorite: _favorites.contains(key),
                onToggleFavorite: () => _toggleFavorite(key));
          }),
        ],
        if (sunnahMatch.isNotEmpty) ...[
          const SizedBox(height: 20),
          _duaSectionHeader(context, isDark, 'دعاهایی از سنت نبوی',
              Icons.auto_awesome, '${sunnahMatch.length} دعا'),
          const SizedBox(height: 10),
          ...sunnahMatch.asMap().entries.map((entry) {
            final key = 's_${entry.value.stableId}';
            if (!keep(key)) return const SizedBox.shrink();
            return _buildDuaCard(context, isDark, entry.value, entry.key + 1,
                isFavorite: _favorites.contains(key),
                onToggleFavorite: () => _toggleFavorite(key));
          }),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  Tab 2: احکام و آداب و فضیلت
// ═══════════════════════════════════════════
class _RulingsEtiquetteVirtueTab extends StatelessWidget {
  const _RulingsEtiquetteVirtueTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(context, isDark, 'احکام دعا', Icons.gavel),
        const SizedBox(height: 12),
        _infoCard(
            context,
            isDark,
            'حکم دعا',
            'دعا عبادتی است که در قرآن و سنت به آن امر شده است. خداوند متعال فرموده:\n\n«وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ ۚ إِنَّ الَّذِينَ يَسْتَكْبِرُونَ عَنْ عِبَادَتِي سَيَدْخُلُونَ جَهَنَّمَ دَاخِرِينَ» (غافر: 60)',
            Icons.book),
        _infoCard(
            context,
            isDark,
            'شرایط استجابت دعا',
            '1) اخلاص در دعا (برای خدا باشد)\n2) صبر بر دعا و عجله نکردن\n3) ترک گناه و توبه\n4) حلال بودن مال و غذا\n5) حضور قلب و تضرع\n6) دعا در اوقات استجابت\n7) یقین به اجابت',
            Icons.checklist),
        _infoCard(
            context,
            isDark,
            'مکروهات دعا',
            '1) دعا برای گناه و قطع رحم\n2) دعای بر ضرر دیگران\n3) تکرار بی‌حضور قلب\n4) عجله در استجابت\n5) تجاوز در دعا (درخواست محال)',
            Icons.warning),
        _infoCard(
            context,
            isDark,
            'دعا برای دیگران',
            'پیامبر ﷺ فرمود:\n«مَا مِنْ مُسْلِمٍ يَدْعُو لِأَخِيهِ بِظَهْرِ الْغَيْبِ إِلَّا قَالَ الْمَلَكُ وَلَكَ بِمِثْلٍ»\n(هیچ مسلمانی نیست که برای برادرش در غیابش دعا کند مگر اینکه فرشته بگوید: و برای تو هم مثل آن) (مسلم)',
            Icons.group),
        const SizedBox(height: 24),
        _sectionHeader(context, isDark, 'آداب دعا', Icons.abc),
        const SizedBox(height: 12),
        _infoCard(
            context,
            isDark,
            'ادب شروع دعا',
            '1) حمد و ثنای خدا\n2) صلوات بر پیامبر ﷺ\n3) اعتراف به گناهان\n4) ذکر نعمت‌های خدا\n5) تضرع و خشوع',
            Icons.abc),
        _infoCard(
            context,
            isDark,
            'حضور قلب و تضرع',
            '1) توجه کامل به خدا\n2) درک معنی دعا\n3) امید به رحمت و ترس از عذاب\n4) صدای آرام و ملایم\n5) گریه از ترس خدا\n\nپیامبر ﷺ فرمود:\n«ادْعُوا اللَّهَ وَأَنْتُمْ مُوقِنُونَ بِالْإِجَابَةِ»\n(خدا را بخوانید در حالی که به استجابت یقین دارید)\n\n(ابو داود)',
            Icons.favorite_border),
        _infoCard(
            context,
            isDark,
            'دعا در نماز',
            'دعا در نماز:\n\n1) دعا در سجده مستحب است\n2) دعا بین دو سجده مستحب است\n3) دعا در قنوت (در نماز وتر) مستحب است\n4) دعا بعد از تشهد مستحب است\n\nپیامبر ﷺ فرمود:\n«أَقْرَبُ مَا يَكُونُ الرَّبُّ مِنَ الْعَبْدِ فِيْ السَّجْدَةِ فَأَكْثِرُوا الدُّعَاءَ فِيهَا»\n(نزدیک‌ترین حال بنده به خدا در سجده است پس در آن زیاد دعا کنید) (مسلم)',
            Icons.mosque),
        _infoCard(
            context,
            isDark,
            'آداب مکان و زمان',
            '1) رو به قبله\n2) در مساجد\n3) بلند کردن دستها\n4) تکرار سه بار (مستحب)\n5) دعا به هر زبانی صحیح است',
            Icons.place),
        const SizedBox(height: 24),
        _sectionHeader(context, isDark, 'فضیلت دعا', Icons.star),
        const SizedBox(height: 12),
        _infoCard(
            context,
            isDark,
            'دعا عبادت است',
            'پیامبر اکرم ﷺ فرمود:\n\n«الدُّعَاءُ هُوَ الْعِبَادَةُ»\n(دعا عبادت است) (ابو داود، ترمذی)\n\nدعا بالاترین عبادت و نشانه توکل به خداست.',
            Icons.mosque),
        _infoCard(
            context,
            isDark,
            'دعا سلاح مؤمن',
            'پیامبر ﷺ فرمود:\n\n«الدُّعَاءُ مُخُّ الْعِبَادَةِ»\n(دعا مغز عبادت است) (ترمذی)\n\nخداوند فرموده:\n«قُلْ مَا يَعْبَأُ بِكُمْ رَبِّي لَوْلَا دُعَاؤُكُمْ»\n(بگو اگر دعای شما نباشد پروردگارم به شما اعتنا نمی‌کند) (فرقان: 77)',
            Icons.shield),
        _infoCard(
            context,
            isDark,
            'صبر در دعا',
            'پیامبر ﷺ فرمود:\n\n«يُسْتَجَابُ لِأَحَدِكُمْ مَا لَمْ يَعْجَلْ»\n(دعای شما مستجاب می‌شود مگر اینکه عجله کنید و بگویید دعا کردم ولی مستجاب نشد) (ابو داود)',
            Icons.hourglass_empty),
        const SizedBox(height: 24),
        _sectionHeader(context, isDark, 'اوقات استجابت دعا', Icons.access_time),
        const SizedBox(height: 12),
        _infoCard(
            context,
            isDark,
            'آخر شب (سوم آخر)',
            'خداوند هر شب در ثلث آخر به آسمان دنیا نازل می‌شود و می‌فرماید:\n«مَنْ يَدْعُونِي فَأَسْتَجِيبَ لَهُ مَنْ يَسْأَلُنِي فَأُعْطِيَهُ مَنْ يَسْتَغْفِرُنِي فَأَغْفِرَ لَهُ»\n(چه کسی مرا می‌خواند تا اجابت کنم) (بخاری و مسلم)',
            Icons.nightlight_round),
        _infoCard(
            context,
            isDark,
            'بین اذان و اقامه',
            'پیامبر ﷺ فرمود:\n\n«الدُّعَاءُ بَيْنَ الْأَذَانِ وَالْإِقَامَةِ لَا يُرَدُّ»\n(دعا بین اذان و اقامه رد نمی‌شود) (ابو داود)',
            Icons.access_time),
        _infoCard(
            context,
            isDark,
            'سجده نماز',
            'پیامبر ﷺ فرمود:\n\n«أَقْرَبُ مَا يَكُونُ الرَّبُّ مِنَ الْعَبْدِ فِيْ السَّجْدَةِ فَأَكْثِرُوا الدُّعَاءَ فِيهَا»\n(نزدیک‌ترین حال بنده به خدا در سجده است پس در آن زیاد دعا کنید) (مسلم)',
            Icons.arrow_downward),
        _infoCard(
            context,
            isDark,
            'روز جمعه',
            'در روز جمعه ساعتی است که دعا رد نمی‌شود. پیامبر ﷺ فرمود:\n\n«فِيهِ سَاعَةٌ لَا يُوَافِقُهَا عَبْدٌ مُسْلِمٌ وَهُوَ قَائِمٌ يُصَلِّي يَسْأَلُ اللَّهَ شَيْئًا إِلَّا أَعْطَاهُ إِيَّاهُ»\n(بخاری و مسلم)\n\nبیشتر علماء می‌گویند این ساعت بعد از عصر تا غروب آفتاب است.',
            Icons.wb_sunny),
        _infoCard(
            context,
            isDark,
            'ماه رمضان و شب قدر',
            '1) ماه رمضان بهترین ماه برای دعا\n2) دعای روزه‌دار رد نمی‌شود\n3) دعا هنگام افطار مستجاب است\n4) شب قدر بهتر از هزار ماه\n\nپیامبر ﷺ فرمود:\n«ثَلَاثَةٌ لَا تُرَدُّ دَعْوَتُهُمْ: الصَّائِمُ حَتَّى يُفْطِرَ، وَالْإِمَامُ الْعَادِلُ، وَدَعْوَةُ الْمَظْلُومِ»\n(سه گروه دعایشان رد نمی‌شود: روزه‌دار تا افطار کند، امام عادل، دعای مظلوم) (ترمذی)',
            Icons.nightlight_round),
        _infoCard(
            context,
            isDark,
            'هنگام نزول باران',
            'پیامبر ﷺ فرمود:\n\n«ثنتان لا تردان: الدعاء عند النداء، و تحت المطر»\n(دو چیز رد نمی‌شود: دعا هنگام اذان، و دعا زیر باران)',
            Icons.water_drop),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  Shared Widgets
// ═══════════════════════════════════════════

Widget _bannerCard(
    BuildContext context, bool isDark, String title, IconData icon) {
  final t = TimeThemeKit.of(context).palette;
  final accentColor = _accentFor(context);
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: isDark ? 0.09 : 0.06),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: accentColor),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 17),
            fontWeight: FontWeight.w800,
            color: t.textPrimary,
            fontFamily: AppTheme.fontFamily,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _sectionHeader(
    BuildContext context, bool isDark, String title, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: (_accentFor(context)).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (_accentFor(context)).withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: _accentFor(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: _accentFor(context),
                  fontFamily: AppTheme.fontFamily)),
        ),
      ],
    ),
  );
}

Widget _infoCard(BuildContext context, bool isDark, String title,
    String content, IconData icon) {
  final t = TimeThemeKit.of(context).palette;
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? t.outline.withValues(alpha: 0.3)
            : t.outline.withValues(alpha: 0.5),
        width: 0.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (_accentFor(context)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _accentFor(context)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                      fontFamily: AppTheme.fontFamily)),
            ),
            IconButton(
              icon: Icon(Icons.copy,
                  size: 16, color: t.textMuted),
              tooltip: 'کپی دعا',
              onPressed: () {
                ShareService.copyText(context, '$title\n$content');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 13),
            fontWeight: FontWeight.w400,
            color: t.textSecondary,
            fontFamily: AppTheme.fontFamily,
            height: 1.8,
          ),
        ),
      ],
    ),
  );
}

Widget _duaSectionHeader(BuildContext context, bool isDark, String title,
    IconData icon, String count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: (_accentFor(context)).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (_accentFor(context)).withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: _accentFor(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  color: _accentFor(context),
                  fontFamily: AppTheme.fontFamily)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (_accentFor(context)).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(count,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: _accentFor(context))),
        ),
      ],
    ),
  );
}

Widget _buildDuaCard(
  BuildContext context,
  bool isDark,
  DuaFromQuran dua,
  int number, {
  required bool isFavorite,
  required VoidCallback onToggleFavorite,
}) {
  final t = TimeThemeKit.of(context).palette;
  final accentColor = _accentFor(context);
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: isDark ? 0.07 : 0.04),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: accentColor.withValues(alpha: isDark ? 0.2 : 0.15),
        width: 0.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$number',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: accentColor)),
              ),
            ),
            if (dua.source.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 12, color: accentColor),
                    const SizedBox(width: 4),
                    Text(dua.source,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: accentColor)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: isFavorite
                      ? Colors.red.shade400
                      : t.textMuted),
              tooltip: 'علاقه‌مندی',
              onPressed: onToggleFavorite,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.share,
                  size: 16, color: t.textMuted),
              tooltip: 'اشتراک‌گذاری',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DuaFromQuranShareScreen(dua: dua, number: number)),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.copy,
                  size: 16, color: t.textMuted),
              tooltip: 'کپی دعا',
              onPressed: () {
                ShareService.copyText(context,
                    '${dua.arabic}\n${dua.persian}\nمنبع: ${dua.source}');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          dua.arabic,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 22),
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE8D5A0) : const Color(0xFF1B5E20),
            fontFamily: AppTheme.fontFamily,
            height: 2.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dua.persian,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 15),
            fontWeight: FontWeight.w400,
            color: t.textSecondary,
            fontFamily: AppTheme.fontFamily,
            height: 2.0,
          ),
        ),
      ],
    ),
  );
}
