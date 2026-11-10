import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_share_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/widgets/hadeeth_share_card.dart';
import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/favorites_store.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// Detail screen of one موسوعه احادیث entry.
///
/// All content (Arabic text, ترجمه، منبع، صحت، شرح و نکات حدیث) lives inside
/// one unified cream card — exactly like the share-image card. When
/// [sequence] is known (opened from the encyclopedia list) the bottom bar
/// lets the user step to the previous/next hadith without going back.
class HadeethEncDetailScreen extends StatefulWidget {
  final HadeethEncHadith hadith;

  /// 1-based position of this hadith in the encyclopedia list; when null the
  /// raw source id is shown instead.
  final int? sequence;

  /// Literal matched by a More deep-search hit; shaded on arrival. Cleared as
  /// soon as the reader steps to another hadith via the bottom bar.
  final String highlightQuery;

  const HadeethEncDetailScreen(
      {super.key,
      required this.hadith,
      this.sequence,
      this.highlightQuery = ''});

  @override
  State<HadeethEncDetailScreen> createState() => _HadeethEncDetailScreenState();
}

class _HadeethEncDetailScreenState extends State<HadeethEncDetailScreen> {
  late HadeethEncHadith _hadith;
  late int? _sequence;
  late String _highlight;
  int _total = 0;
  bool _loadingAdjacent = false;
  bool _isFav = false;

  /// Anchors the FIRST block of the card that carries the searched word, so a
  /// long hadith opens on its word instead of at the Arabic text.
  final _matchAnchor = GlobalKey();

  static const _favKey = 'hadeeth_enc_favorite_ids';

  @override
  void initState() {
    super.initState();
    _hadith = widget.hadith;
    // The real encyclopedia number from the database wins over the optional
    // route hint so search/favorites/topic entries never show a wrong number.
    _sequence = _hadith.sequence ?? widget.sequence;
    _highlight = widget.highlightQuery;
    if (_highlight.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _matchAnchor.currentContext;
        if (!mounted || ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
    if (_sequence != null) _loadTotal();
    FavoritesStore.load(_favKey).then((ids) {
      if (mounted) setState(() => _isFav = ids.contains('${_hadith.id}'));
    });
  }

  Future<void> _toggleFavorite() async {
    final next = await FavoritesStore.toggle(_favKey, '${_hadith.id}');
    if (mounted) setState(() => _isFav = next.contains('${_hadith.id}'));
  }

  Future<void> _loadTotal() async {
    try {
      final c = await HadeethEncDbService().getCount();
      if (mounted && c > 0) setState(() => _total = c);
    } catch (_) {
      AppLogger.warning('hadeeth_enc_detail_screen', 'operation failed');
    }
  }

  bool get _canPrev => _sequence != null && _sequence! > 1 && !_loadingAdjacent;

  bool get _canNext =>
      _sequence != null &&
      _total > 0 &&
      _sequence! < _total &&
      !_loadingAdjacent;

  Future<void> _goTo(int seq) async {
    if (_loadingAdjacent) return;
    setState(() => _loadingAdjacent = true);
    try {
      final id = await HadeethEncDbService().getHadithIdAt(seq - 1);
      final h = id == null ? null : await HadeethEncDbService().getHadith(id);
      if (!mounted) return;
      if (h == null) return;
      setState(() {
        _hadith = h;
        _sequence = h.sequence ?? seq;
        _highlight = '';
        _loadingAdjacent = false;
      });
      FavoritesStore.load(_favKey).then((ids) {
        if (mounted) setState(() => _isFav = ids.contains('${h.id}'));
      });
    } catch (_) {
      AppLogger.warning('hadeeth_enc_detail_screen', 'operation failed');
      if (!mounted) return;
      setState(() => _loadingAdjacent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'حدیث ${_sequence ?? _hadith.id}',
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                size: 20, color: _isFav ? Colors.red.shade400 : null),
            tooltip: 'علاقه‌مندی',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'کپی متن',
            onPressed: () {
              ShareService.copyText(
                  context, '${_hadith.textAr}\n\n${_hadith.text}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            tooltip: 'ارسال حدیث',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    HadeethEncShareScreen(hadith: _hadith, sequence: _sequence),
              ));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 8, DsSpacing.page, 32),
        children: [
          // One unified card for everything — same design as the share image.
          HadeethShareCard(
            hadith: _hadith,
            sequence: _sequence,
            showBranding: false,
            highlightQuery: _highlight,
            matchAnchor: _matchAnchor,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 15, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'منبع: موسوعه الأحادیث النبویة — HadeethEnc.com (نسخه فارسی v1.30)',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : accent.withValues(alpha: 0.85),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: (_sequence == null) ? null : _buildStepBar(context),
    );
  }

  Widget _buildStepBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = TopicHues.hadeethEnc;
    return Container(
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _canPrev ? () => _goTo(_sequence! - 1) : null,
                  icon: _loadingAdjacent && _canPrev
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_back, size: 18),
                  label: Text('حدیث قبلی',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_sequence از $_total',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: TimeThemeKit.of(context).palette.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _canNext ? () => _goTo(_sequence! + 1) : null,
                  child: _loadingAdjacent && _canNext
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('حدیث بعدی',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads one hadith from its database id and then shows [HadeethEncDetailScreen].
///
/// `extra` carries a finished object for in-app navigation, so this exists for
/// the id-only form of the route. A missing database is a different problem
/// from an unknown id: the first is fixed by downloading it from the list, the
/// second never will be.
class HadeethEncDetailByIdScreen extends StatefulWidget {
  final int hadithId;
  final String highlightQuery;
  const HadeethEncDetailByIdScreen(
      {super.key, required this.hadithId, this.highlightQuery = ''});

  @override
  State<HadeethEncDetailByIdScreen> createState() =>
      _HadeethEncDetailByIdScreenState();
}

class _HadeethEncDetailByIdScreenState
    extends State<HadeethEncDetailByIdScreen> {
  late Future<HadeethEncHadith?> _load;

  @override
  void initState() {
    super.initState();
    _load = HadeethEncDbService().getHadith(widget.hadithId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HadeethEncHadith?>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            appBar: SectionAppBar(title: 'حدیث'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hadith = snap.data;
        if (hadith != null) {
          return HadeethEncDetailScreen(
            hadith: hadith,
            highlightQuery: widget.highlightQuery,
          );
        }
        // Only a clean null means «this id does not exist»; any throw means the
        // database itself is not usable yet.
        final notDownloaded = snap.error != null;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const SectionAppBar(title: 'حدیث'),
          body: AppEmptyState(
            icon: notDownloaded ? Icons.cloud_download : Icons.menu_book,
            message: notDownloaded
                ? 'پایگاه دادهٔ موسوعه احادیث آماده نیست.'
                : 'حدیثی با این شماره یافت نشد.',
            subtitle: notDownloaded
                ? 'برای دیدن این حدیث، پایگاه داده را از فهرست موسوعه دانلود کنید.'
                : null,
            accent: TopicHues.hadeethEnc,
            actionLabel: 'فهرست موسوعه',
            onAction: () => context.go(RouteNames.hadeethEnc),
          ),
        );
      },
    );
  }
}
