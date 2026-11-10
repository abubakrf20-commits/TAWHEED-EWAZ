import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// صفحهٔ عنوان — همان صفحهٔ اولِ کتاب چاپی.
///
/// A book opens on its name: title, who compiled it, what it is, how many
/// volumes. It is a display sheet only — it carries no page index, so opening
/// a book here never moves a saved position, a bookmark or a highlight.
class BookTitlePage extends StatelessWidget {
  const BookTitlePage({
    super.key,
    required this.title,
    required this.author,
    required this.category,
    required this.ink,
    required this.fontFamily,
    this.volumes = 0,
  });

  final String title;
  final String author;
  final String category;

  /// The reader's paper ink, so the title belongs to the page instead of the
  /// app theme.
  final Color ink;
  final String fontFamily;

  /// How many printed volumes the edition has, when the file says so.
  final int volumes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'صفحهٔ عنوان $title',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category.isNotEmpty) ...[
                Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    height: 1.6,
                    letterSpacing: 0.4,
                    color: ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _Rule(ink: ink),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 24),
                  fontWeight: FontWeight.w800,
                  height: 1.65,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              _Ornament(ink: ink),
              if (author.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  author,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 1.7,
                    color: ink.withValues(alpha: 0.82),
                  ),
                ),
              ],
              if (volumes > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${NumberFormat.ltrIsolated('$volumes')} جلد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    height: 1.7,
                    color: ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              _Rule(ink: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// برگ سفید: پشتِ عنوان، جلوی فصلِ تازه، یا لِهای جفتِ ناقص.
///
/// Deliberately empty. A printed blank leaf carries nothing but paper, and
/// giving it a folio or a head would make the reader think a page was lost.
class BookBlankSheet extends StatelessWidget {
  const BookBlankSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'برگ سفید',
      child: const SizedBox.expand(),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(width: 56, height: 1, color: ink.withValues(alpha: 0.28));
  }
}

/// A small lozenge between the title and the author — the one ornament a
/// title page is allowed.
class _Ornament extends StatelessWidget {
  const _Ornament({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 34, height: 1, color: ink.withValues(alpha: 0.2)),
        const SizedBox(width: 6),
        Transform.rotate(
          angle: 0.7853981633974483,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.45),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(width: 34, height: 1, color: ink.withValues(alpha: 0.2)),
      ],
    );
  }
}
