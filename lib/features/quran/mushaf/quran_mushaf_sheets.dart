import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reading.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/features/quran/services/quran_translation_service.dart';
import 'package:tawheeed/features/quran/mushaf/quran_tafsir_share_screen.dart';
import 'package:tawheeed/features/quran/mushaf/tafsir_text.dart';
import 'package:tawheeed/features/quran/services/tafsir_service.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Bottom sheets extracted from [QuranMushafView] to keep the reader file
/// focused on the mushaf itself: the content manager (translations/tafsirs)
/// and the inline tafsir sheet.

class MushafContentSheet extends ConsumerStatefulWidget {
  const MushafContentSheet({super.key, required this.palette});

  final MushafPalette palette;

  @override
  ConsumerState<MushafContentSheet> createState() => MushafContentSheetState();
}

class MushafContentSheetState extends ConsumerState<MushafContentSheet> {
  List<QuranContentFile> _catalog = [];
  final Set<String> _downloaded = {};
  String? _busy;
  bool _loading = true;
  int? _selectedTafsir;
  String? _selectedTranslation;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Paint immediately from the local catalog: the builtin list is complete
    // and the downloaded set is a cheap directory scan. The hosted manifest
    // is refreshed in the background so a slow network never delays opening
    // this sheet (first open used to block 10s+ on the catalog HTTP fetch).
    await TafsirService.refreshDownloaded();
    final local = QuranContentService.cachedCatalogOrNull ??
        QuranContentService.builtinCatalog;
    final dl = <String>{};
    for (final f in local) {
      if (await QuranContentService.isDownloaded(f)) dl.add(f.fileName);
    }
    final translation = await QuranTranslationService.selectedEntry();
    if (!mounted) return;
    setState(() {
      _catalog = local;
      _downloaded.addAll(dl);
      _loading = false;
      _selectedTafsir =
          TafsirDbInfo.byId(ref.read(tafsirIdProvider))?.id ?? 169;
      _selectedTranslation = translation.id;
    });
    await _refreshHostedCatalog(local);
  }

  /// Fetches the hosted manifest off the critical path and repaints only when
  /// it actually differs from what is already on screen.
  Future<void> _refreshHostedCatalog(List<QuranContentFile> local) async {
    final fresh = await QuranContentService.fetchCatalog();
    if (!mounted || identical(fresh, local)) return;
    await TafsirService.refreshDownloaded();
    final dl = <String>{};
    for (final f in fresh) {
      if (await QuranContentService.isDownloaded(f)) dl.add(f.fileName);
    }
    if (!mounted) return;
    setState(() {
      _catalog = fresh;
      _downloaded
        ..clear()
        ..addAll(dl);
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _download(QuranContentFile file) async {
    setState(() => _busy = file.fileName);
    final path = await QuranContentService.ensureDownloaded(file);
    await TafsirService.refreshDownloaded();
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (path != null) _downloaded.add(file.fileName);
    });
    _snack(path != null
        ? '${file.name} دانلود شد.'
        : 'دانلود ${file.name} ناموفق بود؛ اتصال اینترنت را بررسی کنید.');
  }

  Future<void> _delete(QuranContentFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف فایل'),
        content: Text(
          '«${file.name}» از دستگاه حذف شود؟ برای استفادهٔ دوباره باید دوباره دانلود شود.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = file.fileName);
    // Close any open sqlite handle before deleting the file — otherwise the
    // next getTafsir() hits a deleted inode until the app restarts.
    TafsirService.close();
    if (file.isTranslation) QuranTranslationService.evict(file.fileName);
    await QuranContentService.deleteDownloaded(file);
    await TafsirService.refreshDownloaded();
    if (!mounted) return;
    setState(() {
      _busy = null;
      _downloaded.remove(file.fileName);
    });
    _snack('${file.name} حذف شد.');
  }

  Future<void> _selectTafsir(QuranContentFile file) async {
    final id = TafsirDbInfo.idForContentFile(file);
    setState(() => _selectedTafsir = id);
    await ref.read(settingsProvider.notifier).setTafsirId(id);
    _snack('${file.name} انتخاب شد.');
  }

  Future<void> _selectTranslation(QuranContentFile file) async {
    setState(() => _selectedTranslation = file.id);
    await QuranTranslationService.setSelectedId(file.id);
    _snack('${file.name} انتخاب شد.');
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final translations = _catalog.where((f) => f.isTranslation).toList();
    final tafsirs = _catalog.where((f) => f.isTafsir).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    'ترجمه و تفاسیر',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.surfaceText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'یک بار دانلود کنید؛ همیشه آفلاین در دسترس است.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: palette.surfaceText.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.accent),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_catalog.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'هیچ محتوایی در دسترس نیست.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: palette.surfaceText,
                  ),
                ),
              )
            else
              Expanded(
                child: MushafSheetScrollable(
                  builder: (context, physics) => ListView(
                    physics: physics,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final f in translations)
                        _contentTile(
                          f,
                          subtitle: _downloaded.contains(f.fileName)
                              ? 'دانلود شده • ${NumberFormat.normalizeDigits(f.sizeMB.toStringAsFixed(1))} MB'
                              : 'حجم دانلود: ${NumberFormat.normalizeDigits(f.sizeMB.toStringAsFixed(1))} MB',
                          selected: _downloaded.contains(f.fileName) &&
                              _selectedTranslation == f.id,
                          onSelected: _downloaded.contains(f.fileName)
                              ? () => _selectTranslation(f)
                              : null,
                          trailing: _actionFor(f),
                        ),
                      if (tafsirs.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                          child: Text(
                            'تفاسیر',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.surfaceText.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        for (final f in tafsirs)
                          _contentTile(
                            f,
                            subtitle: _downloaded.contains(f.fileName)
                                ? 'دانلود شده • ${NumberFormat.normalizeDigits(f.sizeMB.toStringAsFixed(1))} MB'
                                : 'حجم دانلود: ${NumberFormat.normalizeDigits(f.sizeMB.toStringAsFixed(1))} MB',
                            selected: _downloaded.contains(f.fileName) &&
                                _selectedTafsir ==
                                    TafsirDbInfo.idForContentFile(f),
                            onSelected: _downloaded.contains(f.fileName)
                                ? () => _selectTafsir(f)
                                : null,
                            trailing: _actionFor(f),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contentTile(
    QuranContentFile file, {
    required String subtitle,
    required Widget trailing,
    bool selected = false,
    VoidCallback? onSelected,
  }) {
    // The row follows the app's shared list language (the Home/More kit): the
    // same duotone identity tile the reciter list wears, with the language tag
    // kept as a chip after the name.
    return QuranKitRow(
      palette: widget.palette,
      icon: file.isTafsir ? Icons.menu_book_rounded : Icons.translate,
      title: file.name,
      badge: file.langLabel.isEmpty
          ? null
          : QuranLangChip(lang: file.lang ?? '', label: file.langLabel),
      subtitle: subtitle,
      selected: selected,
      trailing: trailing,
      onTap: onSelected,
    );
  }

  Widget _actionFor(QuranContentFile file) {
    final palette = widget.palette;
    if (_busy == file.fileName) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (_downloaded.contains(file.fileName)) {
      return IconButton(
        tooltip: 'حذف',
        icon: Icon(Icons.delete_outline, color: palette.surfaceText),
        onPressed: () => _delete(file),
      );
    }
    return IconButton(
      tooltip: 'دانلود',
      icon: Icon(Icons.download_for_offline_outlined, color: palette.accent),
      onPressed: () => _download(file),
    );
  }
}

// ── Tafsir sheet ────────────────────────────────────────────────────────────

/// The small language pill that sits after a translation/tafsir row's name
/// (فارسی / عربی / کوردی …). Kept as a chip — it qualifies the name without
/// competing with it. Shared by the content manager and both reader pickers,
/// so a language reads the same wherever content is listed.
class QuranLangChip extends StatelessWidget {
  const QuranLangChip({super.key, required this.lang, required this.label});

  final String lang;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (lang) {
      'ar' => const Color(0xFF5C6BC0),
      'ku' => const Color(0xFF8E24AA),
      _ => const Color(0xFF1F7A63),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class MushafTafsirSheet extends ConsumerStatefulWidget {
  const MushafTafsirSheet({
    super.key,
    required this.surah,
    required this.verse,
    required this.palette,
  });

  final int surah;
  final int verse;
  final MushafPalette palette;

  @override
  ConsumerState<MushafTafsirSheet> createState() => MushafTafsirSheetState();
}

class MushafTafsirSheetState extends ConsumerState<MushafTafsirSheet> {
  String? _text;
  bool _loading = true;
  String? _error;
  int _tafsirId = 169;
  bool _refreshNeeded = true;
  bool _pickerOpen = false;
  late int _surah = widget.surah;
  late int _verse = widget.verse;

  @override
  void initState() {
    super.initState();
    _tafsirId = ref.read(tafsirIdProvider);
    _init();
  }

  @override
  void didUpdateWidget(covariant MushafTafsirSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surah != widget.surah || oldWidget.verse != widget.verse) {
      _surah = widget.surah;
      _verse = widget.verse;
      _load();
    }
  }

  Future<void> _init() async {
    // Load the tafsir text first (fast: bundled/local DB). Refreshing the
    // downloaded-tafsir list is a cheap local scan, but it must never block
    // the first paint of the sheet.
    await _load();
    if (!mounted) return;
    unawaited(TafsirService.refreshDownloaded().then((_) {
      if (mounted) setState(() => _refreshNeeded = false);
    }));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final text =
        await TafsirService.getTafsir(_surah, _verse, tafsirId: _tafsirId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (text != null) {
        _text = text;
      } else {
        _error = TafsirDbInfo.available.isEmpty
            ? 'هیچ تفسیری دانلود نشده است.\nاز دکمهٔ «ترجمه و تفاسیر» در بالای صفحه، یک تفسیر را دانلود کنید.'
            : 'تفسیر این آیه در دسترس نیست.';
      }
    });
  }

  /// Name of the tafsir being read: the downloaded row when known, otherwise
  /// the bundled المختصر that [TafsirService.databaseFor] falls back to for
  /// the default id.
  String get _tafsirName {
    final current = TafsirDbInfo.byId(_tafsirId);
    if (current != null) return current.name;
    return _catalogFileFor(_tafsirFile)?.name ?? 'تفسیر';
  }

  /// The file the current id resolves to; empty when the id is unknown.
  String get _tafsirFile {
    final current = TafsirDbInfo.byId(_tafsirId);
    if (current != null) return current.fileName;
    return _tafsirId == TafsirService.defaultTafsirId ? 'mokhtasar_fa.db' : '';
  }

  bool get _canPrev => !(_surah == 1 && _verse == 1);

  bool get _canNext => !(_surah == 114 && _verse == getVerseCount(114));

  /// Step one verse back, crossing into the previous surah's last verse.
  void _goPrev() {
    if (!_canPrev || _loading) return;
    setState(() {
      if (_verse > 1) {
        _verse--;
      } else {
        _surah--;
        _verse = getVerseCount(_surah);
      }
    });
    _load();
  }

  /// Step one verse forward, crossing into the next surah's first verse.
  void _goNext() {
    if (!_canNext || _loading) return;
    setState(() {
      if (_verse < getVerseCount(_surah)) {
        _verse++;
      } else {
        _surah++;
        _verse = 1;
      }
    });
    _load();
  }

  Future<void> _select(int id, String name) async {
    setState(() {
      _tafsirId = id;
      _text = null;
      _pickerOpen = false;
    });
    await ref.read(settingsProvider.notifier).setTafsirId(id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('$name انتخاب شد.'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  /// Shares the current verse's tafsir as text and as an image.
  Future<void> _share() async {
    final text = _text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تفسیر این آیه برای اشتراک در دسترس نیست.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final name = _tafsirName;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranTafsirShareScreen(
          surah: _surah,
          initialFrom: _verse,
          initialTo: _verse,
          tafsirId: _tafsirId,
          tafsirName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final available =
        _refreshNeeded ? const <TafsirDbInfo>[] : TafsirDbInfo.available;
    final current = TafsirDbInfo.byId(_tafsirId);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height *
              kMushafContentSheetHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MushafContentSheetHeader.compact(
              palette: palette,
              // The surah rides the title, so the sheet spends one chrome row
              // on naming the reading and one action — the page turns live at
              // the foot, where the translation sheet keeps them.
              title: 'تفسیر آیهٔ '
                  '${NumberFormat.ltrIsolated(NumberFormat.en(_verse))} · '
                  '${getSurahNameArabic(_surah)}',
              actions: [
                MushafSheetAction(
                  palette: palette,
                  icon: Icons.share_outlined,
                  label: 'اشتراک',
                  enabled: !_loading && _text != null,
                  onTap: _share,
                ),
              ],
              bottom: available.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: QuranKitRow(
                        palette: palette,
                        icon: Icons.menu_book_rounded,
                        title: _tafsirName,
                        badge: _langBadgeFor(_tafsirFile),
                        subtitle: _pickerOpen
                            ? 'یک تفسیر را انتخاب کنید'
                            : 'برای تغییر تفسیر لمس کنید',
                        selected: _pickerOpen,
                        trailing: Icon(
                          _pickerOpen ? Icons.expand_less : Icons.expand_more,
                          color: palette.surfaceMuted,
                        ),
                        onTap: () =>
                            setState(() => _pickerOpen = !_pickerOpen),
                      ),
                    ),
            ),
            Expanded(
              child: _pickerOpen
                  ? MushafSheetScrollable(
                      builder: (context, physics) => ListView(
                        physics: physics,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: [
                          for (final t in available)
                            QuranKitRow(
                              palette: palette,
                              icon: Icons.menu_book_rounded,
                              title: t.name,
                              badge: _langBadgeFor(t.fileName),
                              subtitle: t.id == current?.id
                                  ? 'تفسیر فعال'
                                  : 'برای انتخاب لمس کنید',
                              selected: t.id == current?.id,
                              onTap: () {
                                if (t.id == current?.id) {
                                  setState(() => _pickerOpen = false);
                                  return;
                                }
                                _select(t.id, t.name);
                              },
                            ),
                        ],
                      ),
                    )
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: AppTheme.scaledFontSize(context, 13),
                                  height: 1.7,
                                  color: palette.surfaceText,
                                ),
                              ),
                            )
                          // The commentary is the page: full measure, no card
                          // around it and no rail beside it — the verse turns
                          // sit at the foot, where the translation sheet keeps
                          // them. [SelectionArea] lets the reader copy a
                          // passage without changing a single run's style.
                          : SelectionArea(
                              child: MushafSheetScroll(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // The ayah reads the way the reader
                                    // already knows it — the app face, a step
                                    // larger — and the tafsir follows
                                    // underneath, opened by the page's one
                                    // ornament instead of by a box.
                                    MushafPassageAyah(
                                      text: _bundledArabicVerse(_surah, _verse),
                                      palette: palette,
                                      baseSize: 19,
                                    ),
                                    const SizedBox(height: 22),
                                    MushafRuleOrnament(palette: palette),
                                    const SizedBox(height: 12),
                                    Text(
                                      'تفسیر — $_tafsirName',
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 13),
                                        height: 1.5,
                                        fontWeight: FontWeight.w800,
                                        color: palette.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    TafsirText(
                                      _text ?? '',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 14),
                                        height: 1.95,
                                        color: palette.surfaceText,
                                      ),
                                      arabicStyle: TextStyle(
                                        fontFamily: 'Amiri',
                                        fontFamilyFallback: const ['Calibri'],
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 17),
                                        height: 2.0,
                                        fontWeight: FontWeight.w600,
                                        color: mushafAyahInk(palette),
                                      ),
                                      honorificStyle: TextStyle(
                                        fontFamily: 'Amiri',
                                        fontFamilyFallback: const ['Calibri'],
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 15),
                                        height: 1.9,
                                        color: palette.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    // The reading closes on the same mark it
                                    // opened with, at a quieter strength — a
                                    // printed page ends, it does not scroll
                                    // into nothing.
                                    Center(
                                      child: MushafDiamond(
                                        palette: palette,
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
            ),
            // Outside the scroll so the turns never scroll away, and outside
            // the loading branch so they stay put (dimmed) while the verse
            // loads — the same foot the translation sheet holds its pager on.
            if (!_pickerOpen)
              MushafSheetPager(
                palette: palette,
                page: getPageNumber(_surah, _verse),
                previousLabel: 'آیهٔ قبلی',
                nextLabel: 'آیهٔ بعدی',
                onPrevious: _canPrev ? _goPrev : null,
                onNext: _canNext ? _goNext : null,
                busy: _loading,
              ),
          ],
        ),
      ),
    );
  }
}

String _bundledArabicVerse(int surah, int verse) {
  for (final row in quran) {
    if (row['sora'] == surah && row['aya_no'] == verse) {
      final text = row['aya_text_emlaey'] ?? row['aya_text'] ?? '';
      return text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return '';
}

/// Catalog row for a content file, read from the network-free catalog.
QuranContentFile? _catalogFileFor(String fileName) {
  if (fileName.isEmpty) return null;
  final catalog = QuranContentService.cachedCatalogOrNull ??
      QuranContentService.builtinCatalog;
  for (final f in catalog) {
    if (f.fileName == fileName) return f;
  }
  return null;
}

/// The language pill for a content file, or nothing when it is unknown.
Widget? _langBadgeFor(String fileName) {
  final file = _catalogFileFor(fileName);
  if (file == null || file.langLabel.isEmpty) return null;
  return QuranLangChip(lang: file.lang ?? '', label: file.langLabel);
}
