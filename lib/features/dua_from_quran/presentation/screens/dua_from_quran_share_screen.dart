import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/dua_from_quran/domain/entities/dua_from_quran_entity.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «اشتراک دعا» — renders a قرآن/سنت dua on a single unified cream card —
/// the same visual language as the موسوعه احادیث share image — then lets the
/// user share it as an image (PNG), as formatted text, or copy it.
class DuaFromQuranShareScreen extends StatefulWidget {
  final DuaFromQuran dua;
  final int? number;

  const DuaFromQuranShareScreen({super.key, required this.dua, this.number});

  @override
  State<DuaFromQuranShareScreen> createState() =>
      _DuaFromQuranShareScreenState();
}

/// Content blocks that can be included when sharing a dua (text or image).
enum DuaFromQuranShareContent {
  arabic('متن عربی', Icons.text_fields),
  translation('ترجمه', Icons.translate),
  source('منبع', Icons.menu_book_outlined);

  const DuaFromQuranShareContent(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DuaFromQuranShareScreenState extends State<DuaFromQuranShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  final Set<DuaFromQuranShareContent> _textContent =
      DuaFromQuranShareContent.values.toSet();
  final Set<DuaFromQuranShareContent> _imageContent =
      DuaFromQuranShareContent.values.toSet();

  DuaFromQuran get dua => widget.dua;

  void _toggle(
    Set<DuaFromQuranShareContent> set,
    DuaFromQuranShareContent content,
  ) {
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
        'dua_book_sunnah_${widget.number ?? dua.hashCode}.png',
        text: ShareService.channelBlock,
      );
    } on ShareCaptureException catch (e) {
      AppLogger.warning('dua_from_quran_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('dua_from_quran_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title() =>
      widget.number == null ? 'دعا' : 'دعای شماره ${widget.number}';

  Future<void> _shareText() async {
    final text = _formattedText();
    await ShareService.shareText(
      text,
      subject: '${_title()} — دعا از کتاب و سنت',
    );
  }

  Future<void> _copyText() async {
    if (mounted) await ShareService.copyText(context, _formattedText());
  }

  String _formattedText() {
    final b = StringBuffer()
      ..writeln(_title())
      ..writeln();
    if (_textContent.contains(DuaFromQuranShareContent.arabic) &&
        dua.arabic.trim().isNotEmpty) {
      b
        ..writeln(dua.arabic.trim())
        ..writeln();
    }
    if (_textContent.contains(DuaFromQuranShareContent.translation) &&
        dua.persian.trim().isNotEmpty) {
      b
        ..writeln('ترجمه:')
        ..writeln(dua.persian.trim())
        ..writeln();
    }
    if (_textContent.contains(DuaFromQuranShareContent.source) &&
        dua.source.trim().isNotEmpty) {
      b
        ..writeln('منبع: ${dua.source.trim()}')
        ..writeln();
    }
    b.writeln(ShareService.appLine('دعا از کتاب و سنت'));
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
    const accent = TopicHues.dua;
    final t = TimeThemeKit.of(context).palette;
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'اشتراک دعا'),
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
              child: _DuaShareCard(
                dua: dua,
                number: widget.number,
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
  final Set<DuaFromQuranShareContent> selected;
  final ValueChanged<DuaFromQuranShareContent> onToggle;
  const _ContentSelector({
    required this.title,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.dua;
    final t = TimeThemeKit.of(context).palette;
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
            for (final c in DuaFromQuranShareContent.values)
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
/// language as every other share surface: flat cream background, warm hairline
/// border, brown labels, icon+title header and one shared footer.
class _DuaShareCard extends StatelessWidget {
  final DuaFromQuran dua;
  final int? number;
  final Set<DuaFromQuranShareContent> content;

  const _DuaShareCard({
    required this.dua,
    this.number,
    this.content = const {
      DuaFromQuranShareContent.arabic,
      DuaFromQuranShareContent.translation,
      DuaFromQuranShareContent.source,
    },
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);
    const accent = TopicHues.dua;

    return ShareCardShell(
      children: [
        ShareCardHeader(
          icon: Icons.volunteer_activism_outlined,
          title: number == null ? 'دعا' : 'دعای شماره $number',
          subtitle: 'دعا از کتاب و سنت',
          accent: accent,
        ),
        const SizedBox(height: 14),
        // Arabic text
        if (content.contains(DuaFromQuranShareContent.arabic) &&
            dua.arabic.trim().isNotEmpty) ...[
          Text(
            dua.arabic.trim(),
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
        if (content.contains(DuaFromQuranShareContent.translation) &&
            dua.persian.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.translate,
            label: 'ترجمه',
            accent: accent,
          ),
          const SizedBox(height: 6),
          Text(
            dua.persian.trim(),
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              height: 1.9,
              color: c.body,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Source
        if (content.contains(DuaFromQuranShareContent.source) &&
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
        const ShareCardFooter(section: 'دعا از کتاب و سنت'),
      ],
    );
  }
}
