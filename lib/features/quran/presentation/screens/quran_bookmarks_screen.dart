import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/data/daos/quran_bookmark_dao.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/mushaf/quran_paper_chrome.dart';
import 'package:tawheeed/features/quran/presentation/providers/quran_bookmark_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The bookmark list, in the reader's own colours.
///
/// It takes the [MushafPalette] the reader opened it from instead of reading
/// the app's time theme (report §6.1): the mushaf is a paper/night reader, so
/// opening this list from a night page used to cross-fade into the light theme
/// — and its rows wore the theme's flat accent tile rather than the reader's
/// duotone one. Now the whole screen (chrome, paper, empty state, rows, the
/// swipe-delete and the undo bar) follows the paper it was opened on, and each
/// row is the shared [QuranKitRow] every other mushaf list uses.
class QuranBookmarksScreen extends ConsumerStatefulWidget {
  const QuranBookmarksScreen({
    super.key,
    required this.palette,
    this.onGoToPage,
  });

  /// The paper the reader was on when they opened this list.
  final MushafPalette palette;

  final void Function(int surah, int ayah)? onGoToPage;

  @override
  ConsumerState<QuranBookmarksScreen> createState() =>
      _QuranBookmarksScreenState();
}

class _QuranBookmarksScreenState extends ConsumerState<QuranBookmarksScreen> {
  /// Sort/filter controls (upgrade wave-1 #4): the reader's marks default to
  /// newest-first, with a one-tap flip to Mushaf order and a «only the ones
  /// I annotated» filter for when the list outgrows a screen.
  bool _sortBySurah = false;
  bool _onlyNoted = false;

  MushafPalette get palette => widget.palette;

  /// Destructive ink for the swipe-delete. The mushaf palette carries no error
  /// hue on purpose (it is paper, not semantic chrome), so the app's own error
  /// red is picked by the paper rather than read off the time theme this screen
  /// no longer follows.
  Color get _danger =>
      palette.isNight ? AppTheme.darkError : AppTheme.lightError;

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(quranBookmarkDaoProvider);
    // The list comes from the shared provider, not a StreamBuilder built here:
    // `stream: dao.watchAll()` in `build` resubscribes on every rebuild, so each
    // frame issued a fresh query and the reader could never settle.
    final bookmarks = ref.watch(quranBookmarksProvider);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: quranPaperAppBar(
        context,
        palette: palette,
        title: 'نشان‌های قرآن',
      ),
      body: bookmarks.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
        // A failed read is NOT an empty list: saying «هنوز نشانی ثبت نشده» when
        // the query actually threw tells the reader their marks are gone. The
        // error keeps its own face and a retry that re-runs the stream.
        error: (_, __) => _ErrorState(
          palette: palette,
          danger: _danger,
          onRetry: () => ref.invalidate(quranBookmarksProvider),
        ),
        data: (rawItems) {
          if (rawItems.isEmpty) return _EmptyState(palette: palette);
          final items = _applyControls(rawItems);
          if (items.isEmpty) {
            return _FilteredEmptyState(palette: palette, onlyNoted: _onlyNoted);
          }
          return Column(
            children: [
              _ListControls(
                palette: palette,
                sortBySurah: _sortBySurah,
                onlyNoted: _onlyNoted,
                onSortBySurah: (v) => setState(() => _sortBySurah = v),
                onOnlyNoted: (v) => setState(() => _onlyNoted = v),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final b = items[i];
                    final surahName = getSurahNameArabic(b.surah);
                    return _BookmarkRow(
                      palette: palette,
                      data: b,
                      surahName: surahName,
                      danger: _danger,
                      onTap: () {
                        if (widget.onGoToPage != null) {
                          Navigator.pop(context);
                          widget.onGoToPage!(b.surah, b.ayah);
                        } else {
                          Navigator.pop(context, b);
                        }
                      },
                      onDismissed: () async {
                        await dao.removeByAyah(b.surah, b.ayah);
                        if (!context.mounted) return;
                        _showUndoSnack(context, dao, b, surahName);
                      },
                      // Long-press opens the note writer on THIS screen — the
                      // reader's ayah sheet can write notes too, but the list
                      // had no way back into one (upgrade wave-1 #4).
                      onEditNote: () => _editNote(b, dao),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<QuranBookmarkTableData> _applyControls(
      List<QuranBookmarkTableData> raw) {
    var items = raw;
    if (_onlyNoted) {
      items = items
          .where((b) => b.note != null && b.note!.trim().isNotEmpty)
          .toList();
    }
    if (_sortBySurah) {
      final sorted = List<QuranBookmarkTableData>.of(items)
        ..sort((a, b) {
          final bySurah = a.surah.compareTo(b.surah);
          return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
        });
      items = sorted;
    } else {
      final sorted = List<QuranBookmarkTableData>.of(items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      items = sorted;
    }
    return items;
  }

  Future<void> _editNote(
      QuranBookmarkTableData b, QuranBookmarkDao dao) async {
    final controller = TextEditingController(text: b.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _NoteDialog(
        palette: palette,
        controller: controller,
        ayahLabel:
            '${getSurahNameArabic(b.surah)} — آیه ${NumberFormat.formatPlain(b.ayah.toDouble())}',
      ),
    );
    if (saved != true) return;
    // setNote persists through the watched stream — the row updates itself.
    await dao.setNote(b.surah, b.ayah, controller.text);
  }

  /// Undo window after a swipe-delete: the bookmark is re-inserted (new id, same
  /// ayah and note) unless that ayah was marked again in the meantime. Without
  /// it a mis-swipe silently cost the user their position.
  void _showUndoSnack(BuildContext context, QuranBookmarkDao dao,
      QuranBookmarkTableData b, String surahName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            'نشان «$surahName — آیه ${NumberFormat.formatPlain(b.ayah.toDouble())}» حذف شد',
            style: TextStyle(color: palette.onChrome)),
        backgroundColor: palette.chrome,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'بازگردانی',
          textColor: palette.accent,
          onPressed: () async {
            if (await dao.getByAyah(b.surah, b.ayah) == null) {
              await dao.add(b.surah, b.ayah, note: b.note);
            }
          },
        ),
      ));
  }
}

/// The sort/filter chip row (upgrade wave-1 #4). Both controls apply in
/// place — no sheet behind a sheet for a two-option list.
class _ListControls extends StatelessWidget {
  const _ListControls({
    required this.palette,
    required this.sortBySurah,
    required this.onlyNoted,
    required this.onSortBySurah,
    required this.onOnlyNoted,
  });

  final MushafPalette palette;
  final bool sortBySurah;
  final bool onlyNoted;
  final ValueChanged<bool> onSortBySurah;
  final ValueChanged<bool> onOnlyNoted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          _ControlChip(
            palette: palette,
            icon: Icons.menu_book,
            label: 'ترتیب سوره',
            selected: sortBySurah,
            onSelected: onSortBySurah,
          ),
          const SizedBox(width: 8),
          _ControlChip(
            palette: palette,
            icon: Icons.edit_note,
            label: 'فقط یادداشت‌دار',
            selected: onlyNoted,
            onSelected: onOnlyNoted,
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final MushafPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? palette.surface : palette.surfaceText;
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      backgroundColor: palette.surface,
      selectedColor: palette.accent,
      side: BorderSide(color: selected ? palette.accent : palette.border),
      showCheckmark: false,
      avatar: Icon(icon, size: 15, color: ink),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11.5),
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

/// The note writer, on the list itself: pre-filled, blank = clear (the DAO's
/// rule — clearing a note keeps the mark).
class _NoteDialog extends StatelessWidget {
  const _NoteDialog({
    required this.palette,
    required this.controller,
    required this.ayahLabel,
  });

  final MushafPalette palette;
  final TextEditingController controller;
  final String ayahLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'یادداشت نشان',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w800,
          color: palette.surfaceText,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ayahLabel,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: palette.surfaceMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: palette.surfaceText,
            ),
            decoration: InputDecoration(
              hintText: 'یادداشت شما (خالی = پاک شدن یادداشت)',
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: palette.surfaceMuted,
              ),
              filled: true,
              fillColor: palette.background.withValues(alpha: 0.5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.accent),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'انصراف',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w600,
              color: palette.surfaceMuted,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: palette.accent),
          child: Text(
            'ذخیره',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              color: palette.background,
            ),
          ),
        ),
      ],
    );
  }
}

/// The filter ate every row: a different sentence from «nothing marked» —
/// the marks exist, the filter is just narrower than the list.
class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.palette, required this.onlyNoted});

  final MushafPalette palette;
  final bool onlyNoted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        onlyNoted ? 'هیچ نشانی یادداشت‌دار نیست' : 'هیچ نشانی با این فیلتر نیست',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          color: palette.surfaceMuted,
        ),
      ),
    );
  }
}

/// One bookmark: the shared kit row inside a paper card, swipe-to-delete.
class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.palette,
    required this.data,
    required this.surahName,
    required this.danger,
    required this.onTap,
    required this.onDismissed,
    this.onEditNote,
  });

  final MushafPalette palette;
  final QuranBookmarkTableData data;
  final String surahName;
  final Color danger;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  /// Long-press opens the note writer; null leaves the row without the
  /// affordance (kept optional so the widget test can drive rows bare).
  final VoidCallback? onEditNote;

  @override
  Widget build(BuildContext context) {
    final note = data.note;
    final hasNote = note != null && note.isNotEmpty;
    return Dismissible(
      key: ValueKey('bm_${data.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: QuranKitRow(
          palette: palette,
          icon: Icons.bookmark,
          title:
              '$surahName — آیه ${NumberFormat.formatPlain(data.ayah.toDouble())}',
          // Page identity on the first line; the reader's own note, when there
          // is one, on the second (report §7.4 — the list has always rendered
          // a note, only the writer was missing).
          subtitleRich: TextSpan(children: [
            TextSpan(
              text: 'سوره ${NumberFormat.formatPlain(data.surah.toDouble())}'
                  ' • صفحه ${NumberFormat.formatPlain(getPageNumber(data.surah, data.ayah).toDouble())}',
            ),
            if (hasNote) ...[
              const TextSpan(text: '\n'),
              TextSpan(
                text: note,
                style: TextStyle(color: palette.surfaceText),
              ),
            ],
          ]),
          trailing: Icon(Icons.chevron_left,
              size: 18, color: palette.surfaceMuted),
          onTap: onTap,
          onLongPress: onEditNote,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}

/// Nothing marked yet, said in the reader's colours.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: palette.surfaceMuted),
            const SizedBox(height: 12),
            Text(
              'هنوز نشانی ثبت نشده',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: palette.surfaceText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'برای نشان‌گذاری، روی آیه نگه دارید و «نشان‌گذاری» را بزنید',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.6,
                color: palette.surfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The read failed: say so plainly and offer the one action that helps.
/// Deliberately not the empty state — «هنوز نشانی ثبت نشده» after a failed
/// query would report a loss that did not happen.
class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.palette,
    required this.danger,
    required this.onRetry,
  });

  final MushafPalette palette;
  final Color danger;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // This screen paints paper, not the ambient field, so it supplies the ink
    // rather than letting the panel read the time theme — the mushaf palette
    // carries no error hue on purpose and its text colours are the paper's.
    return FailureView(
      id: 'quran_bookmarks_load',
      title: 'خواندن نشان‌ها ممکن نشد',
      detail: 'نشان‌های شما پاک نشده‌اند؛ فقط این فهرست باز نشد.',
      onRetry: onRetry,
      layout: FailureLayout.page,
      ink: FailureInk(
        title: palette.surfaceText,
        detail: palette.surfaceMuted,
        danger: danger,
      ),
    );
  }
}
