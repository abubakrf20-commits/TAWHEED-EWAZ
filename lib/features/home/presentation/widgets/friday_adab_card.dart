import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/section_header.dart';
import 'package:tawheeed/core/design_system/components/share_card_palette.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/shared/services/friday_content.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════
/// FridayAdabCard — «آداب و فضایل روز جمعه» on the home page.
///
/// Rendered ONLY on Friday ([FridayContent.isFriday]); on every other day it
/// is a zero-size box so the home page is unchanged. Content comes from
/// [FridayContent] — the SAME single source the weekly notification and the
/// settings preview read — so the card, the reminder and the notification
/// can never disagree.
///
/// Design: the flat card language of the current home page (palette card,
/// hairline border, no gradient, no blur): a [SectionHeader] with the share
/// actions, the headline hadith as a tinted quote box, and one flat row per
/// adab on the shared duotone tile. The card is ALWAYS fully expanded — all
/// adabs and each row's full text (detail + hadith + source) render in place,
/// with no «بیشتر»/«بستن» controls anywhere (user decision, 2026-10-16);
/// nothing of the source is hidden behind a tap.
/// ═══════════════════════════════════════════════════════════════
const Color _fridayAccent = HomeColors.friday;

/// Neutral COOL greys for the exported surface's frame and divider.
///
/// [ShareCardPalette]'s `border`/`divider` are warm beige tones
/// (`0xFFE3D6BE` / `0xFFEADFC9`) that rasterize as yellow lines on phone
/// screens — the exact trap the inheritance share card documents
/// ("warm/beige greys … read as yellow lines"). The Friday export must not
/// inherit that, so its frame and divider are painted in a cool grey instead.
/// The on-screen card already uses a cool neutral outline ([AppCard]'s
/// `t.outline`), which is why normal mode shows no yellow line under the
/// texts.
const Color _shareFrame = Color(0xFFD7D7E2);
const Color _shareDivider = Color(0xFFE3E3EA);

/// Cool-grey border for the exported surface's inner rows/quote box.
///
/// The on-screen card keeps its purple row borders (the user's preferred
/// look), but the EXPORTED image must not carry thin purple hairlines: those
/// anti-alias and, once a chat app re-compresses the PNG (chroma
/// subsampling), shift warm — exactly the "yellow/red line under the text"
/// the shared image showed. A cool grey reads as a neutral hairline on every
/// display and after compression, so the Friday export carries no warm line.
const Color _shareRowBorder = Color(0xFFC9C9D6);

/// Neutral COOL-grey fill for the exported surface's quote box and adab rows.
///
/// The on-screen card keeps a faint purple tint on these boxes (the user's
/// preferred look), but in the EXPORTED PNG that tint rasterizes as a purple
/// HIGHLIGHT band behind every text block from top to bottom — the
/// "هایلات روی تمامی متنها" the shared image showed. A neutral cool grey keeps
/// the box structure without reading as a colored highlight after capture or
/// chat re-compression.
const Color _shareBoxFill = Color(0xFFF4F5F9);

/// The detail plus its own hadith as ONE text — shared by the on-screen row
/// and the exported surface so the two can never show different words.
String _adabBody(FridayAdab adab) {
  final hadith = adab.hadith;
  return hadith == null
      ? adab.detail
      : '${adab.detail}\n'
          '«${hadith.arabic}» — ${hadith.translation} (${hadith.source})';
}

class FridayAdabCard extends ConsumerStatefulWidget {
  const FridayAdabCard({super.key, this.now, this.captureCard});

  /// Clock seam: a widget test / golden can pin "is it Friday?" to a known
  /// instant instead of the real calendar day. In production the shared
  /// minute ticker supplies it, so the home goldens (which freeze that
  /// ticker) stay deterministic.
  @visibleForTesting
  final DateTime? now;

  /// Rasterizer seam: a widget test can watch the export surface without
  /// driving the engine's `toImage`, which needs `runAsync`.
  @visibleForTesting
  final Future<Uint8List> Function(GlobalKey key)? captureCard;

  @override
  ConsumerState<FridayAdabCard> createState() => _FridayAdabCardState();
}

class _FridayAdabCardState extends ConsumerState<FridayAdabCard> {
  bool _shareBusy = false;

  /// Boundary of the OFF-SCREEN export surface that [_shareImage] inserts
  /// into the overlay — never the on-screen card (see [_shareImage]).
  final GlobalKey _shareKey = GlobalKey();

  String _buildShareText() {
    final b = StringBuffer()
      ..writeln('🕌 ${FridayContent.title}')
      ..writeln('«${FridayContent.headline.arabic}»')
      ..writeln(
          '${FridayContent.headline.translation} (${FridayContent.headline.source})')
      ..writeln();
    for (final a in FridayContent.adabs) {
      b.writeln('• ${a.title}: ${a.detail}');
      final h = a.hadith;
      if (h != null) {
        b.writeln('  «${h.arabic}» — ${h.translation} (${h.source})');
      }
    }
    b
      ..writeln()
      ..writeln(ShareService.appLine(FridayContent.title))
      ..writeln(ShareService.channelLine);
    return b.toString();
  }

  Future<void> _shareImage() async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    OverlayEntry? entry;
    try {
      // The exported image must not follow the sender's theme, and it must be
      // opaque: rasterizing the on-screen card captured a TRANSPARENT PNG (the
      // boundary sat inside AppCard, so the card's own background was outside
      // it) whose theme ink read as a black image on the default «شب» theme —
      // the reported «تاریک» share (2026-10-21). So the export is its own
      // surface, built off-screen on the cream share paper at the card's own
      // width, then captured and thrown away.
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        throw const ShareCaptureException('کارت ارسال آماده نیست.');
      }
      final screenWidth = MediaQuery.sizeOf(context).width;
      final shareWidth = screenWidth > 444 ? 420.0 : screenWidth - 24;
      // The export is captured ~200 ms after it is inserted, so the mark must
      // already be decoded or the footer's logo slot ships blank.
      await ShareCardLogo.precache(
        context,
        onError: (error, _) =>
            AppLogger.warning('FridayAdabCard', 'logo preload failed: $error'),
      );
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -shareWidth - 100,
          top: 0,
          width: shareWidth,
          child: RepaintBoundary(
            key: _shareKey,
            child: const FridayAdabShareCard(),
          ),
        ),
      );
      overlay.insert(entry);
      // Give the off-screen surface a few frames to lay out and paint.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final capture = widget.captureCard ?? ShareService.captureCard;
      final bytes = await capture(_shareKey);
      await ShareService.sharePng(bytes, 'friday_adab.png',
          text: ShareService.channelBlock);
    } on ShareCaptureException catch (e) {
      // The exception already carries a user-facing message; show it and add
      // no AppLogger noise beyond the failure snackbar.
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (e) {
      AppLogger.warning('FridayAdabCard', 'image share failed: $e');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      entry?.remove();
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _shareText() =>
      ShareService.shareText(_buildShareText(), subject: FridayContent.title);

  @override
  Widget build(BuildContext context) {
    // Production reads the shared minute ticker (the same seam every other
    // home card uses) so a rebuilt day — and the home goldens that freeze it
    // — never depend on the wall clock.
    final now = widget.now ?? ref.watch(clockTickerProvider).minute.value;
    if (!FridayContent.isFriday(now)) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? _fridayAccent : mix(_fridayAccent, Colors.black, 0.45);
    const all = FridayContent.adabs;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SectionHeader(
              title: FridayContent.title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'اشتراک متن',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    onPressed: _shareText,
                    icon: const Icon(Icons.share_outlined,
                        size: 18, color: _fridayAccent),
                  ),
                  IconButton(
                    tooltip: 'اشتراک تصویر',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    onPressed: _shareImage,
                    icon: const Icon(Icons.image_outlined,
                        size: 18, color: _fridayAccent),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _quoteBox(FridayContent.headline),
                const SizedBox(height: 8),
                for (final a in all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _adabRow(a, titleColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteBox(FridayHadith hadith) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _fridayAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: _fridayAccent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mosque_outlined, size: 20, color: _fridayAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hadith.arabic,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hadith.translation} (${hadith.source})',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    height: 1.35,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adabRow(FridayAdab adab, Color titleColor) {
    final t = TimeThemeKit.of(context).palette;
    // Detail plus its own hadith in ONE text, shown IN FULL: the card is
    // always fully expanded (user decision, 2026-10-16) — no per-row
    // expander, nothing of the source is hidden behind a tap.
    final body = _adabBody(adab);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _fridayAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: _fridayAccent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DuotoneIconTile(accent: _fridayAccent, icon: adab.icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    height: 1.35,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The exported «آداب و فضایل روز جمعه» surface — what [_shareImage] captures.
///
/// Deliberately NOT the on-screen [AppCard]: the export is opaque and
/// theme-independent. Rasterizing the on-screen card produced a TRANSPARENT
/// PNG (its boundary sat inside [AppCard], so the card's own background was
/// outside it) whose ink followed the sender's theme — a black image under
/// the default «شب» theme (reported 2026-10-21). This paper is the cream
/// [ShareCardPalette.bg] with fixed ink, so a received image reads the same
/// whatever theme it was sent from.
class FridayAdabShareCard extends StatelessWidget {
  const FridayAdabShareCard({super.key});

  @override
  Widget build(BuildContext context) {
    // A light theme + light kit palette so [DuotoneIconTile] resolves its
    // glyph contrast against the cream paper, not the sender's dark theme.
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        extensions: const [TimeThemeKit(AppPalettes.goldLight)],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          key: const ValueKey('friday-share-surface'),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: ShareCardPalette.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _shareFrame, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mosque_outlined,
                      size: 20, color: _fridayAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      FridayContent.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color: ShareCardPalette.inkTitle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _quoteBox(context, FridayContent.headline),
              const SizedBox(height: 8),
              for (final a in FridayContent.adabs) ...[
                _adabRow(context, a),
                const SizedBox(height: 8),
              ],
              const Divider(height: 10, color: _shareDivider),
              const SizedBox(height: 6),
              const ShareCardSignature(
                section: FridayContent.title,
                fontSize: ShareCardSignature.compactFontSize,
                color: ShareCardPalette.label,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quoteBox(BuildContext context, FridayHadith hadith) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _shareBoxFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _shareRowBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mosque_outlined, size: 20, color: _fridayAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hadith.arabic,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: ShareCardPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hadith.translation} (${hadith.source})',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    height: 1.35,
                    color: ShareCardPalette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adabRow(BuildContext context, FridayAdab adab) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _shareBoxFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _shareRowBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DuotoneIconTile(accent: _fridayAccent, icon: adab.icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adab.title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: ShareCardPalette.inkTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _adabBody(adab),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    height: 1.35,
                    color: ShareCardPalette.inkBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
