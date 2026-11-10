import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';
import 'package:tawheeed/features/education/presentation/widgets/science_card.dart';

class SciencesHomeScreen extends StatefulWidget {
  const SciencesHomeScreen({super.key});

  @override
  State<SciencesHomeScreen> createState() => _SciencesHomeScreenState();
}

class _SciencesHomeScreenState extends State<SciencesHomeScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await SciencesContent.load();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final t = TimeThemeKit.of(context).palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'علوم اسلامی',
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: 20, color: t.primary),
            tooltip: 'جستجوی علوم',
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: _buildHome(),
    );
  }

  Widget _buildHome() {
    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: DsSpacing.page, vertical: 12),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        ...SciencesContent.categoryOrder.map((cat) {
          final sciences = SciencesContent.byCategory(cat);
          if (sciences.isEmpty) return const SizedBox.shrink();
          return ScienceCategoryCard(
            category: cat,
            sciences: sciences,
            onScienceTap: (science) => _openScience(context, science),
          );
        }),
      ],
    );
  }

  /// HERO — solid dark token card (flat decision for the hub): no gradient.
  Widget _buildHero() {
    final p = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.heroMid,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DuotoneIconTile(
                  accent: AppPalette.heroGoldDeep,
                  icon: Icons.school_outlined,
                  size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${SciencesContent.all.length} علم اسلامی',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w500,
                            color: p.heroInk)),
                    Text(
                        '${SciencesContent.categoryOrder.length} دسته · از بنیادین تا کاربردی',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            color: p.heroInk.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // SEARCH AFFORDANCE — glass-white pill on the solid dark hero.
          InkWell(
            onTap: () => _showSearch(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text('جستجوی علوم...',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: _ScienceSearchDelegate());
  }

  void _openScience(BuildContext context, ScienceData science) {
    // GoRouter, not Navigator.push: the `/sciences/:id` route is wrapped in the
    // ambient background, whereas a raw MaterialPageRoute pops outside the
    // router and leaves the transparent scaffold painting the bare window.
    context.push(RouteNames.scienceDetailPath(science.id));
  }
}

class _ScienceSearchDelegate extends SearchDelegate<String?> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'پاک کردن جستجو',
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, size: 20),
        tooltip: 'بازگشت',
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final results = query.isEmpty
        ? SciencesContent.all
        : SciencesContent.all.where((s) => s.matchesSearch(query)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: results.map((s) {
        final snippet = _findSnippet(s, query);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          // Per-item emoji replaced by the group's duotone glyph — the same
          // treatment the category tiles use; semantically labelled for
          // TalkBack with the science title itself.
          leading: Semantics(
            label: s.title,
            child: DuotoneIconTile(
                accent: SciencesContent.accentOf(s.category),
                icon: SciencesContent.glyphOf(s.category)),
          ),
          title: _ScienceResultTitle(science: s),
          subtitle: snippet.isNotEmpty
              ? Text(snippet,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
              : Text(s.category.label,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11))),
          trailing: Icon(Icons.chevron_left, size: 18, color: t.textMuted),
          onTap: () {
            // Capture the router before closing the search page: the delegate's
            // context is torn down by close(), and a Navigator.push here would
            // leave the router (and the ambient background) behind.
            final router = GoRouter.of(context);
            close(context, null);
            router.push(RouteNames.scienceDetailPath(s.id));
          },
        );
      }).toList(),
    );
  }

  String _findSnippet(ScienceData s, String q) {
    return s.findSnippet(q) ?? '';
  }
}

class _ScienceResultTitle extends StatelessWidget {
  final ScienceData science;
  const _ScienceResultTitle({required this.science});

  @override
  Widget build(BuildContext context) {
    // The «به‌زودی» badge wears the science's own category hue, like the
    // tiles on the category cards.
    final accent = SciencesContent.accentOf(science.category);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(science.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w600)),
        ),
        if (!science.isComplete) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'به‌زودی',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 9),
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
