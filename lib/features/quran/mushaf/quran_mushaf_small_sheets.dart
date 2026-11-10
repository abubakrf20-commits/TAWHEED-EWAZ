part of 'quran_mushaf_view.dart';

// ── Go-to dialog (page / surah / juz) ──────────────────────────────────────

class _GoToDialog extends StatefulWidget {
  const _GoToDialog({
    required this.palette,
    required this.onResolveSurah,
    required this.onResolveJuz,
  });

  final MushafPalette palette;
  final Future<int> Function(int surah) onResolveSurah;
  final Future<int> Function(int juz) onResolveJuz;

  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _pageField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _pageField.dispose();
    super.dispose();
  }

  void _pick(int page) => Navigator.of(context).pop(page);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'رفتن به',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.palette.surfaceText.withValues(alpha: 0.9),
                ),
              ),
            ),
            TabBar(
              controller: _tab,
              labelColor: widget.palette.accent,
              unselectedLabelColor:
                  widget.palette.surfaceText.withValues(alpha: 0.5),
              indicatorColor: widget.palette.accent,
              labelStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'صفحه'),
                Tab(text: 'سوره'),
                Tab(text: 'جزء'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildPageTab(),
                  _buildSurahTab(),
                  _buildJuzTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _pageField,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: widget.palette.surfaceText),
            decoration: InputDecoration(
              labelText: 'شماره صفحه (1 تا 604)',
              labelStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: widget.palette.surfaceText.withValues(alpha: 0.7)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.palette.accent),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: widget.palette.accent,
              foregroundColor: widget.palette.onChrome,
            ),
            onPressed: () {
              final page = int.tryParse(
                  NumberFormat.normalizeDigits(_pageField.text.trim()));
              if (page != null && page >= 1 && page <= 604) _pick(page);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label:
                Text('برو', style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 114,
      itemBuilder: (context, index) {
        final n = index + 1;
        return ListTile(
          dense: true,
          // The number is bare text on purpose: no box/avatar around the surah
          // rows (reader: «جزء و سوره در بوکس نباشند»).
          leading: SizedBox(
            width: 28,
            child: Center(
              child: Text(
                NumberFormat.normalizeDigits('$n'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: widget.palette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          title: Text(
            getSurahNameArabic(n),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.palette.surfaceText,
            ),
          ),
          subtitle: Text(
            getSurahName(n),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: widget.palette.surfaceMuted,
            ),
          ),
          onTap: () async {
            final page = await widget.onResolveSurah(n);
            if (context.mounted) _pick(page);
          },
        );
      },
    );
  }

  Widget _buildJuzTab() {
    // No boxes around the juz numbers (reader: «جزء و سوره در بوکس نباشند»):
    // the grid keeps only its tap targets, so the numbers read as a plain
    // table while the whole cell stays hittable.
    return GridView.count(
      crossAxisCount: 5,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var j = 1; j <= 30; j++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final page = await widget.onResolveJuz(j);
              if (context.mounted) _pick(page);
            },
            child: Center(
              child: Text(
                NumberFormat.normalizeDigits('$j'),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.palette.surfaceText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
