// Download page — the spec-E page that lives inside the reader's download
// sheet.
//
// What changed for the reader's report: the page is now scrollable all the
// way down (it used a physics-gated view that could not scroll at all on
// first open), carries a storage hero with real free space, and has the
// wifi-only toggle with a default of on.

part of 'quran_mushaf_view.dart';

/// The storage hero: a ring with the pages percent, two labelled bars and
/// the free-space line, with a compact delete affordance.
class _StorageHero extends StatelessWidget {
  const _StorageHero({
    required this.palette,
    required this.pagesDone,
    required this.fontsDone,
    required this.pagesTotal,
    required this.fontsTotal,
    required this.freeSpaceMb,
    required this.onDelete,
    required this.canDelete,
    required this.deleting,
  });

  final MushafPalette palette;
  final int pagesDone;
  final int fontsDone;
  final int pagesTotal;
  final int fontsTotal;
  final double? freeSpaceMb;
  final VoidCallback onDelete;
  final bool canDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final pagesFraction = pagesTotal == 0 ? 0.0 : (pagesDone / pagesTotal).clamp(0.0, 1.0);
    final fontsFraction = fontsTotal == 0 ? 0.0 : (fontsDone / fontsTotal).clamp(0.0, 1.0);
    final percent = (pagesFraction * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // The reader's flat surface, not the retired gold hero gradient
        // (reader request: «رنگ بوکس فضای دانلود مصحف»). The card is part of
        // the reader's kit now — the same faint accent wash the ayah sheet's
        // share tile wears — and, unlike an unconditional gold, it follows the
        // paper: on the night palette the gold field put cream text on a light
        // background, which is exactly the contrast the palette exists to keep.
        color: palette.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CustomPaint(
                  painter: _RingPct(percent, palette.accent),
                  child: Center(
                    child: Text(
                      '${NumberFormat.toLatin('$percent')}٪',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فضای دانلود مصحف',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.surfaceText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _heroBar(
                      context,
                      'صفحه‌ها ${NumberFormat.fraction(pagesDone, pagesTotal)}',
                      pagesFraction,
                      palette,
                    ),
                    const SizedBox(height: 4),
                    _heroBar(
                      context,
                      'فونت‌ها ${NumberFormat.fraction(fontsDone, fontsTotal)}',
                      fontsFraction,
                      palette,
                    ),
                    if (freeSpaceMb != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'فضای آزاد دستگاه: ${NumberFormat.toLatin(freeSpaceMb!.toStringAsFixed(0))} مگابایت',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: palette.surfaceText.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canDelete) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: deleting ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('حذف داده'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.accent,
                  side: BorderSide(color: palette.accent.withValues(alpha: 0.5)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroBar(
    BuildContext context,
    String label,
    double value,
    MushafPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: palette.surfaceText.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 5,
            backgroundColor: palette.surfaceText.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
      ],
    );
  }
}

/// Ring that paints `percent` on the accent colour.
class _RingPct extends CustomPainter {
  const _RingPct(this.percent, this.color);
  final int percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - 8) / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: 0.15),
    );
    if (percent <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -0.5 * 3.141592653589793,
      2 * 3.141592653589793 * (percent / 100).clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPct old) =>
      old.percent != percent || old.color != color;
}
