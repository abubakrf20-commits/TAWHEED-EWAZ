import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/quran_translation_reader.dart';
import 'package:tawheeed/features/quran/services/quran_translation_service.dart';
import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «اشتراک‌گذاری آیه‌ها» — lets the user pick a consecutive range of ayahs of
/// one surah (e.g. آل‌عمران 15 تا 20), with or without the selected translation,
/// and share them on a single unified cream card as an image (PNG), as
/// formatted text, or copy the text — the same experience as the حصن المسلم
/// share screen ([AdhkarShareScreen] / [DuaShareScreen]).
class QuranAyahShareScreen extends StatefulWidget {
  final int surah;
  final int initialFrom;
  final int initialTo;
  const QuranAyahShareScreen({
    super.key,
    required this.surah,
    required this.initialFrom,
    required this.initialTo,
  });

  @override
  State<QuranAyahShareScreen> createState() => _QuranAyahShareScreenState();
}


/// The exported card's social format (upgrade wave-2 #6): the three shapes a
/// reader actually posts — square feed, tall story, wide banner. The content
/// is identical; only width and typography breathe differently.
enum AyahShareLayout { square, story, banner }

class _QuranAyahShareScreenState extends State<QuranAyahShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  AyahShareLayout _layout = AyahShareLayout.square;

  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  bool _withTranslation = true;

  /// The translation this share uses (wave-2 follow-up, user request:
  /// «اشتراک گذاری ترجمه هم اضاف کن با گزینه انتخاب ترجمه مثل اشتراک گذاری
  /// تفسیر»). Null = the app's selected translation; a picked entry pins the
  /// share to THAT translation without touching the reader's own setting.
  QuranContentFile? _shareTranslation;

  int? _resolvedFrom;
  int? _resolvedTo;
  Map<int, String> _translations = const {};

  int get _maxVerse => getVerseCount(widget.surah);
  bool get _rangeValid =>
      _resolvedFrom != null &&
      _resolvedTo != null &&
      _resolvedTo! >= _resolvedFrom!;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: '${widget.initialFrom}');
    _toCtrl = TextEditingController(text: '${widget.initialTo}');
    _resolvedFrom = widget.initialFrom;
    _resolvedTo = widget.initialTo;
    unawaited(_loadTranslations());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTranslations() async {
    final from = _resolvedFrom;
    final to = _resolvedTo;
    if (!_withTranslation || from == null || to == null) {
      if (mounted && _translations.isNotEmpty) {
        setState(() => _translations = const {});
      }
      return;
    }
    final fileName = _shareTranslation?.fileName ??
        await QuranTranslationService.selectedFileName();
    final map = await QuranTranslationReader.getTranslationsForRange(
        fileName, widget.surah, from, to);
    if (mounted) setState(() => _translations = map);
  }

  void _applyRange() {
    final a = int.tryParse(NumberFormat.normalizeDigits(_fromCtrl.text.trim()));
    final b = int.tryParse(NumberFormat.normalizeDigits(_toCtrl.text.trim()));
    if (a == null ||
        b == null ||
        a < 1 ||
        b < 1 ||
        a > _maxVerse ||
        b > _maxVerse ||
        a > b) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('محدودهٔ آیهٔ واردشده نامعتبر است'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _resolvedFrom = a;
      _resolvedTo = b;
    });
    unawaited(_loadTranslations());
  }

  void _toggleTranslation(bool value) {
    setState(() => _withTranslation = value);
    unawaited(_loadTranslations());
  }

  String get _surahName => getSurahNameArabic(widget.surah);

  List<int> get _rangeVerses {
    final f = _resolvedFrom, t = _resolvedTo;
    if (f == null || t == null) return const [];
    return [for (var v = f; v <= t; v++) v];
  }

  String _arabic(int verse) {
    for (final row in quran) {
      if (row['sora'] == widget.surah && row['aya_no'] == verse) {
        final text = row['aya_text_emlaey'] ?? row['aya_text'] ?? '';
        return text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return '';
  }

  String get _headerTitle {
    final f = _resolvedFrom, t = _resolvedTo;
    if (f == null || t == null) return '';
    if (f == t) return 'سورهٔ $_surahName — آیهٔ ${_fa(f)}';
    return 'سورهٔ $_surahName — آیات ${_fa(f)} تا ${_fa(t)}';
  }

  String _fa(int n) => NumberFormat.toLatin('$n');

  /// Max verses per shared image: a whole-surah card would rasterize into a
  /// multi-thousand-pixel PNG and OOM on low-end devices. Longer ranges can
  /// still be shared as text.
  static const int _maxImageVerses = 50;

  Future<void> _shareImage() async {
    if (_busy) return;
    if (!_rangeValid) {
      _applyRange();
      return;
    }
    if (_rangeVerses.length > _maxImageVerses) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'تصویر حداکثر ${_fa(_maxImageVerses)} آیه را در بر می‌گیرد؛ محدوده را کوچک‌تر کنید یا از «ارسال متن» استفاده کنید.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _pumpFrames();
      final bytes = await ShareService.captureCard(
        _cardKey,
      );
      final f = _resolvedFrom!, t = _resolvedTo!;
      await ShareService.sharePng(bytes, 'ayah_${widget.surah}_${f}_$t.png');
    } on ShareCaptureException catch (e) {
      AppLogger.warning('quran_ayah_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('quran_ayah_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    final text = _formattedText();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('برای این محدوده متنی یافت نشد'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await ShareService.shareText(text, subject: _headerTitle);
  }

  Future<void> _copyText() async {
    final text = _formattedText();
    if (text.isEmpty) return;
    if (mounted) await ShareService.copyText(context, text);
  }

  String _formattedText() {
    final verses = _rangeVerses;
    if (verses.isEmpty) return '';
    final b = StringBuffer()
      ..writeln('🕌 $_headerTitle')
      ..writeln();
    for (final v in verses) {
      final ar = _arabic(v).trim();
      if (ar.isEmpty) continue;
      b.writeln('﴿ $ar ﴾');
      if (_withTranslation) {
        final t = _translations[v];
        if (t != null && t.trim().isNotEmpty) b.writeln('(${_fa(v)}) $t');
      }
      b.writeln();
    }
    b.writeln(ShareService.appLine('قرآن'));
    return b.toString().trim();
  }

  Future<void> _pumpFrames() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'اشتراک‌گذاری آیات'),
        body: ListView(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 24),
          children: [
            Text(
              'سورهٔ ${getSurahNameArabic(widget.surah)} — '
              'محدودهٔ آیات را انتخاب کنید (1 تا ${_fa(_maxVerse)})، '
              'سپس به‌صورت تصویر، متن یا کپی ارسال نمایید.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RangeField(
                    controller: _fromCtrl,
                    label: 'از آیه',
                    onSubmitted: (_) => _applyRange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RangeField(
                    controller: _toCtrl,
                    label: 'تا آیه',
                    onSubmitted: (_) => _applyRange(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _applyRange,
                  style: IconButton.styleFrom(
                    backgroundColor: ShareCardPalette.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 20),
                  tooltip: 'اعمال محدوده',
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              value: _withTranslation,
              activeThumbColor: ShareCardPalette.accent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('با ترجمه',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w600)),
              subtitle: Text('نشان دادن ترجمهٔ انتخاب‌شده زیر هر آیه',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textSecondary)),
              onChanged: _toggleTranslation,
            ),
            // The translation picker (user request: «با گزینه انتخاب ترجمه
            // مثل اشتراک گذاری تفسیر») — visible only when the share carries
            // a translation at all.
            if (_withTranslation)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ShareTranslationPicker(
                  selected: _shareTranslation,
                  onSelected: (entry) {
                    setState(() => _shareTranslation = entry);
                    unawaited(_loadTranslations());
                  },
                ),
              ),
            if (!_rangeValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('محدودهٔ معتبری انتخاب نشده است',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color:
                            isDark ? AppTheme.darkError : AppTheme.lightError)),
              ),
            const SizedBox(height: 10),
            // The format picker (wave-2 #6) — applies to the preview below
            // and to the exported PNG, so what you see is what you send.
            Row(
              children: [
                for (final l in AyahShareLayout.values) ...[
                  Expanded(
                    child: _LayoutChip(
                      layout: l,
                      selected: _layout == l,
                      onSelected: () => setState(() => _layout = l),
                    ),
                  ),
                  if (l != AyahShareLayout.banner) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            RepaintBoundary(
              key: _cardKey,
              // The shared image always uses the light cream design, even in
              // dark mode, so the exported PNG matches the brand card.
              child: Theme(
                data: Theme.of(context).copyWith(brightness: Brightness.light),
                child: _AyahShareCard(
                  title: _headerTitle,
                  verses: _rangeVerses,
                  arabic: _arabic,
                  translations: _withTranslation ? _translations : const {},
                  fa: _fa,
                  layout: _layout,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ShareCardPalette.accent,
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
                      foregroundColor: ShareCardPalette.accent,
                      side: BorderSide(color: ShareCardPalette.accent.withValues(alpha: 0.5)),
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
                foregroundColor: t.textSecondary,
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
      ),
    );
  }
}

class _RangeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onSubmitted;
  const _RangeField({
    required this.controller,
    required this.label,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.scaledFontSize(context, 15)),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 13),
            color: TimeThemeKit.of(context).palette.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

/// The unified cream share card — the shared [ShareCardShell] with an icon
/// header, the picked ayahs in Amiri and their translations below. The footer
/// is the one app signature line.
class _AyahShareCard extends StatelessWidget {
  final String title;
  final List<int> verses;
  final String Function(int) arabic;
  final Map<int, String> translations;
  final String Function(int) fa;
  final AyahShareLayout layout;
  const _AyahShareCard({
    required this.title,
    required this.verses,
    required this.arabic,
    required this.translations,
    required this.fa,
    this.layout = AyahShareLayout.square,
  });

  /// Export width per format: square and story read best at feed width;
  /// the banner is a wide strip.
  double get _width => switch (layout) {
        AyahShareLayout.square => 420,
        AyahShareLayout.story => 420,
        AyahShareLayout.banner => 720,
      };

  double get _arabicSize => switch (layout) {
        AyahShareLayout.banner => 17,
        AyahShareLayout.story => 21,
        _ => 19,
      };

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);

    return SizedBox(
      width: _width,
      child: ShareCardShell(
        children: [
          ShareCardHeader(
            icon: Icons.menu_book_outlined,
            title: title.isNotEmpty ? title : 'سوره‌های قرآن',
            subtitle: 'قرآن کریم',
            accent: SectionHues.quran,
          ),
          const SizedBox(height: 14),
          for (final v in verses) ...[
            if (arabic(v).trim().isNotEmpty) ...[
              Text(
                arabic(v).trim(),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  // Amiri renders the imlaey Arabic with proper diacritics;
                  // Calibri (a Latin font) is only a fallback here.
                  fontFamily: 'Amiri',
                  fontFamilyFallback: const ['Calibri'],
                  fontSize: AppTheme.scaledFontSize(context, _arabicSize),
                  height: layout == AyahShareLayout.story ? 2.2 : 2.0,
                  fontWeight: FontWeight.w600,
                  color: c.head,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
              ),
            ],
            if ((translations[v] ?? '').trim().isNotEmpty) ...[
              Text(
                '(${fa(v)}) ${(translations[v] ?? '').trim()}',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  height: 1.8,
                  color: c.body,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 10),
          const ShareCardFooter(section: 'قرآن'),
        ],
      ),
    );
  }
}

/// One format chip; the label names the shape a reader recognizes.
class _LayoutChip extends StatelessWidget {
  const _LayoutChip({
    required this.layout,
    required this.selected,
    required this.onSelected,
  });

  final AyahShareLayout layout;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final (icon, label) = switch (layout) {
      AyahShareLayout.square => (Icons.crop_square_rounded, 'مربع'),
      AyahShareLayout.story => (Icons.phone_iphone_rounded, 'استوری'),
      AyahShareLayout.banner => (Icons.crop_16_9_rounded, 'بنر'),
    };
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      avatar: Icon(icon, size: 15),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w600,
        ),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      selectedColor: ShareCardPalette.accent.withValues(alpha: .18),
      side: BorderSide(
        color: selected ? ShareCardPalette.accent : t.outline,
      ),
    );
  }
}

/// The share's translation picker (user request): one row showing the
/// translation this share will carry, opening a sheet of the catalog's
/// translations with their availability. Selecting one pins THE SHARE to it
/// — the reader's own translation setting is untouched, the same way the
/// tafsir share picks a tafsir without moving the reader's.
class _ShareTranslationPicker extends StatelessWidget {
  const _ShareTranslationPicker({
    required this.selected,
    required this.onSelected,
  });

  final QuranContentFile? selected;
  final ValueChanged<QuranContentFile> onSelected;

  Future<void> _pick(BuildContext context) async {
    final t = TimeThemeKit.of(context).palette;
    final entries = QuranTranslationService.available();
    final availability = <QuranContentFile, bool>{};
    for (final e in entries) {
      // Bundled answers instantly (no IO). Downloaded probes are capped: a
      // wedged filesystem must degrade to «دانلود نشده», not hang the sheet.
      availability[e] = QuranTranslationReader.isBundled(e.fileName) ||
          await QuranTranslationReader.isAvailable(e.fileName).timeout(
              const Duration(milliseconds: 300),
              onTimeout: () => false);
    }
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<QuranContentFile>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'ترجمهٔ اشتراک‌گذاری',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(ctx, 14),
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
            ),
            for (final e in entries)
              ListTile(
                dense: true,
                leading: Icon(Icons.translate_rounded,
                    size: 20,
                    color: availability[e] == true
                        ? t.tertiary
                        : t.textMuted),
                title: Text(
                  e.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(ctx, 13.5),
                    fontWeight: FontWeight.w600,
                    color: availability[e] == true
                        ? t.textPrimary
                        : t.textMuted,
                  ),
                ),
                subtitle: Text(
                  availability[e] == true
                      ? e.langLabel
                      : '${e.langLabel} — دانلود نشده',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(ctx, 11.5),
                    color: t.textMuted,
                  ),
                ),
                trailing: selected?.id == e.id
                    ? Icon(Icons.check_rounded,
                        size: 20, color: t.tertiary)
                    : null,
                // An unavailable entry does not pretend: it stays put and the
                // hint says to download it from the content sheet.
                enabled: availability[e] == true,
                onTap: availability[e] == true
                    ? () => Navigator.pop(ctx, e)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return FutureBuilder<String>(
      future: QuranTranslationService.selectedEntry().then((e) => e.name),
      builder: (context, snap) {
        final name = selected?.name ?? snap.data ?? 'ترجمهٔ برنامه';
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pick(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.translate_rounded,
                    size: 18, color: t.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ترجمهٔ اشتراک: $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    size: 20, color: t.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
