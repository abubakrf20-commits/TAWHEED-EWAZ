import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

/// One searchable piece of a section page.
///
/// [tab] is the index the entry lives under, so a hit can take the reader to
/// the tab it came from — or null when the page has no tab strip (ختم قرآن is a
/// single page). A null tab means the answer is the result card itself: the
/// sheet closes and nothing else moves, which is honest for a page that has
/// nowhere to jump to.
///
/// [body] is matched as well as [title], and is shown in the result card — the
/// answer is often readable right there, without leaving the search.
class SectionSearchEntry {
  const SectionSearchEntry({
    this.tab,
    this.tabLabel,
    required this.title,
    this.body = '',
  });

  final int? tab;

  /// The chip on the result card. Null hides the chip.
  final String? tabLabel;

  final String title;
  final String body;
}

/// An AppBar action that searches the section it sits in.
///
/// WHY: the More page search stops at the door. A reader standing inside
/// «ارکان و محرمات» who wants one ruling had to go back to the shell, search,
/// and re-enter — so in practice they scrolled. This keeps the search where the
/// content is, and the result card carries the answer plus a chip naming its
/// tab, which is switched on tap.
///
/// The entry list is supplied by the page (it owns its content), so this widget
/// knows nothing about any particular section.
class SectionSearchAction extends StatelessWidget {
  const SectionSearchAction({
    super.key,
    required this.sectionTitle,
    required this.entries,
  });

  /// Shown in the sheet's hint and its empty state.
  final String sectionTitle;

  final List<SectionSearchEntry> entries;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'جست‌وجو در $sectionTitle',
      icon: const Icon(Icons.search),
      onPressed: entries.isEmpty
          ? null
          : () async {
              final chosen = await showSectionSearch(
                context,
                sectionTitle: sectionTitle,
                entries: entries,
              );
              if (chosen == null || !context.mounted) return;
              // A page without tabs has nowhere to jump; the card was the
              // answer, so closing the sheet is the whole interaction.
              final tab = chosen.tab;
              if (tab == null) return;
              // The action lives under the page's tab controller, so the tab it
              // names is reachable from here.
              final controller = DefaultTabController.maybeOf(context);
              if (controller == null || tab >= controller.length) return;
              controller.animateTo(tab);
            },
    );
  }
}

/// Opens the section search. Resolves to the entry the reader chose, or null.
Future<SectionSearchEntry?> showSectionSearch(
  BuildContext context, {
  required String sectionTitle,
  required List<SectionSearchEntry> entries,
}) {
  return showModalBottomSheet<SectionSearchEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SectionSearchSheet(
      sectionTitle: sectionTitle,
      entries: entries,
    ),
  );
}

/// A pre-folded entry: the search keys are built once, when the sheet opens,
/// not on every keystroke.
class _Indexed {
  _Indexed(this.entry)
      : titleKey = normalizeSearchKey(entry.title),
        bodyKey = normalizeSearchKey(entry.body);

  final SectionSearchEntry entry;
  final String titleKey;
  final String bodyKey;
}

class _SectionSearchSheet extends StatefulWidget {
  const _SectionSearchSheet({
    required this.sectionTitle,
    required this.entries,
  });

  final String sectionTitle;
  final List<SectionSearchEntry> entries;

  @override
  State<_SectionSearchSheet> createState() => _SectionSearchSheetState();
}

class _SectionSearchSheetState extends State<_SectionSearchSheet> {
  late final List<_Indexed> _index = [
    for (final e in widget.entries) _Indexed(e),
  ];
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Title hits before body hits; inside each, the tab order the page uses.
  List<SectionSearchEntry> get _results {
    final q = normalizeSearchKey(_query);
    if (q.isEmpty) return const [];
    final titleHits = <SectionSearchEntry>[];
    final bodyHits = <SectionSearchEntry>[];
    for (final item in _index) {
      if (item.titleKey.contains(q)) {
        titleHits.add(item.entry);
      } else if (item.bodyKey.contains(q)) {
        bodyHits.add(item.entry);
      }
    }
    return [...titleHits, ...bodyHits];
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final results = _results;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'جست‌وجو در ${widget.sectionTitle}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.entries.length} مطلب',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'مثلاً: طواف، محرمات، قربانی',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: t.textMuted,
                  ),
                  prefixIcon: Icon(Icons.search, size: 18, color: t.textMuted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, size: 16, color: t.textMuted),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: t.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.primary, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _query.isEmpty
                              ? 'در ${widget.entries.length} مطلب این بخش '
                                  'جست‌وجو کنید — عنوان و متن هر دو.'
                              : 'چیزی در ${widget.sectionTitle} پیدا نشد.',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            height: 1.8,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ResultCard(
                        entry: results[i],
                        onTap: () => Navigator.of(context).pop(results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.entry, required this.onTap});

  final SectionSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.tabLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      entry.tabLabel!,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9.5),
                        color: t.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                entry.body,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  height: 1.7,
                  color: t.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
