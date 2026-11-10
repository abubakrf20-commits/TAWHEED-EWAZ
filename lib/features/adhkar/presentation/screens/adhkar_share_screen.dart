import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «ارسال ذکر» — renders a timeline adhkar (عنوان + متن عربی + ترجمه + فضیلت
/// + منبع) on a single unified cream card — the exact same visual language as
/// the حصن المسلم share card — then lets the user share it as an image (PNG),
/// as formatted text, or copy it.
class AdhkarShareScreen extends StatefulWidget {
  final ZikrItem item;
  const AdhkarShareScreen({super.key, required this.item});

  @override
  State<AdhkarShareScreen> createState() => _AdhkarShareScreenState();
}

/// Content blocks that can be included when sharing a dhikr (text or image).
enum AdhkarShareContent {
  arabic('متن عربی', Icons.text_fields),
  translation('ترجمه', Icons.translate),
  virtue('فضیلت', Icons.auto_awesome_outlined),
  source('منبع', Icons.menu_book_outlined);

  const AdhkarShareContent(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _AdhkarShareScreenState extends State<AdhkarShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  final Set<AdhkarShareContent> _textContent =
      AdhkarShareContent.values.toSet();
  final Set<AdhkarShareContent> _imageContent =
      AdhkarShareContent.values.toSet();

  ZikrItem get item => widget.item;

  void _toggle(Set<AdhkarShareContent> set, AdhkarShareContent content) {
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
        'azkar_${item.id}.png',
        text: ShareService.channelBlock,
      );
    } on ShareCaptureException catch (e) {
      AppLogger.warning('adhkar_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('adhkar_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    await ShareService.shareText(
      _formattedText(),
      subject: '${item.title} — تایم لاین اعمال',
    );
  }

  Future<void> _copyText() async {
    if (mounted) await ShareService.copyText(context, _formattedText());
  }

  String _formattedText() {
    final b = StringBuffer()
      ..writeln(item.title)
      ..writeln();
    if (_textContent.contains(AdhkarShareContent.arabic) &&
        item.arabicText.trim().isNotEmpty) {
      b
        ..writeln(item.arabicText.trim())
        ..writeln();
    }
    if (_textContent.contains(AdhkarShareContent.translation) &&
        item.translation.trim().isNotEmpty) {
      b
        ..writeln('ترجمه:')
        ..writeln(item.translation.trim())
        ..writeln();
    }
    if (_textContent.contains(AdhkarShareContent.virtue) &&
        item.virtue.trim().isNotEmpty) {
      b
        ..writeln('فضیلت:')
        ..writeln(item.virtue.trim())
        ..writeln();
    }
    if (_textContent.contains(AdhkarShareContent.source) &&
        item.source.trim().isNotEmpty) {
      b
        ..writeln('منبع: ${item.source.trim()}')
        ..writeln();
    }
    b
      ..writeln(ShareService.appLine('تایم لاین اعمال'))
      ..writeln(ShareService.channelLine);
    return b.toString();
  }

  Future<void> _pumpFrames() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = ShareCardPalette.accent;
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'ارسال ذکر'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'محتوا را برای متن و تصویر انتخاب کنید، سپس ارسال نمایید.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
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
            RepaintBoundary(
              key: _cardKey,
              child: _AdhkarShareCard(item: item, content: _imageContent),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.image_outlined, size: 20),
                    label: Text(
                      _busy ? 'در حال ساخت...' : 'ارسال تصویر',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                      ),
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
                    label: Text(
                      'ارسال متن',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: _copyText,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(
                'کپی متن',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group of [FilterChip]s letting the user pick which content blocks are
/// included when sharing as text or as an image.
class _ContentSelector extends StatelessWidget {
  final String title;
  final Set<AdhkarShareContent> selected;
  final ValueChanged<AdhkarShareContent> onToggle;
  const _ContentSelector({
    required this.title,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = ShareCardPalette.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in AdhkarShareContent.values)
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

/// The unified cream share card, rendered through [ShareCardShell] like every
/// other share surface. Only blocks present in [content] are rendered.
class _AdhkarShareCard extends StatelessWidget {
  final ZikrItem item;
  final Set<AdhkarShareContent> content;
  const _AdhkarShareCard({
    required this.item,
    this.content = const {
      AdhkarShareContent.arabic,
      AdhkarShareContent.translation,
      AdhkarShareContent.virtue,
      AdhkarShareContent.source,
    },
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    const accent = SectionHues.tasbih;

    final showVirtue = content.contains(AdhkarShareContent.virtue) &&
        item.virtue.trim().isNotEmpty;

    return ShareCardShell(
      children: [
        ShareCardHeader(
          icon: Icons.mosque_outlined,
          title: item.title,
          subtitle: 'تایم لاین اعمال',
          accent: accent,
        ),
        const SizedBox(height: 14),
        // Arabic text
        if (content.contains(AdhkarShareContent.arabic) &&
            item.arabicText.trim().isNotEmpty) ...[
          Text(
            item.arabicText.trim(),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontFamilyFallback: const ['Calibri'],
              fontSize: AppTheme.scaledFontSize(context, 18),
              height: 2.0,
              fontWeight: FontWeight.w600,
              color: c.head,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: ShareCardDivider(),
          ),
        ],
        // Persian translation
        if (content.contains(AdhkarShareContent.translation) &&
            item.translation.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.translate,
            label: 'ترجمه',
            accent: accent,
          ),
          const SizedBox(height: 6),
          Text(
            item.translation.trim(),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14.5),
              height: 1.9,
              color: c.body,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Virtue
        if (showVirtue) ...[
          const ShareCardLabel(
            icon: Icons.auto_awesome_outlined,
            label: 'فضیلت',
            accent: accent,
          ),
          const SizedBox(height: 6),
          Text(
            item.virtue.trim(),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13.5),
              height: 1.9,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Source
        if (content.contains(AdhkarShareContent.source) &&
            item.source.trim().isNotEmpty) ...[
          const ShareCardDivider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 15, color: c.label),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.source.trim(),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: c.label,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const ShareCardFooter(section: 'تایم لاین اعمال'),
      ],
    );
  }
}
