part of 'quran_mushaf_view.dart';

// ── QCF4 whole-mushaf download sheet (live-font mushaf) ────────────────────

/// Bottom sheet managing the full QCF4 pre-download: 604 page JSON files +
/// 48 TTF fonts ≈ 125 MB so the live-font reader works offline. Listens to
/// [Qcf4DownloadManager.instance.state] and exposes start/cancel + a quick
/// enable switch for QCF4 mode.
class _Qcf4DownloadSheet extends StatefulWidget {
  const _Qcf4DownloadSheet({
    required this.palette,
    required this.manager,
    required this.onStart,
    required this.onCancel,
    this.embedded = false,
    this.onDataDeleted,
  });

  final MushafPalette palette;
  final Qcf4DownloadManager manager;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  /// Fired after the stored pages + fonts are really gone, so a host page's
  /// own storage readout (the pre-download sheet's hero) refreshes with it.
  final VoidCallback? onDataDeleted;

  /// When embedded inside another (already scrollable) sheet, skip the outer
  /// SafeArea / drag handle / fixed-height wrapper and show only the compact
  /// section content.
  final bool embedded;

  @override
  State<_Qcf4DownloadSheet> createState() => _Qcf4DownloadSheetState();
}

class _Qcf4DownloadSheetState extends State<_Qcf4DownloadSheet> {
  MushafPalette get palette => widget.palette;
  Qcf4DownloadManager get manager => widget.manager;

  int _cachedPages = 0;
  int _cachedFonts = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // Recompute "is the whole mushaf already on disk" whenever this sheet is
    // opened, so a library downloaded in a previous session (or resumed to
    // completion right now) shows as ready — not "start download".
    unawaited(manager.refreshFullyDownloaded());
    manager.state.addListener(_onManagerState);
    unawaited(_refreshCachedCounts());
  }

  @override
  void dispose() {
    manager.state.removeListener(_onManagerState);
    super.dispose();
  }

  void _onManagerState() {
    // Refresh cached counts when a download finished so the storage readout
    // stays accurate without re-opening the sheet.
    if (!manager.state.value.running) {
      unawaited(_refreshCachedCounts());
    }
  }

  Future<void> _refreshCachedCounts() async {
    final pages = await Qcf4DataStore.instance.cachedPageCount();
    final fonts = await Qcf4FontLoader.instance.cachedFontCount();
    if (!mounted) return;
    setState(() {
      _cachedPages = pages;
      _cachedFonts = fonts;
    });
  }

  Future<void> _deleteMushafData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف دادهٔ دانلود مصحف'),
        content: const Text(
          'همهٔ «صفحات مصحف» و «فونت‌های TTF» دانلودشده از حافظهٔ دستگاه حذف شود؟ برای استفادهٔ آفلاین باید دوباره دانلود کنید.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await manager.clearAllDownloaded();
      widget.onDataDeleted?.call();
      await _refreshCachedCounts();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.embedded) return content;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: content,
      ),
    );
  }

  /// A compact two-column progress row (label + done/total) for the per-asset
  /// breakdown shown while the full QCF4 download is running.
  Widget _downloadBreakdownRow(String label, int done, int total) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: palette.surfaceText.withValues(alpha: 0.75),
          ),
        ),
        const Spacer(),
        Text(
          NumberFormat.fraction(done, total),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.surfaceText,
          ),
        ),
      ],
    );
  }

  /// Management row shown when nothing is actively downloading: reports how
  /// many mushaf pages / fonts are already stored, and offers a "delete" action
  /// to free that space when the reader is back online.
  Widget _cachedStorageIndicator() {
    final hasData = _cachedPages > 0 || _cachedFonts > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceText.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded,
                  size: 16, color: palette.surfaceText.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'دادهٔ دانلودشده در حافظه:',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: palette.surfaceText.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              if (_deleting)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _downloadBreakdownRow(
                    'صفحه', _cachedPages, Qcf4Config.pageCount),
              ),
              Expanded(
                child: _downloadBreakdownRow(
                    'فونت', _cachedFonts, 1 + Qcf4Config.hafsFontCount),
              ),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _deleting ? null : _deleteMushafData,
              icon: Icon(Icons.delete_outline,
                  size: 15, color: Colors.red.shade400),
              label: Text(
                'حذف دادهٔ دانلود',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Colors.red.shade400),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              // Shared handle spec (mushaf_color_sheets.dart): 40x4, the
              // surface text colour — one look across every reader sheet.
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.surfaceText.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  'دانلود کامل مصحف QCF4 (فونت زنده)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.surfaceText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '604 صفحه + 48 فونت TTF (حدود 125 مگابایت).',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: palette.surfaceText.withValues(alpha: 0.65),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.accent),
        ],
        ValueListenableBuilder<Qcf4DownloadState>(
          valueListenable: manager.state,
          builder: (context, st, _) {
            final complete = st.fullyDownloaded ||
                (st.total > 0 && st.done >= st.total && !st.running);
            final progress =
                st.total > 0 ? (st.done / st.total).clamp(0.0, 1.0) : 0.0;
            final percent = (progress * 100).round();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (st.running) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            st.currentItem.isEmpty
                                ? 'در حال آماده‌سازی…'
                                : st.currentItem,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: palette.surfaceText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${NumberFormat.fraction(st.done, st.total)} (${NumberFormat.normalizeDigits('$percent')}٪)',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: palette.accent.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                    const SizedBox(height: 10),
                    _downloadBreakdownRow(
                      'صفحات مصحف',
                      st.pagesDone,
                      Qcf4Config.pageCount,
                    ),
                    const SizedBox(height: 4),
                    _downloadBreakdownRow(
                      'فونت‌ها (TTF)',
                      st.fontsDone,
                      1 + Qcf4Config.hafsFontCount,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (st.error != null && !st.running) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        st.error!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                  if (complete && st.total > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: palette.accent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'مصحف QCF4 کامل آماده است',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.surfaceText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!st.running) ...[
                    _cachedStorageIndicator(),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    onPressed: st.running ? widget.onCancel : widget.onStart,
                    // A check icon on a button that STARTS a download reads
                    // as "already done"; the icon has to say "download"
                    // until there is really nothing left to fetch.
                    icon: Icon(
                      st.running
                          ? Icons.stop_circle_outlined
                          : (complete
                              ? Icons.refresh_rounded
                              : Icons.download_rounded),
                      size: 18,
                    ),
                    label: Text(
                      st.running
                          ? 'توقف دانلود'
                          : complete
                              ? 'دانلود مجدد · همه‌چیز آماده است'
                              : 'شروع دانلود (${NumberFormat.normalizeDigits(st.sizeMB.toStringAsFixed(0))} مگابایت)',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          st.running ? Colors.red.shade400 : palette.accent,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
