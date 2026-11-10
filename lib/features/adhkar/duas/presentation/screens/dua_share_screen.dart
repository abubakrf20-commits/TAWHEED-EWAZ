import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «ارسال دعا» — renders a حصن المسلم dua (متن + ترجمه + شرح + منبع) on a
/// single unified cream card — the exact same visual language as the reader
/// card and the موسوعه احادیث share image — then lets the user share it as an
/// image (PNG), as formatted text, or copy it.
class DuaShareScreen extends StatefulWidget {
  final DuaModel dua;
  const DuaShareScreen({super.key, required this.dua});

  @override
  State<DuaShareScreen> createState() => _DuaShareScreenState();
}

/// Content blocks that can be included when sharing a dua (text or image).
enum DuaShareContent {
  arabic('متن عربی', Icons.text_fields),
  transliteration('رونویسی', Icons.record_voice_over_outlined),
  translation('ترجمه', Icons.translate),
  explanation('شرح', Icons.auto_stories_outlined),
  source('منبع', Icons.menu_book_outlined);

  const DuaShareContent(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DuaShareScreenState extends State<DuaShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  final Set<DuaShareContent> _textContent = DuaShareContent.values.toSet();
  final Set<DuaShareContent> _imageContent = DuaShareContent.values.toSet();

  DuaModel get dua => widget.dua;

  void _toggle(Set<DuaShareContent> set, DuaShareContent content) {
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
        'dua_${dua.id}.png',
        text: ShareService.channelBlock,
      );
    } on ShareCaptureException catch (e) {
      AppLogger.warning('dua_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('dua_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    final text = _formattedText();
    await ShareService.shareText(text, subject: '${dua.title} — حصن المسلم');
  }

  Future<void> _copyText() async {
    if (mounted) await ShareService.copyText(context, _formattedText());
  }

  String _formattedText() {
    final b = StringBuffer()
      ..writeln(dua.title)
      ..writeln();
    if (_textContent.contains(DuaShareContent.arabic) &&
        dua.arabicText.trim().isNotEmpty) {
      b
        ..writeln(dua.arabicText.trim())
        ..writeln();
    }
    if (_textContent.contains(DuaShareContent.transliteration) &&
        dua.transliteration != null &&
        dua.transliteration!.trim().isNotEmpty) {
      b
        ..writeln('رونویسی:')
        ..writeln(dua.transliteration!.trim())
        ..writeln();
    }
    if (_textContent.contains(DuaShareContent.translation) &&
        dua.translation.trim().isNotEmpty) {
      b
        ..writeln('ترجمه:')
        ..writeln(dua.translation.trim())
        ..writeln();
    }
    if (_textContent.contains(DuaShareContent.explanation)) {
      if (dua.words.isNotEmpty) {
        b
          ..writeln('معنی کلمات:')
          ..writeln();
        for (final w in dua.words) {
          b.writeln('• $w');
        }
        b.writeln();
      }
      if (dua.guidance.isNotEmpty) {
        b
          ..writeln('رهنمود حدیث:')
          ..writeln();
        for (final g in dua.guidance) {
          b.writeln(g);
        }
        b.writeln();
      }
      if (dua.benefits.isNotEmpty) {
        b
          ..writeln('فوائد حدیث:')
          ..writeln();
        for (final f in dua.benefits) {
          b.writeln('• $f');
        }
        b.writeln();
      }
    }
    if (_textContent.contains(DuaShareContent.source) &&
        dua.source.trim().isNotEmpty) {
      b.writeln('منبع: ${dua.source.trim()}');
      b.writeln();
    }
    b.writeln(ShareService.appLine('حصن المسلم'));
    b.writeln(ShareService.channelLine);
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
    const accent = TopicHues.duas;
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'ارسال دعا'),
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
              child: _DuaShareCard(dua: dua, content: _imageContent),
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
  final Set<DuaShareContent> selected;
  final ValueChanged<DuaShareContent> onToggle;
  const _ContentSelector({
    required this.title,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.duas;
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
            for (final c in DuaShareContent.values)
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

/// The unified cream share card, built on [ShareCardShell] — the same design
/// language as every other share surface: flat cream background, warm
/// hairline border, brown labels, icon+title header and one shared footer.
/// Only blocks present in [content] are rendered; شرح blocks render only when
/// the item actually has them.
class _DuaShareCard extends StatelessWidget {
  final DuaModel dua;
  final Set<DuaShareContent> content;
  const _DuaShareCard({
    required this.dua,
    this.content = const {
      DuaShareContent.arabic,
      DuaShareContent.transliteration,
      DuaShareContent.translation,
      DuaShareContent.explanation,
      DuaShareContent.source,
    },
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    const accent = TopicHues.duas;

    final showExplanation =
        content.contains(DuaShareContent.explanation) && dua.hasCommentary;

    return ShareCardShell(
      children: [
        ShareCardHeader(
          icon: Icons.shield_outlined,
          title: dua.title,
          subtitle: 'حصن المسلم',
          accent: accent,
        ),
        const SizedBox(height: 14),
        if (dua.lead.trim().isNotEmpty) ...[
          Text(
            dua.lead.trim(),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              height: 1.8,
              fontStyle: FontStyle.italic,
              color: c.label,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Arabic text
        if (content.contains(DuaShareContent.arabic) &&
            dua.arabicText.trim().isNotEmpty) ...[
          Text(
            dua.arabicText.trim(),
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
        // Transliteration
        if (content.contains(DuaShareContent.transliteration) &&
            dua.transliteration != null &&
            dua.transliteration!.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.record_voice_over_outlined,
            label: 'رونویسی',
            accent: accent,
          ),
          const SizedBox(height: 6),
          Text(
            dua.transliteration!.trim(),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              height: 1.8,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Persian translation
        if (content.contains(DuaShareContent.translation) &&
            dua.translation.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.translate,
            label: 'ترجمه',
            accent: accent,
          ),
          const SizedBox(height: 6),
          Text(
            dua.translation.trim(),
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
        // شرح: word meanings, guidance, benefits
        if (showExplanation) ...[
          if (dua.words.isNotEmpty) ...[
            const ShareCardLabel(
              icon: Icons.spellcheck_outlined,
              label: 'معنی کلمات حدیث',
              accent: accent,
            ),
            const SizedBox(height: 6),
            for (final w in dua.words) _Bullet(tip: w),
            const SizedBox(height: 12),
          ],
          if (dua.guidance.isNotEmpty) ...[
            const ShareCardLabel(
              icon: Icons.compass_calibration_outlined,
              label: 'رهنمود حدیث',
              accent: accent,
            ),
            const SizedBox(height: 6),
            for (final g in dua.guidance)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  g,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13.5),
                    height: 1.9,
                    color: c.muted,
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          if (dua.benefits.isNotEmpty) ...[
            const ShareCardLabel(
              icon: Icons.tips_and_updates_outlined,
              label: 'فوائد حدیث',
              accent: accent,
            ),
            const SizedBox(height: 6),
            for (final f in dua.benefits) _Bullet(tip: f),
            const SizedBox(height: 12),
          ],
        ],
        // Source
        if (content.contains(DuaShareContent.source) &&
            dua.source.trim().isNotEmpty) ...[
          const ShareCardDivider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 15, color: c.label),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  dua.source.trim(),
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
        const ShareCardFooter(section: 'حصن المسلم'),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String tip;
  const _Bullet({required this.tip});

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
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
                color: c.label,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13.5),
                height: 1.8,
                color: c.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
