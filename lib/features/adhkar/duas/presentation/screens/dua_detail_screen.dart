import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/providers/duas_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_share_screen.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// Cream palette — same unified-card language as the hadeeth share card.
const Color _cardBgLight = Color(0xFFFDF6EC);
const Color _cardBgDark = Color(0xFF1B1F2A);
const Color _borderLight = Color(0xFFE3D6BE);
const Color _labelLight = Color(0xFF6B5638);

class DuaDetailScreen extends ConsumerStatefulWidget {
  final DuaModel dua;

  /// The word a deep-search hit was opened for — painted inside the dua's own
  /// text the moment the screen opens.
  final String highlightQuery;
  const DuaDetailScreen(
      {super.key, required this.dua, this.highlightQuery = ''});

  @override
  ConsumerState<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends ConsumerState<DuaDetailScreen> {
  /// Anchors the FIRST text block that carries the searched word, so a long
  /// dua opens on its word instead of at the top of the card.
  final _matchAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.highlightQuery.trim().isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    final dua = widget.dua;
    // `dua` is a snapshot handed in by the list. The heart writes through the
    // provider, so the icon has to read the live row — the pushed model never
    // changes and the star would stay in its old state. `null` while the
    // provider has not loaded yet, which falls back to the snapshot.
    final liveFavorite = ref.watch(duasProvider.select((s) {
      for (final d in s.duas) {
        if (d.id == dua.id) return d.isFavorite;
      }
      return null;
    }));
    final isFavorite = liveFavorite ?? dua.isFavorite;
    final hasArabic = dua.arabicText.trim().isNotEmpty;
    final hasTranslation = dua.translation.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: dua.title,
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Theme.of(context).colorScheme.error : null,
              size: 22,
            ),
            tooltip: 'علاقه‌مندی',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(duasProvider.notifier).toggleFavorite(dua.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'اشتراک‌گذاری',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DuaShareScreen(dua: dua)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'کپی',
            onPressed: () {
              final buffer = StringBuffer(dua.title);
              if (hasArabic) buffer.write('\n\n${dua.arabicText}');
              if (hasTranslation) buffer.write('\n\n${dua.translation}');
              if (dua.source.trim().isNotEmpty) {
                buffer.write('\n\nمنبع: ${dua.source}');
              }
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('کپی شد')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // One unified cream card for everything — like the share image.
          _UnifiedDuaCard(
            dua: dua,
            highlightQuery: widget.highlightQuery,
            matchAnchor: _matchAnchor,
          ),
        ],
      ),
    );
  }
}

class _UnifiedDuaCard extends StatelessWidget {
  final DuaModel dua;
  final String highlightQuery;

  /// Attached to the first block whose text carries the query — the screen
  /// scrolls to it, so a hit deep in the benefits opens ON its word.
  final GlobalKey? matchAnchor;
  const _UnifiedDuaCard(
      {required this.dua, required this.highlightQuery, this.matchAnchor});

  /// Every text block on the card goes through here, so a deep-search hit
  /// paints the same word in the arabic, the translation and the notes.
  Widget _painted(BuildContext context, String text, TextStyle style,
      {TextAlign? textAlign}) {
    final query = highlightQuery.trim();
    if (query.isEmpty) {
      return Text(text,
          textAlign: textAlign,
          textDirection: TextDirection.rtl,
          style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: TextHighlight.spans(text, query,
            baseStyle: style,
            highlightStyle:
                TextHighlight.defaultHighlightStyle(context, base: style)),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? _cardBgDark : _cardBgLight;
    final border = isDark ? Colors.white.withValues(alpha: 0.16) : _borderLight;
    final divider =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFEADFC9);
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0E6D2);
    final chipText = isDark ? Colors.white : const Color(0xFF5A4632);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.9) : _labelLight;

    // The first block the query actually occurs in gets the anchor; later
    // matches still paint, but only one block can be scrolled to.
    final query = highlightQuery.trim();
    var anchored = false;
    Widget anchor(String text, Widget child) {
      if (anchored || matchAnchor == null || query.isEmpty) return child;
      if (TextHighlight.findMatches(text, query).isEmpty) return child;
      anchored = true;
      return KeyedSubtree(key: matchAnchor, child: child);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.4),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header chip: category / book name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: divider, width: 1.2),
                ),
                child: Text(
                  '🛡 ${dua.category ?? 'حصن المسلم'}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w800,
                    color: chipText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (dua.lead.trim().isNotEmpty) ...[
            anchor(
              dua.lead.trim(),
              _painted(
                context,
                dua.lead.trim(),
                TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  height: 1.8,
                  fontStyle: FontStyle.italic,
                  color: labelColor.withValues(alpha: 0.95),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Arabic text
          if (dua.arabicText.trim().isNotEmpty) ...[
            anchor(
              dua.arabicText.trim(),
              _painted(
                context,
                dua.arabicText.trim(),
                TextStyle(
                  fontFamily: 'Calibri',
                  fontSize: AppTheme.scaledFontSize(context, 17),
                  height: 2.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
          ],
          // Persian translation
          if (dua.translation.trim().isNotEmpty) ...[
            _RowLabel('ترجمه', Icons.translate, labelColor, isDark),
            const SizedBox(height: 6),
            anchor(
              dua.translation.trim(),
              _painted(
                context,
                dua.translation.trim(),
                TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14.5),
                  height: 1.9,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.92)
                      : const Color(0xFF2A2A2A),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Word meanings
          if (dua.words.isNotEmpty) ...[
            _RowLabel('معنی کلمات حدیث', Icons.spellcheck_outlined, labelColor,
                isDark),
            const SizedBox(height: 6),
            for (final w in dua.words)
              anchor(
                w,
                _Bullet(tip: w, color: labelColor, query: highlightQuery),
              ),
            const SizedBox(height: 12),
          ],
          // Guidance
          if (dua.guidance.isNotEmpty) ...[
            _RowLabel('رهنمود حدیث', Icons.compass_calibration_outlined,
                labelColor, isDark),
            const SizedBox(height: 6),
            for (final g in dua.guidance)
              anchor(
                g,
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _painted(
                    context,
                    g,
                    TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      height: 1.9,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.82)
                          : const Color(0xFF444444),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          // Benefits
          if (dua.benefits.isNotEmpty) ...[
            _RowLabel('فوائد حدیث', Icons.tips_and_updates_outlined, labelColor,
                isDark),
            const SizedBox(height: 6),
            for (final b in dua.benefits)
              anchor(
                b,
                _Bullet(tip: b, color: labelColor, query: highlightQuery),
              ),
            const SizedBox(height: 12),
          ],
          // References
          if (dua.refs.isNotEmpty) ...[
            Divider(color: divider, height: 1),
            const SizedBox(height: 10),
            _RowLabel(
                'منابع و تخریج', Icons.menu_book_outlined, labelColor, isDark),
            const SizedBox(height: 6),
            for (final r in dua.refs)
              anchor(
                r,
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _painted(
                    context,
                    r,
                    TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      height: 1.7,
                      color: labelColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
          ] else if (dua.source.trim().isNotEmpty) ...[
            Divider(color: divider, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 15, color: labelColor),
                const SizedBox(width: 6),
                Flexible(
                  child: anchor(
                    'منبع: ${dua.source}',
                    _painted(
                      context,
                      'منبع: ${dua.source}',
                      TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: labelColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _RowLabel(this.text, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 13),
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : color,
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String tip;
  final Color color;
  final String query;
  const _Bullet({required this.tip, required this.color, this.query = ''});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(builder: (context) {
              final style = TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13.5),
                height: 1.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : const Color(0xFF444444),
              );
              if (query.trim().isEmpty) {
                return Text(tip,
                    textDirection: TextDirection.rtl, style: style);
              }
              return Text.rich(
                TextSpan(
                  style: style,
                  children: TextHighlight.spans(tip, query,
                      baseStyle: style,
                      highlightStyle: TextHighlight.defaultHighlightStyle(
                          context, base: style)),
                ),
                textDirection: TextDirection.rtl,
              );
            }),
          ),
        ],
      ),
    );
  }
}
