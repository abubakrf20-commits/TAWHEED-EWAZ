import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/tafsir_text.dart';
import 'package:tawheeed/features/quran/services/tafsir_markup.dart';
import 'package:tawheeed/features/quran/services/tafsir_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «اشتراک‌گذاری تفسیر» — lets the user pick a consecutive range of ayahs of
/// one surah (defaulting to the verse they came from) and share each ayah's
/// Arabic text along with its tafsir (Persian commentary) on a single unified
/// cream card — as an image (PNG), as formatted text, or copied — the same
/// experience as the حصن المسلم share screen and the ayah share screen.
class QuranTafsirShareScreen extends StatefulWidget {
  final int surah;
  final int initialFrom;
  final int initialTo;
  final int tafsirId;
  final String tafsirName;
  const QuranTafsirShareScreen({
    super.key,
    required this.surah,
    required this.initialFrom,
    required this.initialTo,
    required this.tafsirId,
    required this.tafsirName,
  });

  @override
  State<QuranTafsirShareScreen> createState() => _QuranTafsirShareScreenState();
}


class _QuranTafsirShareScreenState extends State<QuranTafsirShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;

  int? _resolvedFrom;
  int? _resolvedTo;
  Map<int, String> _tafsirs = const {};

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
    unawaited(_loadTafsirs());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTafsirs() async {
    final from = _resolvedFrom;
    final to = _resolvedTo;
    if (from == null || to == null) return;
    final map = await TafsirService.getTafsirForRange(
      widget.surah,
      from,
      to,
      tafsirId: widget.tafsirId,
    );
    if (mounted) setState(() => _tafsirs = map);
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
    unawaited(_loadTafsirs());
  }

  String get _surahNameAr => getSurahNameArabic(widget.surah);

  String _fa(int n) => NumberFormat.toLatin('$n');

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
    if (f == t) return 'سورهٔ $_surahNameAr — آیهٔ ${_fa(f)}';
    return 'سورهٔ $_surahNameAr — آیات ${_fa(f)} تا ${_fa(t)}';
  }

  String get _title {
    if (_resolvedFrom == null || _resolvedTo == null) return '';
    return 'تفسیر ${widget.tafsirName.trim()} — $_headerTitle';
  }

  /// Max verses per shared image: each ayah adds an Arabic line plus a
  /// paragraph of tafsir, and a whole-surah card would rasterize into a
  /// multi-thousand-pixel PNG and OOM on low-end devices. Longer ranges can
  /// still be shared as text.
  static const int _maxImageVerses = 15;

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
      await ShareService.sharePng(bytes, 'tafsir_${widget.surah}_${f}_$t.png');
    } on ShareCaptureException catch (e) {
      AppLogger.warning('quran_tafsir_share_screen', 'error: $e');
      if (mounted) ShareService.showImageFailure(context, e.message);
    } catch (_) {
      AppLogger.warning('quran_tafsir_share_screen', 'operation failed');
      if (mounted) ShareService.showImageFailure(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    final text = _formattedText();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('برای این محدوده تفسیری یافت نشد'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    await ShareService.shareText(text, subject: _title);
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
      ..writeln('تفسیر — $_title')
      ..writeln();
    var hasContent = false;
    for (final v in verses) {
      final tafsir = _tafsirs[v]?.trim() ?? '';
      if (tafsir.isEmpty) continue;
      hasContent = true;
      final ar = _arabic(v).trim();
      if (ar.isNotEmpty) b.writeln('﴿ $ar ﴾');
      b.writeln('تفسیر (${_fa(v)}):');
      b.writeln(TafsirMarkup.strip(tafsir));
      b.writeln();
    }
    if (!hasContent) return '';
    b.writeln(ShareService.appLine('تفسیر قرآن'));
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
        appBar: const SectionAppBar(title: 'اشتراک‌گذاری تفسیر'),
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
            RepaintBoundary(
              key: _cardKey,
              // The shared image always uses the light cream design, even in
              // dark mode, so the exported PNG matches the brand card.
              child: Theme(
                data: Theme.of(context).copyWith(brightness: Brightness.light),
                child: _TafsirShareCard(
                  title: _title,
                  verses: _rangeVerses,
                  arabic: _arabic,
                  tafsirs: _tafsirs,
                  fa: _fa,
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

/// The unified cream share card — the shared [ShareCardShell] with an
/// icon header, the picked ayahs in Amiri and each tafsir under its own
/// kit label row. The footer is the one app signature line.
class _TafsirShareCard extends StatelessWidget {
  final String title;
  final List<int> verses;
  final String Function(int) arabic;
  final Map<int, String> tafsirs;
  final String Function(int) fa;
  const _TafsirShareCard({
    required this.title,
    required this.verses,
    required this.arabic,
    required this.tafsirs,
    required this.fa,
  });

  @override
  Widget build(BuildContext context) {
    final c = ShareCardColors.of(context);

    return ShareCardShell(
      children: [
        ShareCardHeader(
          icon: Icons.menu_book_outlined,
          title: title.isEmpty ? 'قرآن کریم' : title,
          subtitle: 'تفسیر',
          accent: SectionHues.quran,
        ),
        const SizedBox(height: 12),
        ..._verseBlocks(context: context, c: c),
        const SizedBox(height: 2),
        const ShareCardFooter(section: 'تفسیر قرآن'),
      ],
    );
  }

  List<Widget> _verseBlocks({
    required BuildContext context,
    required ShareCardColors c,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      final ar = arabic(v).trim();
      final tafsir = tafsirs[v]?.trim() ?? '';
      if (ar.isNotEmpty) {
        widgets.add(Text(
          ar,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Amiri',
            fontFamilyFallback: const ['Calibri'],
            fontSize: AppTheme.scaledFontSize(context, 19),
            height: 2.0,
            fontWeight: FontWeight.w600,
            color: c.head,
          ),
        ));
        widgets.add(const SizedBox(height: 8));
      }
      if (tafsir.isNotEmpty) {
        widgets.add(ShareCardLabel(
          icon: Icons.menu_book_outlined,
          label: 'تفسیر (${fa(v)})',
          accent: SectionHues.quran,
        ));
        widgets.add(const SizedBox(height: 6));
        widgets.add(TafsirText(
          tafsir,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14),
            height: 1.9,
            color: c.body,
          ),
          arabicStyle: TextStyle(
            fontFamily: 'Amiri',
            fontFamilyFallback: const ['Calibri'],
            fontSize: AppTheme.scaledFontSize(context, 17),
            height: 2.0,
            fontWeight: FontWeight.w600,
            color: c.head,
          ),
          honorificStyle: TextStyle(
            fontFamily: 'Amiri',
            fontFamilyFallback: const ['Calibri'],
            fontSize: AppTheme.scaledFontSize(context, 15),
            height: 1.9,
            color: c.head,
          ),
        ));
      }
      if (i != verses.length - 1) {
        widgets.add(const SizedBox(height: 10));
        widgets.add(const ShareCardDivider());
        widgets.add(const SizedBox(height: 10));
      } else {
        widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }
}
