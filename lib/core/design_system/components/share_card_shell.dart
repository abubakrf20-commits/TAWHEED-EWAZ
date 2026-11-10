import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/share_card_palette.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/services/share_service.dart';

/// The one share-card frame: cream paper, radius 18, a 1.2 dp hairline and no
/// shadow — the exported image is read on someone else's phone, so it holds a
/// flat printed page rather than the app's elevated surfaces.
///
/// Before this shell the seven share cards each rebuilt the same container by
/// hand (radius 22, border 1.4, some with a blur-18 shadow, padding drifting
/// between 12 and 18), which is exactly how the exports stopped reading as one
/// family. Every share surface now renders through it.
class ShareCardShell extends StatelessWidget {
  const ShareCardShell({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(14),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border, width: 1.2),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// The card's title row: the flat duotone tile (34 dp) that every list row in
/// the app uses, then the title — never a decorative emoji.
class ShareCardHeader extends StatelessWidget {
  const ShareCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Row(
      children: [
        DuotoneIconTile(accent: accent, icon: icon, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: c.head,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: c.label,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// A block label inside a card (ترجمه، شرح، فضیلت …) — the same duotone tile
/// as the header, on the section's own accent, followed by the label ink.
class ShareCardLabel extends StatelessWidget {
  const ShareCardLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Row(
      children: [
        DuotoneIconTile(accent: accent, icon: icon, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: c.head,
            ),
          ),
        ),
      ],
    );
  }
}

/// The card's hairline, always in the resolved divider ink — a bare `Divider`
/// paints the theme's grey on the cream paper, which is the drift the share
/// surfaces lock forbids.
class ShareCardDivider extends StatelessWidget {
  const ShareCardDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) => Divider(
        color: ShareCardColors.of(context).divider,
        height: height,
      );
}

/// The Tawheed mark printed beside the signature line on an exported card.
///
/// The asset name lives in [ShareService.logoAsset] and nowhere else: a
/// per-surface `Image.asset` is what the share-surface lock rejects, because
/// ten exports then carry ten chances to draw a different mark. Cards never
/// build this widget themselves — [ShareCardSignature] is the only caller.
class ShareCardLogo extends StatelessWidget {
  const ShareCardLogo({super.key, this.size = defaultSize});

  /// Height of the mark in the signature row. It rides beside an 11 sp line,
  /// so it stays near the line's own height — at 48 dp it dwarfed the text, and
  /// even 20 dp read a shade taller than the line it marks.
  static const double defaultSize = 18;

  /// Height of the mark; the asset is wider than it is tall (256×228), so the
  /// width follows the aspect ratio rather than being forced square.
  final double size;

  /// A card is captured at up to 6× (`ShareService.captureCard`), so the mark
  /// decodes for the exported PNG rather than for a 1× preview.
  static ImageProvider<Object> providerFor(double size) => ResizeImage(
        const AssetImage(ShareService.logoAsset),
        width: (size * 6).round(),
      );

  /// Loads the same decoded image [build] will paint. An off-screen export is
  /// captured a few frames after it is inserted, so a first-time decode would
  /// land after the shutter and the exported PNG would have a blank footer.
  static Future<void> precache(
    BuildContext context, {
    double size = defaultSize,
    ImageErrorListener? onError,
  }) =>
      precacheImage(providerFor(size), context, onError: onError);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image(
        image: providerFor(size),
        height: size,
        fit: BoxFit.contain,
        semanticLabel: ShareService.signatureName,
        errorBuilder: (context, error, stack) => Icon(
          Icons.mosque_outlined,
          size: size * .7,
          color: ShareCardColors.of(context).label,
        ),
      ),
    );
  }
}

/// The mark and the signature on ONE line: the app logo, a 6 dp gap, then the
/// dash-free signature (the em dash belongs to text shares only).
///
/// Stacking the mark above the line made the footer twice as tall as the
/// signature it marks, so the row is the footer's fixed composition — the
/// gallery, the two hand-written footers and the Friday export all read it from
/// here rather than composing their own.
class ShareCardSignature extends StatelessWidget {
  const ShareCardSignature({
    super.key,
    required this.section,
    this.fontSize = defaultFontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
  });

  /// The footer's own line size.
  static const double defaultFontSize = 11;

  /// The tighter line the Friday export uses, where the card is denser and the
  /// signature must not outgrow the adab rows.
  static const double compactFontSize = 10;

  /// The section name appended to the signature line
  /// (`ShareService.signatureLine`).
  final String section;

  final double fontSize;
  final FontWeight fontWeight;

  /// Defaults to the card's resolved label ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ShareCardLogo(),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              ShareService.signatureLine(section),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, fontSize),
                fontWeight: fontWeight,
                color: color ?? c.label,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The one footer every share card ends with: a hairline and the signature row
/// ([ShareCardSignature]: app mark beside the dash-free line). Every card reads
/// it from here so the ten exports print the same signature.
class ShareCardFooter extends StatelessWidget {
  const ShareCardFooter({super.key, required this.section});

  /// The section name appended to the signature line
  /// (`ShareService.signatureLine`).
  final String section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShareCardDivider(),
        const SizedBox(height: 10),
        ShareCardSignature(section: section),
      ],
    );
  }
}
