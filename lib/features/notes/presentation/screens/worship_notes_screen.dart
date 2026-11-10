import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';
import 'package:tawheeed/features/notes/presentation/providers/voice_note_provider.dart';
import 'package:tawheeed/features/notes/presentation/utils/note_colors.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

/// Notes identity color — warm amber (sticky-note wall feel).
const Color _notesAccent = TopicHues.worshipNotes;
const Color _notesAccentStrong = Color(0xFFE67E22);
const Color _notesAccentSoft = Color(0xFFFFF3D6);

enum NoteFilter { all, pinned, today, thisWeek, done }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

/// `m:ss` (or `s.s`) for a voice-note clip; empty string when unknown.
String _fmtClip(Duration d) {
  if (d <= Duration.zero) return '';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
  return '${d.inMilliseconds / 1000}';
}

/// The heading a note card shows: the real title, or — when the note was saved
/// without one (or with the legacy «یادداشت» placeholder) — the first words of
/// the body. Keeps the list quiet and lets title-less notes stand on content.
bool _hasRealTitle(NoteTableData n) {
  final t = n.title.trim();
  return t.isNotEmpty && t != 'یادداشت';
}

/// Above this many folded notes, the fold cache is pruned to the live set.
const int notesFoldCacheLimit = 400;

/// One note's folded (search-normalised) title and body.
class _FoldedNote {
  const _FoldedNote({
    required this.stamp,
    required this.title,
    required this.content,
  });

  /// `updatedAt` of the row this was folded from.
  final int stamp;
  final String title;
  final String content;
}

String _noteCardTitle(NoteTableData n) {
  if (_hasRealTitle(n)) return n.title.trim();
  final c = n.content.trim();
  return c.isEmpty ? 'بی‌عنوان' : c;
}

class WorshipNotesScreen extends ConsumerStatefulWidget {
  const WorshipNotesScreen({super.key});

  @override
  ConsumerState<WorshipNotesScreen> createState() => _WorshipNotesScreenState();
}

class _WorshipNotesScreenState extends ConsumerState<WorshipNotesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearchActive = false;
  NoteFilter _filter = NoteFilter.all;
  bool _showDone = true;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<NoteTableData> _filterNotes(List<NoteTableData> notes) {
    var filtered = _applyFilter(notes);
    if (_searchQuery.isNotEmpty) {
      // Fold ی/ي، ك/ک and Persian/Arabic digits on both sides: searching
      // «۱۲۳» or « مطالعه» with an Arabic-keyboard ي has to find the note
      // the user typed themselves, not just one entered on the right
      // keyboard (same matching as the global search screen).
      final q = _fold(_searchQuery);
      filtered = filtered.where((n) {
        final f = _foldedNote(n);
        return f.title.contains(q) || f.content.contains(q);
      }).toList();
    }
    return filtered;
  }

  /// Folded title/body of every note, keyed by the row it was folded from.
  ///
  /// WHY: the fold is ten RegExp passes over the whole text, and it used to run
  /// for every note on every rebuild — i.e. twice per keystroke over the entire
  /// notebook. [NoteTableData.updatedAt] is bumped on every mutation (content,
  /// pin, done, colour), so it is a sound invalidation stamp: an edited note
  /// re-folds, and nothing else does.
  final Map<String, _FoldedNote> _foldedNotes = {};

  static String _fold(String s) => toAsciiDigits(normalizeForSearch(s));

  _FoldedNote _foldedNote(NoteTableData n) {
    final stamp = n.updatedAt.microsecondsSinceEpoch;
    final cached = _foldedNotes[n.id];
    if (cached != null && cached.stamp == stamp) return cached;
    final folded = _FoldedNote(
      stamp: stamp,
      title: _fold(n.title),
      content: _fold(n.content),
    );
    _foldedNotes[n.id] = folded;
    // Notes deleted while the screen is open must not keep their text alive.
    if (_foldedNotes.length > notesFoldCacheLimit) {
      final live = {for (final note in _lastNotes) note.id};
      _foldedNotes.removeWhere((id, _) => !live.contains(id));
    }
    return folded;
  }

  List<NoteTableData> _lastNotes = const [];

  List<NoteTableData> _applyFilter(List<NoteTableData> notes) {
    switch (_filter) {
      case NoteFilter.all:
        return notes;
      case NoteFilter.pinned:
        return notes.where((n) => n.isPinned).toList();
      case NoteFilter.today:
        return notes.where((n) => _isToday(n.updatedAt)).toList();
      case NoteFilter.thisWeek:
        return notes.where((n) => _inThisWeek(n.updatedAt)).toList();
      case NoteFilter.done:
        return notes.where((n) => n.isDone).toList();
    }
  }

  bool _inThisWeek(DateTime d) {
    final now = DateTime.now();
    final daysSinceSat = (now.weekday + 1) % 7;
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysSinceSat));
    return !d.isBefore(weekStart);
  }

  Future<void> _openEditor({NoteTableData? note}) async {
    // A note opened from a search hit carries the searched word: the editor
    // paints it inside the fields and scrolls to it. Opening the editor for a
    // new note, or with no query, keeps the plain route.
    final q = _searchQuery.trim();
    await context.push(
      note != null && q.isNotEmpty
          ? '${RouteNames.noteEditor}?q=${Uri.encodeQueryComponent(q)}'
          : RouteNames.noteEditor,
      extra: note,
    );
  }

  void _confirmDelete(NoteTableData note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف یادداشت'),
        content: Text('«${_noteCardTitle(note)}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.lightError),
            onPressed: () {
              ref.read(notesProvider.notifier).deleteNote(note.id);
              Navigator.pop(ctx);
              _showUndoSnack();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  /// Undo snackbar shown right after a delete — a 5-second window to bring
  /// the note back (same id, color, pin and timestamps).
  void _showUndoSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('یادداشت حذف شد'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () => ref.read(notesProvider.notifier).undoLastDelete(),
        ),
      ));
  }

  void _copyNote(NoteTableData note) {
    final text = '${note.title}\n${note.content}';
    ShareService.copyText(context, text, doneMessage: 'متن کپی شد');
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'یادداشت‌های عبادت',
        titleWidget: _isSearchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16)),
                decoration: InputDecoration(
                  hintText: 'جستجو در یادداشت‌ها...',
                  hintStyle: TextStyle(color: t.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 250),
                      () => setState(() => _searchQuery = v));
                },
                textDirection: TextDirection.rtl,
              )
            : Text('یادداشت‌ها',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.primary)),
        actions: [
          if (_isSearchActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'بستن جستجو',
              onPressed: () {
                setState(() {
                  _isSearchActive = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'جستجو',
              onPressed: () => setState(() => _isSearchActive = true),
            ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          return AsyncScreen(
            asyncValue: ref.watch(notesProvider),
            onRetry: () => ref.invalidate(notesProvider),
            data: (allNotes) {
              _lastNotes = allNotes;
              final filtered = _filterNotes(allNotes).toList()
                ..sort((a, b) {
                  if (a.isPinned && !b.isPinned) return -1;
                  if (!a.isPinned && b.isPinned) return 1;
                  return b.updatedAt.compareTo(a.updatedAt);
                });

              if (allNotes.isEmpty) {
                return _NotesVirtuesScreen(onStart: _openEditor);
              }
              if (filtered.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.search_off,
                  message: 'نتیجه‌ای یافت نشد',
                  subtitle: 'عبارت دیگری جستجو کنید یا فیلتر را تغییر دهید',
                  accent: _notesAccent,
                );
              }

              final pinned = filtered.where((n) => n.isPinned).toList();
              final done =
                  filtered.where((n) => n.isDone && !n.isPinned).toList();
              final active =
                  filtered.where((n) => !n.isPinned && !n.isDone).toList();
              final today = active.where((n) => _isToday(n.updatedAt)).toList();
              final thisWeek = active
                  .where(
                      (n) => _inThisWeek(n.updatedAt) && !_isToday(n.updatedAt))
                  .toList();
              final older = active
                  .where((n) =>
                      !_inThisWeek(n.updatedAt) && !_isToday(n.updatedAt))
                  .toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: _NotesMiniHeader(total: allNotes.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFilterRow(allNotes),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.search_off,
                        message: 'نتیجه‌ای یافت نشد',
                        subtitle:
                            'عبارت دیگری جستجو کنید یا فیلتر را تغییر دهید',
                        accent: _notesAccent,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _buildList(
                            filter: _filter,
                            pinned: pinned,
                            today: today,
                            thisWeek: thisWeek,
                            older: older,
                            done: done,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton.extended(
          onPressed: _openEditor,
          tooltip: 'یادداشت جدید',
          backgroundColor: _notesAccent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text('یادداشت جدید',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ),
    );
  }

  List<Widget> _buildList({
    required NoteFilter filter,
    required List<NoteTableData> pinned,
    required List<NoteTableData> today,
    required List<NoteTableData> thisWeek,
    required List<NoteTableData> older,
    required List<NoteTableData> done,
  }) {
    List<Widget> section(String title, List<NoteTableData> items) => [
          if (items.isNotEmpty) ...[
            _SectionLabel(title: title, count: items.length),
            const SizedBox(height: 8),
            ...items.map(_buildTile),
            const SizedBox(height: 16),
          ],
        ];

    final children = switch (filter) {
      NoteFilter.pinned => section('سنجاق شده', pinned),
      NoteFilter.today => section(
          'امروز', [...today, ...done.where((n) => _isToday(n.updatedAt))]),
      NoteFilter.thisWeek => section('این هفته', [
          ...thisWeek,
          ...done.where((n) => _inThisWeek(n.updatedAt)),
        ]),
      NoteFilter.done => section('انجام شده', done),
      NoteFilter.all => [
          ...section('سنجاق شده', pinned),
          ...section('امروز', today),
          ...section('این هفته', thisWeek),
          ...section('گذشته', older),
          if (done.isNotEmpty) ...[
            _CollapsibleHeader(
              title: 'انجام شده',
              count: done.length,
              expanded: _showDone,
              onToggle: () => setState(() => _showDone = !_showDone),
            ),
            const SizedBox(height: 8),
            if (_showDone) ...done.map(_buildTile),
            const SizedBox(height: 16),
          ],
        ],
    };

    return children;
  }

  Widget _buildTile(NoteTableData note) {
    return _NoteTile(
      note: note,
      onTap: () => _openEditor(note: note),
      onDelete: () => _confirmDelete(note),
      onCopy: () => _copyNote(note),
      onPin: () => ref.read(notesProvider.notifier).toggleNotePin(note.id),
      onToggleDone: () =>
          ref.read(notesProvider.notifier).toggleNoteDone(note.id),
      onColorTap: (colorIndex) =>
          ref.read(notesProvider.notifier).setNoteColor(note.id, colorIndex),
      onPlayAudio: note.audioPath.isEmpty
          ? null
          : () =>
              ref.read(voiceNotePlayerProvider.notifier).toggle(note.audioPath),
    );
  }

  Widget _buildFilterRow(List<NoteTableData> allNotes) {
    final t = TimeThemeKit.of(context).palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _NoteFilterChip('همه', NoteFilter.all, Icons.grid_view_rounded,
              _filter, (f) => setState(() => _filter = f),
              key: const ValueKey('note_filter_all')),
          const SizedBox(width: 8),
          _NoteFilterChip('سنجاق شده', NoteFilter.pinned, Icons.push_pin,
              _filter, (f) => setState(() => _filter = f),
              key: const ValueKey('note_filter_pinned')),
          const SizedBox(width: 8),
          _NoteFilterChip('امروز', NoteFilter.today, Icons.today, _filter,
              (f) => setState(() => _filter = f),
              key: const ValueKey('note_filter_today')),
          const SizedBox(width: 8),
          _NoteFilterChip('این هفته', NoteFilter.thisWeek, Icons.date_range,
              _filter, (f) => setState(() => _filter = f),
              key: const ValueKey('note_filter_week')),
          const SizedBox(width: 8),
          _NoteFilterChip('انجام شده', NoteFilter.done, Icons.check_circle,
              _filter, (f) => setState(() => _filter = f),
              key: const ValueKey('note_filter_done')),
          const SizedBox(width: 12),
          Text(
            '${allNotes.length} یادداشت',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY STATE — writing virtues (khatm/tasks/expenses pattern)
// ══════════════════════════════════════════════════════════════
class _NotesVirtuesScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _NotesVirtuesScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final virtues = [
      const _VirtueData(
        icon: Icons.edit_note,
        text: 'دانش را با نوشتن به بند بکش؛ نوشتن، نگهبان دانش است',
        source: 'پیامبر اکرم ﷺ',
        color: Color(0xFFF5A623),
      ),
      const _VirtueData(
        icon: Icons.lightbulb_outline,
        text: 'هر فکری که نوشته نشود، به آسانی از دست می‌رود',
        source: 'حکمت',
        color: Color(0xFF26A69A),
      ),
      const _VirtueData(
        icon: Icons.psychology_outlined,
        text: 'نوشتن، اندیشه را منظم و ذهن را سبک می‌کند',
        color: AppTheme.success,
      ),
      const _VirtueData(
        icon: Icons.savings_outlined,
        text: 'یادداشت‌های امروز، گنجینهٔ تجربه‌های فردای توست',
        source: 'مدیریت دانش',
        color: Color(0xFF6A1B9A),
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: _notesAccent.withValues(alpha: 0.06),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _notesAccent.withValues(alpha: 0.12),
                        border: Border.all(
                            color: _notesAccent.withValues(alpha: 0.35)),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _notesAccent,
                      ),
                      child: const Icon(Icons.note_alt_outlined,
                          size: 28, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'یادداشت‌ها',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'دیوار نوشته‌ها',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: isDark ? _notesAccent : (Color.lerp(_notesAccent, Colors.black, 0.45) ?? _notesAccent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنوز یادداشتی ثبت نشده',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final v = virtues[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: v.color, width: 4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: v.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: v.color.withValues(alpha: 0.30)),
                                  ),
                                  child: Icon(v.icon, color: v.color, size: 24),
                                ),
                                Positioned(
                                  top: -2,
                                  left: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: v.color,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: AppTheme.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.text,
                                    style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(
                                          context, 13.5),
                                      height: 1.5,
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (v.source != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      v.source!,
                                      style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(
                                            context, 11),
                                        color: dsContentColor(context, v.color),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: virtues.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('افزودن اولین یادداشت',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _notesAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'هر فکر و تجربه‌ای را که ارزش حفظ دارد، همین حالا بنویس',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VirtueData {
  final IconData icon;
  final String text;
  final String? source;
  final Color color;
  const _VirtueData({
    required this.icon,
    required this.text,
    this.source,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════════════
// HERO — notes wall stats (khatm/tasks/expenses pattern)
// ══════════════════════════════════════════════════════════════
// TINY DECORATIVE HEADER — no heavy card, just a slim accent strip
// ══════════════════════════════════════════════════════════════
class _NotesMiniHeader extends StatelessWidget {
  final int total;
  const _NotesMiniHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = _notesAccent;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.note_alt_outlined, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'یادداشت‌ها',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          child: Text(
            '$total یادداشت',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: isDark ? accent : (Color.lerp(accent, Colors.black, 0.45) ?? accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED HEADERS — amber identity
// ══════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  const _SectionLabel({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _notesAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12.5),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _notesAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: isDark ? _notesAccent : (Color.lerp(_notesAccent, Colors.black, 0.45) ?? _notesAccent),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsibleHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  const _CollapsibleHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _SectionLabel(title: title, count: count),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FILTER CHIP — amber identity
// ══════════════════════════════════════════════════════════════
class _NoteFilterChip extends StatelessWidget {
  final String label;
  final NoteFilter filter;
  final IconData icon;
  final NoteFilter current;
  final ValueChanged<NoteFilter> onChanged;

  const _NoteFilterChip(
      this.label, this.filter, this.icon, this.current, this.onChanged,
      {super.key});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = current == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(filter),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _notesAccent
                : (isDark
                    ? t.surfaceAlt
                    : _notesAccentSoft.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _notesAccent : t.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    selected ? Colors.white : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTE TILE — edge bar + icon chip + pills (family pattern)
// ══════════════════════════════════════════════════════════════
class _NoteTile extends ConsumerWidget {
  final NoteTableData note;
  final VoidCallback onTap, onDelete, onCopy, onPin, onToggleDone;
  final ValueChanged<int> onColorTap;
  final VoidCallback? onPlayAudio;

  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onCopy,
    required this.onPin,
    required this.onToggleDone,
    required this.onColorTap,
    this.onPlayAudio,
  });

  Color get _edgeColor {
    if (note.colorIndex > 0) return NoteColors.getColor(note.colorIndex);
    return _notesAccent;
  }

  Color _cardColor(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteColor = NoteColors.getColor(note.colorIndex);
    if (note.colorIndex > 0) {
      return Color.lerp(noteColor, t.card, 0.5) ?? noteColor;
    }
    // Default = sticky-note paper tint
    return Color.lerp(
          isDark ? _notesAccent : _notesAccentSoft,
          t.card,
          isDark ? 0.94 : 0.55,
        ) ??
        (isDark ? _notesAccent : _notesAccentSoft);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final edge = _edgeColor;
    final hasColor = note.colorIndex > 0;
    final player = ref.watch(voiceNotePlayerProvider);
    final audioPath = note.audioPath;
    final isThisPlaying =
        audioPath.isNotEmpty && player.isActive(audioPath) && player.isPlaying;

    // One heading line — the title, or the body's first words when there is no
    // title. A short content preview only follows when there is a real title.
    final headline = _noteCardTitle(note);
    final showContentLine =
        _hasRealTitle(note) && note.content.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: hasColor
              ? edge.withValues(alpha: 0.45)
              : _notesAccent.withValues(alpha: isDark ? 0.30 : 0.22),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: note.isDone ? edge.withValues(alpha: 0.45) : edge,
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: edge.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          note.isDone ? Icons.check_circle : Icons.edit_note,
                          size: 16,
                          color: note.isDone
                              ? success
                              : dsContentColor(context, edge),
                        ),
                      ),
                      if (audioPath.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message:
                              isThisPlaying ? 'توقف پخش' : 'پخش یادداشت صوتی',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: onPlayAudio,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color:
                                    _notesAccentStrong.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: _notesAccentStrong.withValues(
                                      alpha: isThisPlaying ? 0.6 : 0.25),
                                ),
                              ),
                              child: Icon(
                                isThisPlaying
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline,
                                size: 16,
                                color: _notesAccentStrong,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (note.isPinned) ...[
                                  const Icon(Icons.push_pin,
                                      size: 12, color: _notesAccentStrong),
                                  const SizedBox(width: 4),
                                ],
                                if (audioPath.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _notesAccentStrong.withValues(
                                          alpha: 0.14),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      isThisPlaying
                                          ? _fmtClip(player.position)
                                          : _fmtClip(Duration(
                                              milliseconds:
                                                  note.audioDurationMs)),
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: AppTheme.scaledFontSize(context, 9),
                                        fontWeight: FontWeight.w700,
                                        color: _notesAccentStrong,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 14),
                                      fontWeight: FontWeight.w700,
                                      color: t.textPrimary,
                                      decoration: note.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _fmtDate(note.updatedAt),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 10),
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            if (showContentLine) ...[
                              const SizedBox(height: 2),
                              Text(
                                note.content.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  color: note.isDone
                                      ? t.textMuted
                                      : t.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: _NoteMenu(
                  note: note,
                  onDelete: onDelete,
                  onCopy: onCopy,
                  onPin: onPin,
                  onToggleDone: onToggleDone,
                  onColorTap: onColorTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════
//  NOTE CARD MENU
// ══════════════════════════════════════════════════════════════
class _NoteMenu extends StatelessWidget {
  final NoteTableData note;
  final VoidCallback onDelete, onCopy, onPin, onToggleDone;
  final ValueChanged<int> onColorTap;

  const _NoteMenu({
    required this.note,
    required this.onDelete,
    required this.onCopy,
    required this.onPin,
    required this.onToggleDone,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return PopupMenuButton<String>(
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  size: 18, color: t.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  note.isPinned ? 'برداشتن پین' : 'پین کردن',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_outlined,
                  size: 18, color: t.textPrimary),
              const SizedBox(width: 8),
              const Flexible(
                  child: Text('کپی', overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'done',
          child: Row(
            children: [
              Icon(
                  note.isDone ? Icons.check_circle : Icons.check_circle_outline,
                  size: 18,
                  color: t.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  // The long «علامت‌گذاری به عنوان انجام شده» overflowed the
                  // 256px menu (debug stripes) — shorter labels + ellipsis.
                  note.isDone ? 'حذف علامت انجام' : 'انجام شده',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette_outlined,
                  size: 18, color: t.textPrimary),
              const SizedBox(width: 8),
              const Flexible(
                  child: Text('رنگ', overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppTheme.lightError),
              SizedBox(width: 8),
              Flexible(
                child: Text('حذف',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.lightError)),
              ),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == 'pin') onPin();
        if (v == 'copy') onCopy();
        if (v == 'done') onToggleDone();
        if (v == 'delete') onDelete();
        if (v == 'color') _showColorPicker(context);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.textMuted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.more_vert,
            size: 16, color: t.textMuted),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'انتخاب رنگ',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(NoteColors.palette.length, (i) {
                  final color = NoteColors.getColor(i);
                  final isSelected = i == note.colorIndex;
                  final hasColor = i > 0;
                  return GestureDetector(
                    onTap: () {
                      onColorTap(i);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: hasColor ? color : Theme.of(ctx).cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? _notesAccent
                                  : Theme.of(ctx).dividerColor,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  i == 0
                                      ? Icons.format_color_reset_rounded
                                      : Icons.check,
                                  size: 20,
                                  color: t.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NoteColors.getLabel(i),
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
