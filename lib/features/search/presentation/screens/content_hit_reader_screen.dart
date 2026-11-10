import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/search/services/content_hit.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// The destination for a deep-search hit whose own section has no per-item
/// screen to travel to (a bundled guide, رقیه, دعا از قرآن, a fatwa row …).
///
/// It shows the exact block the match was found in with the searched word
/// painted, so tapping a result always lands on the word itself — the same
/// promise the chapter and book destinations keep for their sections.
class ContentHitReaderScreen extends StatelessWidget {
  const ContentHitReaderScreen({
    super.key,
    required this.hit,
    required this.sectionTitle,
    required this.sectionIcon,
    required this.accent,
    this.onOpenSection,
  });

  final ContentHit hit;
  final String sectionTitle;
  final IconData sectionIcon;
  final Color accent;

  /// Opens the owning section after the reader closes, when that section has
  /// a landing screen the user can go on to.
  final VoidCallback? onOpenSection;

  String get _text => hit.body.trim().isEmpty ? hit.snippet : hit.body.trim();

  void _copy(BuildContext context) {
    final buffer = StringBuffer();
    if (hit.title.trim().isNotEmpty) buffer.writeln('${hit.title}\n');
    buffer.write(_text);
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('کپی شد', style: TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.scaledFontSize(context, 13.5),
      height: 1.9,
      color: t.textPrimary,
    );
    final query = hit.highlightQuery.trim();
    return Scaffold(
      backgroundColor: t.pageBg,
      appBar: SectionAppBar(
        title: hit.title.trim().isEmpty ? sectionTitle : hit.title,
        actions: [
          IconButton(
            tooltip: 'کپی',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () => _copy(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 8, DsSpacing.page, 32),
        children: [
          Row(
            children: [
              DuotoneIconTile(accent: accent, icon: sectionIcon, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionTitle,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    if (hit.title.trim().isNotEmpty)
                      Text(
                        hit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11.5),
                          color: t.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SelectableText.rich(
              TextSpan(
                style: base,
                children: query.isEmpty
                    ? [TextSpan(text: _text, style: base)]
                    : TextHighlight.spans(
                        _text,
                        query,
                        baseStyle: base,
                        highlightStyle: TextHighlight.defaultHighlightStyle(
                            context, base: base),
                      ),
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          if (onOpenSection != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  'رفتن به بخش «$sectionTitle»',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenSection?.call();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
