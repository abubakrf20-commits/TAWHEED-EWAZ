import 'package:flutter/material.dart';

import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/widgets/hadeeth_share_card.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «ارسال حدیث» — renders the hadith (Arabic + ترجمه + منبع + صحت + شرح) on a
/// single beautiful card with the توحید logo below it, then lets the user
/// share it as an image (PNG), as formatted text, or copy it.
class HadeethEncShareScreen extends StatefulWidget {
  final HadeethEncHadith hadith;
  final int? sequence;
  const HadeethEncShareScreen({super.key, required this.hadith, this.sequence});

  @override
  State<HadeethEncShareScreen> createState() => _HadeethEncShareScreenState();
}

class _HadeethEncShareScreenState extends State<HadeethEncShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  final Set<HadeethShareContent> _textContent =
      HadeethShareContent.values.toSet();
  final Set<HadeethShareContent> _imageContent =
      HadeethShareContent.values.toSet();

  HadeethEncHadith get hadith => widget.hadith;

  /// Number shown in the shared text/subject/image: the hadith's real
  /// encyclopedia number first, then the route hint, and finally the raw
  /// source id as a last resort. Before this, a search result (always the
  /// first row → sequence 1) or a favorites entry made every share say
  /// «حدیث شماره 1».
  int get _number => hadith.sequence ?? widget.sequence ?? hadith.id;

  void _toggle(Set<HadeethShareContent> set, HadeethShareContent content) {
    setState(() {
      if (!set.remove(content)) set.add(content);
    });
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _pumpFrames();
      final bytes = await ShareService.captureCard(
        _cardKey,
        minRatio: 3.0,
        maxRatio: 8.0,
      );
      await ShareService.sharePng(
        bytes,
        'hadith_${hadith.id}.png',
        text: ShareService.channelBlock,
      );
    } on ShareCaptureException catch (e) {
      AppLogger.warning('hadeeth_enc_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('hadeeth_enc_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    final text = _formattedText();
    await ShareService.shareText(text,
        subject: 'حدیث شماره $_number — موسوعه احادیث');
  }

  Future<void> _copyText() async {
    if (mounted) await ShareService.copyText(context, _formattedText());
  }

  String _formattedText() {
    final b = StringBuffer()
      ..writeln('🕌 حدیث شماره $_number')
      ..writeln();
    if (_textContent.contains(HadeethShareContent.arabic) &&
        hadith.textAr.trim().isNotEmpty) {
      b
        ..writeln(hadith.textAr.trim())
        ..writeln();
    }
    if (_textContent.contains(HadeethShareContent.translation) &&
        hadith.text.trim().isNotEmpty) {
      b
        ..writeln('ترجمه:')
        ..writeln(hadith.text.trim())
        ..writeln();
    }
    if (_textContent.contains(HadeethShareContent.source) &&
        (hadith.takhrij.trim().isNotEmpty || hadith.grade.trim().isNotEmpty)) {
      if (hadith.takhrij.trim().isNotEmpty) {
        b.writeln('منبع: ${hadith.takhrij.trim()}');
      }
      if (hadith.grade.trim().isNotEmpty) {
        b.writeln('صحت: ${hadith.grade.trim()}');
      }
      b.writeln();
    }
    if (_textContent.contains(HadeethShareContent.explanation) &&
        hadith.explanation.trim().isNotEmpty) {
      b
        ..writeln('شرح:')
        ..writeln(hadith.explanation.trim())
        ..writeln();
    }
    if (_textContent.contains(HadeethShareContent.tips) &&
        hadith.benefits.trim().isNotEmpty) {
      b.writeln('نکات حدیث:');
      for (final tip in hadeethTipLines(hadith.benefits)) {
        b.writeln('• $tip');
      }
      b.writeln();
    }
    b.writeln(ShareService.appLine());
    b.writeln(ShareService.channelLine);
    return b.toString();
  }

  Future<void> _pumpFrames() async {
    // Give the RepaintBoundary a couple of frames so the logo image and
    // fonts are fully laid out before rasterizing.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'ارسال حدیث'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 12, DsSpacing.page, 24),
        children: [
          Text(
            'محتوا را برای متن و تصویر انتخاب کنید، سپس ارسال نمایید.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: TimeThemeKit.of(context).palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          _ContentSelector(
            title: 'در متن',
            selected: _textContent,
            onToggle: (c) => _toggle(_textContent, c),
          ),
          const SizedBox(height: 10),
          _ContentSelector(
            title: 'در تصویر',
            selected: _imageContent,
            onToggle: (c) => _toggle(_imageContent, c),
          ),
          const SizedBox(height: 14),
          // The card that gets rasterized to PNG.
          RepaintBoundary(
            key: _cardKey,
            child: HadeethShareCard(
              hadith: hadith,
              sequence: _number,
              content: _imageContent,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _busy ? null : _shareImage,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.image_outlined, size: 20),
                  label: Text(
                    _busy ? 'در حال ساخت...' : 'ارسال تصویر',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _busy ? null : _shareText,
                  icon: const Icon(Icons.short_text, size: 20),
                  label: Text('ارسال متن',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: TimeThemeKit.of(context).palette.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onPressed: _copyText,
            icon: const Icon(Icons.copy, size: 18),
            label: Text('کپی متن',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// A group of [FilterChip]s letting the user pick which content blocks are
/// included when sharing as text or as an image.
class _ContentSelector extends StatelessWidget {
  final String title;
  final Set<HadeethShareContent> selected;
  final ValueChanged<HadeethShareContent> onToggle;
  const _ContentSelector({
    required this.title,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w700,
            color: TimeThemeKit.of(context).palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in HadeethShareContent.values)
              FilterChip(
                avatar: Icon(
                  c.icon,
                  size: 18,
                  color: selected.contains(c) ? accent : Colors.grey,
                ),
                label: Text(
                  c.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected.contains(c),
                onSelected: (_) => onToggle(c),
                selectedColor: accent.withValues(alpha: 0.16),
                checkmarkColor: accent,
                side: BorderSide(
                  color: accent.withValues(
                    alpha: selected.contains(c) ? 0.6 : 0.2,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
