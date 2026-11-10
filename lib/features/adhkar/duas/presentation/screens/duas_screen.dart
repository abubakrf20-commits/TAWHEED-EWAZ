import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/features/adhkar/duas/duas.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/design_tokens.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_detail_screen.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_share_screen.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/hesn_intro_reader_screen.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

const Color _duaAccent = TopicHues.duas;

class DuasScreen extends ConsumerStatefulWidget {
  const DuasScreen({super.key});

  @override
  ConsumerState<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends ConsumerState<DuasScreen> {
  bool _isSearching = false;
  bool _favOnly = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(duasProvider);
    final allDuas = provider.duas;
    final favorites = provider.favorites;
    final categories = provider.categories;

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(favorites.length),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (provider.error.isNotEmpty && allDuas.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(favorites.length),
        body: FailureView(
          id: 'duas_load',
          title: 'بارگذاری ادعیه ناموفق بود',
          detail: 'دعاهای ذخیره‌شده و علاقه‌مندی‌های شما پاک نشده‌اند؛ '
              'فقط فهرست باز نشد.',
          onRetry: () => ref.read(duasProvider.notifier).build(),
          layout: FailureLayout.page,
        ),
      );
    }

    final filteredDuas =
        _searchQuery.isEmpty ? allDuas : allDuas.where(_matchesSearch).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(favorites.length),
      body: _isSearching
          ? _buildSearchResults(filteredDuas)
          : _buildCategorySections(
              context,
              allDuas,
              favorites,
              _favOnly ? const [] : categories,
              _favOnly ? const [] : provider.sections,
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(int favCount) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.primary(context),
      iconTheme: IconThemeData(color: AppColors.primary(context)),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'جستجو در حصن المسلم...',
                hintTextDirection: TextDirection.rtl,
                border: InputBorder.none,
                fillColor: AppColors.surfaceAlt(context),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'پاک کردن جستجو',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 16)),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : Center(
              child: Text('حصن المسلم',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary(context)))),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'بستن جستجو',
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          )
        else
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'جستجو در ادعیه',
            onPressed: () => setState(() => _isSearching = true),
          ),
        if (!_isSearching && favCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              // Tapping filters the list to the favorites section; tapping
              // again restores the full book.
              child: InkWell(
                onTap: () => setState(() => _favOnly = !_favOnly),
                borderRadius: BorderRadius.circular(20),
                child: Tooltip(
                  message:
                      _favOnly ? 'نمایش همه ابواب' : 'نمایش فقط علاقه‌مندی‌ها',
                  child: Badge(
                    backgroundColor: _favOnly ? AppColors.error(context) : null,
                    label: Text('$favCount'),
                    child: Icon(
                      _favOnly ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                      color: _favOnly ? AppColors.error(context) : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      bottom: _isSearching && _searchQuery.isNotEmpty
          ? PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_filteredCount()} نتیجه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: AppColors.textSecondary(context),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            )
          : null,
    );
  }

  int _filteredCount() {
    return ref.read(duasProvider).duas.where(_matchesSearch).length;
  }

  bool _matchesSearch(DuaModel d) {
    if (_searchQuery.isEmpty) return true;

    final raw = _searchQuery.trim().toLowerCase();

    // «باب 12» / «12» style lookups jump to the bab number.
    final digits = toAsciiDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final n = int.tryParse(digits);
      if (n != null && n >= 1 && n <= 132 && d.chapterNo == n) return true;
    }

    final q = normalizeForSearch(raw);
    if (q.isEmpty) return false;
    if (normalizeForSearch(d.title).contains(q)) return true;
    if (normalizeForSearch(d.arabicText).contains(q)) return true;
    if (normalizeForSearch(d.translation).contains(q)) return true;
    if (normalizeForSearch(d.lead).contains(q)) return true;
    for (final text in [
      ...d.words,
      ...d.guidance,
      ...d.benefits,
      ...d.refs,
    ]) {
      if (normalizeForSearch(text).contains(q)) return true;
    }
    return false;
  }

  Widget _buildSearchResults(List<DuaModel> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: AppColors.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              'نتیجه‌ای برای "$_searchQuery" یافت نشد',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 16),
                color: AppColors.textSecondary(context),
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) => _DuaCard(
        dua: results[index],
        showCategory: true,
        query: _searchQuery.trim(),
      ),
    );
  }

  Widget _buildCategorySections(
    BuildContext context,
    List<DuaModel> allDuas,
    List<DuaModel> favorites,
    List<String> categories,
    List<HesnSection> intros,
  ) {
    if (allDuas.isEmpty) {
      // Two states, two statements. «هنوز علاقه‌مندی‌ای ثبت نشده» is a real
      // answer and has nothing to retry; «محتوای حصن المسلم در دسترس نیست» is
      // the content failing to arrive, and does.
      if (_favOnly && favorites.isEmpty) {
        return const AppEmptyState(
          icon: Icons.favorite_border_rounded,
          message: 'هنوز علاقه‌مندی‌ای ثبت نشده',
          subtitle: 'روی قلب کنار هر دعا بزنید تا اینجا بماند.',
        );
      }
      return FailureView(
        id: 'duas_content',
        title: 'محتوای حصن المسلم در دسترس نیست',
        detail: 'متن ادعیه همراه برنامه ذخیره می‌شود، پس این خطا با اینترنت '
            'درست نمی‌شود. با تلاش دوباره دوباره خوانده می‌شود.',
        onRetry: () => ref.read(duasProvider.notifier).build(),
        layout: FailureLayout.page,
      );
    }

    // Pre-compute category sections for lazy rendering
    final sections = <_CategorySectionData>[];
    if (favorites.isNotEmpty) {
      sections.add(_CategorySectionData(
        title: 'علاقه‌مندی‌ها',
        duas: favorites,
        initiallyExpanded: true,
      ));
    }
    for (final cat in categories) {
      final catDuas = allDuas.where((d) => d.category == cat).toList();
      if (catDuas.isNotEmpty) {
        final bab = catDuas.first.chapterNo;
        sections.add(_CategorySectionData(
          title: cat,
          duas: catDuas,
          babNumber: bab > 0 ? bab : null,
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sections.length + (intros.isEmpty ? 0 : 1) + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DuaHeroHeader(
              totalDuas: allDuas.length, favoritesCount: favorites.length);
        }
        if (intros.isNotEmpty && index == 1) {
          return _IntrosSection(sections: intros);
        }
        final section = sections[intros.isEmpty ? index - 1 : index - 2];
        return _ChapterBox(
          title: section.title,
          duas: section.duas,
          count: section.duas.length,
          initiallyExpanded: section.initiallyExpanded,
          isFavorites: section.babNumber == null,
          babNumber: section.babNumber,
        );
      },
    );
  }
}

class _CategorySectionData {
  final String title;
  final List<DuaModel> duas;
  final bool initiallyExpanded;

  /// Real book bab number (1..132); null for the favorites pseudo-section.
  final int? babNumber;
  _CategorySectionData(
      {required this.title,
      required this.duas,
      this.initiallyExpanded = false,
      this.babNumber});
}

/// Collapsible «مقدمات کتاب» section listing the book's front-matter
/// sections; tapping one opens the full-text reader.
class _IntrosSection extends StatefulWidget {
  final List<HesnSection> sections;
  const _IntrosSection({required this.sections});

  @override
  State<_IntrosSection> createState() => _IntrosSectionState();
}

class _IntrosSectionState extends State<_IntrosSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: AnimatedContainer(
            duration: DesignTokens.fastAnim,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isExpanded
                  ? AppColors.primary(context)
                      .withValues(alpha: isDark ? 0.12 : 0.05)
                  : AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isExpanded
                    ? AppColors.primary(context)
                        .withValues(alpha: isDark ? 0.35 : 0.2)
                    : AppColors.outline(context).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context)
                        .withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 17,
                    color: AppColors.primary(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مقدمات کتاب',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14.5),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context)
                        .withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.sections.length}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: DesignTokens.fastAnim,
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: DesignTokens.medAnim,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final s in widget.sections)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              // Wrapped in the ambient background: these pages
                              // paint a transparent Scaffold and take their paper
                              // from the GoRouter branch, which a raw push leaves.
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AmbientBackground(
                                    child: HesnIntroReaderScreen(section: s),
                                  ),
                                ),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.outline(context)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.article_outlined,
                                      size: 18,
                                      color: AppColors.primary(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        s.title,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: AppTheme.scaledFontSize(
                                              context, 13.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_left,
                                      size: 18,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DuaHeroHeader extends StatelessWidget {
  final int totalDuas;
  final int favoritesCount;
  const _DuaHeroHeader({required this.totalDuas, required this.favoritesCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        // Flat identity tone — the section's teal, with a darker face in the
        // dark theme so the white copy keeps its contrast.
        color: isDark ? const Color(0xFF0D3B33) : const Color(0xFF00695C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            size: 26, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'حصن المسلم',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 18),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'دعاهای محافظت روزانه',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _HeroStat(
                        icon: Icons.auto_stories,
                        value: '$totalDuas',
                        label: 'دعا',
                      ),
                      const SizedBox(width: 8),
                      _HeroStat(
                        icon: Icons.favorite,
                        value: '$favoritesCount',
                        label: 'علاقه‌مندی',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Text(
              '$value $label',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bab (topic) rendered as a single unified cream box: header strip with
/// the bab number badge, and — when expanded — its dhikr items listed one by
/// one inside the same box, separated by thin dividers.
class _ChapterBox extends StatefulWidget {
  final String title;
  final List<DuaModel> duas;
  final int count;
  final bool initiallyExpanded;
  final bool isFavorites;
  final int? babNumber;

  const _ChapterBox({
    required this.title,
    required this.duas,
    required this.count,
    this.initiallyExpanded = false,
    this.isFavorites = false,
    this.babNumber,
  });

  @override
  State<_ChapterBox> createState() => _ChapterBoxState();
}

class _ChapterBoxState extends State<_ChapterBox> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same palette as the «مقدمات کتاب» section: themed card + primary tint.
    final accent = AppColors.primary(context);
    final badgeBg = accent.withValues(alpha: isDark ? 0.25 : 0.1);
    final borderColor = AppColors.outline(context).withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: widget.isFavorites || widget.babNumber == null
                          ? Icon(Icons.favorite,
                              size: 16,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.error(context))
                          : Text(
                              '${widget.babNumber}',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize:
                                    AppTheme.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: DesignTokens.fastAnim,
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Items listed one by one beneath the header, in the same box
            AnimatedSize(
              duration: DesignTokens.medAnim,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      children: [
                        for (var i = 0; i < widget.duas.length; i++)
                          _ChapterItemRow(
                            dua: widget.duas[i],
                            seq: i + 1,
                            showTopDivider: i > 0,
                          ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single dhikr row inside a [_ChapterBox]: ONE compact line showing just
/// the opening words of the dhikr (like the book's intro rows). Tapping opens
/// the full reader with متن + ترجمه + شرح.
class _ChapterItemRow extends StatelessWidget {
  final DuaModel dua;
  final int seq;
  final bool showTopDivider;

  const _ChapterItemRow({
    required this.dua,
    required this.seq,
    this.showTopDivider = false,
  });

  String get _snippet {
    final raw =
        dua.arabicText.trim().isNotEmpty ? dua.arabicText : dua.translation;
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    // Same palette as the «مقدمات کتاب» section.
    final accent = AppColors.primary(context);
    final divider = AppColors.outline(context).withValues(alpha: 0.25);
    final chipBg = accent.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) Divider(color: divider, height: 1, indent: 14),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AmbientBackground(child: DuaDetailScreen(dua: dua)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$seq',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Calibri',
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                if (dua.hasCommentary) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 15,
                    color: accent.withValues(alpha: 0.55),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: AppColors.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DuaCard extends ConsumerWidget {
  final DuaModel dua;
  final bool showCategory;

  /// The word this card was found for, when it is rendered as a search
  /// result: the detail page must paint it, not just open the dua.
  final String query;

  const _DuaCard(
      {required this.dua, this.showCategory = false, this.query = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final largeArabicFont = ref.watch(largeArabicFontProvider);
    final showArabicText = ref.watch(showArabicTextProvider);
    final showDaleel = ref.watch(showDaleelProvider);
    final arabicFontSize = largeArabicFont ? 22.0 : 18.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0x33FFFFFF)
                : _duaAccent.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AmbientBackground(
                child: DuaDetailScreen(dua: dua, highlightQuery: query),
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _duaAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (showCategory && (dua.category?.isNotEmpty ?? false))
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _duaAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dua.category ?? '',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w600,
                            color: _duaAccent,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        dua.title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 18),
                      tooltip: 'اشتراک‌گذاری',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AmbientBackground(child: DuaShareScreen(dua: dua)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(
                        dua.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: dua.isFavorite
                            ? AppColors.error(context)
                            : AppColors.textMuted(context),
                        size: 20,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: dua.isFavorite
                          ? 'حذف از علاقه‌مندی‌ها'
                          : 'افزودن به علاقه‌مندی‌ها',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(duasProvider.notifier).toggleFavorite(dua.id);
                      },
                    ),
                  ],
                ),
                if (showArabicText && dua.arabicText.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _duaAccent.withValues(alpha: isDark ? 0.08 : 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        right: BorderSide(
                            color: _duaAccent.withValues(alpha: 0.7), width: 3),
                      ),
                    ),
                    child: Text(
                      dua.arabicText,
                      style: TextStyle(
                        fontSize: arabicFontSize,
                        fontFamily: 'Amiri',
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
                if (dua.translation.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    dua.translation,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      fontFamily: AppTheme.fontFamily,
                      color: AppColors.textSecondary(context),
                      height: 1.7,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
                if (showDaleel && dua.source.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _duaAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book,
                            size: 12, color: _duaAccent),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            dua.source,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 10.5),
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w600,
                              color: _duaAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
