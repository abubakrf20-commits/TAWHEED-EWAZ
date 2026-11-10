import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/design_system/components/ring.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The dhikr section's own colours, resolved once per build.
///
/// Everything here comes from the theme tokens the section already used (gold
/// accent, navy ink, success green, the page's outline), so the three view
/// modes cannot drift into three different palettes. Backgrounds are flat
/// fills; there are no gradients or translucent blobs anywhere in the section.
class DhikrTone {
  const DhikrTone({
    required this.gold,
    required this.success,
    required this.ink,
    required this.inkSoft,
    required this.card,
    required this.border,
    required this.track,
    required this.isDark,
  });

  final Color gold;
  final Color success;
  final Color ink;
  final Color inkSoft;
  final Color card;
  final Color border;
  final Color track;
  final bool isDark;

  factory DhikrTone.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DhikrTone(
      gold: isDark ? AppTheme.darkPrimary : AppTheme.lightTertiary,
      success: AppTheme.success,
      ink: AppColors.textPrimary(context),
      inkSoft: AppColors.textSecondary(context),
      card: AppColors.card(context),
      border: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
      track: AppColors.surfaceAlt(context),
      isDark: isDark,
    );
  }

}


/// The one-tick registration hint, worded identically wherever the reader can
/// meet it: a dhikr of a hundred repetitions is said, not counted out.
const String kDhikrHoldToRegister = 'برای ثبت یک‌جای ذکر، نگه دارید';

/// The item's Arabic text, on the paper-ish block the section uses.
class DhikrArabicBox extends StatelessWidget {
  const DhikrArabicBox({
    super.key,
    required this.item,
    required this.tone,
    required this.scaled,
    this.muted = false,
    this.maxHeight,
  });

  final ZikrItem item;
  final DhikrTone tone;

  /// The Arabic size after the reader's text-size setting.
  final double scaled;

  /// Finished items print in a softer ink, not with an opacity widget.
  final bool muted;

  /// Caps the block inside the focus card so a very long hadith scrolls
  /// instead of pushing the counter off the screen.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    if (item.arabicText.trim().isEmpty) return const SizedBox.shrink();
    final body = SelectableText(
      item.arabicText,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: scaled,
        height: 2.0,
        color: muted ? tone.inkSoft : tone.ink,
      ),
    );
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tone.isDark ? Colors.white.withValues(alpha: 0.03) : DhikrPalette.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border.withValues(alpha: 0.8)),
      ),
      child: body,
    );
    if (maxHeight == null) return box;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: SingleChildScrollView(child: box),
    );
  }
}

/// The virtue («فضیلت») note on its green chip, when the item has one.
class DhikrNoteChip extends StatelessWidget {
  const DhikrNoteChip({
    super.key,
    required this.text,
    required this.tone,
    required this.size,
  });

  final String text;
  final DhikrTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 15, color: tone.success),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: size,
                height: 1.75,
                color: tone.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The source («منبع») on its beige chip, when the item has one.
class DhikrSourceChip extends StatelessWidget {
  const DhikrSourceChip({
    super.key,
    required this.text,
    required this.tone,
    required this.size,
  });

  final String text;
  final DhikrTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tone.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 15, color: tone.gold),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: size,
                  color: AppColors.strongAccent(context, tone.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 40dp tinted icon button — share, copy, undo, previous.
class DhikrIconButton extends StatelessWidget {
  const DhikrIconButton({
    super.key,
    required this.icon,
    required this.tone,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
    this.semanticLabel,
  });

  final IconData icon;
  final DhikrTone tone;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: Material(
        color: tone.track,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.45,
                color: AppColors.textMuted(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Copies one dhikr exactly as the section always has (title, Arabic,
/// translation, source) and confirms with the usual snackbar.
Future<void> copyDhikr(BuildContext context, ZikrItem item) async {
  final buffer = StringBuffer(item.title)
    ..write('\n\n')
    ..write(item.arabicText)
    ..write('\n\n')
    ..write(item.translation);
  if (item.source.trim().isNotEmpty) {
    buffer
      ..write('\n\nمنبع ')
      ..write(item.source);
  }
  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('کپی شد'),
      duration: Duration(seconds: 1),
    ));
}

/// The «پیشرفت اذکار» card: a ring, two lines and — for a short collection — a
/// one-segment-per-item bar so the shape of the day is visible at a glance.
class DhikrProgressCard extends StatelessWidget {
  const DhikrProgressCard({
    super.key,
    required this.tone,
    required this.done,
    required this.total,
    this.compact = false,
    this.segments = const [],
  });

  final DhikrTone tone;
  final int done;
  final int total;

  /// The timeline's one-line version (40dp ring, caption only).
  final bool compact;

  /// Item states in content order: 0 = none, 1 = partial, 2 = done.
  final List<int> segments;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    // The app's one ring: the kit painter, from 12 o'clock, round caps. The
    // section built this twice by hand (a Stack over a CircularProgressIndicator
    // here, another Stack in the focus counter), which is how one ring can open
    // one way and its twin the opposite way.
    final ring = RingView(
      size: compact ? 40 : 52,
      strokeWidth: compact ? 4 : 5,
      progress: pct,
      color: pct >= 1 ? tone.success : tone.gold,
      trackColor: tone.gold.withValues(alpha: 0.16),
      child: Text(
        NumberFormat.fraction(done, total),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, compact ? 9 : 10.5),
          fontWeight: FontWeight.w700,
          color: tone.ink,
        ),
      ),
    );

    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          compact ? 'پیشرفت اذکار · ${(pct * 100).round()}%' : 'پیشرفت اذکار',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, compact ? 12 : 13.5),
            fontWeight: FontWeight.w600,
            color: tone.ink,
          ),
        ),
        if (!compact)
          Text(
            '${(pct * 100).round()}% از این بخش',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: AppColors.textMuted(context),
            ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: tone.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ring,
              const SizedBox(width: 12),
              Expanded(child: labels),
              if (pct >= 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tone.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'کامل',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w700,
                      color: tone.success,
                    ),
                  ),
                ),
            ],
          ),
          if (!compact && segments.isNotEmpty && segments.length <= 24) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: switch (segments[i]) {
                          2 => tone.success,
                          1 => tone.gold,
                          _ => tone.track,
                        },
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
