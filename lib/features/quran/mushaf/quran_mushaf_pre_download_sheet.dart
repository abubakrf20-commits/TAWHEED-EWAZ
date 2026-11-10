part of 'quran_mushaf_view.dart';

// ── Pre-download (offline tafsir/translation + talaavat) ───────────────────

class _PreDownloadSheet extends StatefulWidget {
  const _PreDownloadSheet({
    required this.palette,
    required this.audioService,
    required this.reciters,
    required this.reciterId,
    required this.reciterName,
    required this.currentSurah,
    required this.onReciterChanged,
  });

  final MushafPalette palette;
  final QuranAudioDownloadService audioService;
  final List<Mp3QuranReciter> reciters;
  final String? reciterId;
  final String reciterName;
  final int currentSurah;
  final ValueChanged<String> onReciterChanged;

  @override
  State<_PreDownloadSheet> createState() => _PreDownloadSheetState();
}

class _PreDownloadSheetState extends State<_PreDownloadSheet> {
  bool _audioSurahReady = false;
  bool _scanningAudio = true;
  bool _wasAudioRunning = false;

  bool _translationSurahReady = false;
  bool _scanningTranslation = true;
  bool _wasTranslationRunning = false;

  int _audioCachedSurahs = 0;
  int _translationCachedSurahs = 0;
  bool _countsLoading = true;

  /// Pages + fonts already on disk. Read from the same services the QCF4
  /// sheet reads — never from an in-memory counter — so the hero and the
  /// breakdown below it can never disagree.
  int _storagePages = 0;
  int _storageFonts = 0;
  bool _scannerBusy = false;

  /// Real free space of the volume the app lives on, in MB. `null` until the
  /// platform answers (or forever, if it refuses) — the hero then hides the
  /// line instead of printing a wrong number.
  double? _freeSpaceMb;

  /// «فقط با وای‌فای دانلود شود» — default ON (a 125 MB mushaf on a mobile
  /// data plan is the one download the reader must opt into explicitly).
  /// Persisted so the choice survives the sheet.
  static const String _wifiOnlyPrefsKey = 'quran_download_wifi_only';
  bool _wifiOnly = true;

  /// Active reciter inside this sheet; changes call [widget.onReciterChanged]
  /// so the reader's audio follows.
  late String? _reciterId;

  /// Display name of [_reciterId] (kept local so the label updates instantly
  /// when the user picks a different reciter inside this sheet).
  late String _reciterName;

  /// The storage hero's «حذف داده» affordance — a compact outline button
  /// whose dialog names the space it frees, never a big red button.
  Future<void> _confirmStorageWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف دادهٔ دانلود مصحف'),
        content: const Text(
          'همهٔ صفحات و فونت‌های دانلودشده از حافظهٔ دستگاه حذف شوند؟ '
          'برای استفادهٔ آفلاین باید دوباره دانلود کنید.',
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
    setState(() => _scannerBusy = true);
    try {
      // The same primitive the QCF4 sheet uses: it cancels an in-flight
      // download and awaits it before touching files, so a delete can never
      // race a writer.
      await Qcf4DownloadManager.instance.clearAllDownloaded();
      if (!mounted) return;
      await _refreshStorageCounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('دادهٔ دانلود مصحف حذف شد.'),
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _scannerBusy = false);
    }
  }

  /// The «فقط با وای‌فای دانلود شود» gate. Unknown transports never block (a
  /// failed platform call must not make the reader unable to download);
  /// mobile data asks for an explicit per-download opt-in so the toggle's
  /// promise — a data plan is never spent silently — actually holds.
  Future<bool> _wifiAllowsDownload() async {
    if (!_wifiOnly) return true;
    final onWifi = await DeviceStatusService.isOnWifi();
    if (onWifi != false) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اتصال به وای‌فای نیست'),
        content: const Text(
          'گوشی روی دادهٔ موبایل است و «فقط با وای‌فای دانلود شود» روشن است.\n\n'
          'برای همین دانلود از دادهٔ موبایل استفاده شود؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('دانلود با دادهٔ موبایل'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  /// «فقط با وای‌فای دانلود شود» — persisted as a plain bool, like the other
  /// download preferences.
  Widget _buildWifiToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _p.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _p.accent.withValues(alpha: 0.2)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        secondary: Icon(Icons.wifi, color: _p.accent),
        title: Text('فقط با وای‌فای دانلود شود',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily, color: _p.surfaceText)),
        subtitle: Text(
          'دانلود روی دادهٔ موبایل پیش‌فرض انجام نمی‌شود',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: _p.surfaceMuted),
        ),
        value: _wifiOnly,
        activeThumbColor: _p.accent,
        onChanged: (v) {
          setState(() => _wifiOnly = v);
          unawaited(SharedPreferences.getInstance()
              .then((p) => p.setBool(_wifiOnlyPrefsKey, v)));
        },
      ),
    );
  }

  MushafPalette get _p => widget.palette;

  @override
  void initState() {
    super.initState();
    _reciterId = widget.reciterId;
    _reciterName = widget.reciterName;
    _wasAudioRunning = widget.audioService.state.value.running;
    _wasTranslationRunning =
        QuranTranslationDownloadService.instance.state.value.running;
    widget.audioService.state.addListener(_onAudioState);
    QuranTranslationDownloadService.instance.state
        .addListener(_onTranslationState);
    _scanAudio();
    _scanTranslation();
    unawaited(_refreshManageCounts());
    unawaited(_refreshStorageCounts());
    SharedPreferences.getInstance().then((p) {
      final stored = p.getBool(_wifiOnlyPrefsKey);
      if (stored != null && mounted) setState(() => _wifiOnly = stored);
    });
  }

  /// Reads pages + fonts off disk for the storage hero, plus the device's real
  /// free space. Both counts come from the same services the QCF4 sheet lists,
  /// so the hero and the breakdown below it can never disagree.
  Future<void> _refreshStorageCounts() async {
    final pages = await Qcf4DataStore.instance.cachedPageCount();
    final fonts = await Qcf4FontLoader.instance.cachedFontCount();
    final freeSpaceMb = await DeviceStatusService.freeSpaceMb();
    if (!mounted) return;
    setState(() {
      _storagePages = pages;
      _storageFonts = fonts;
      _freeSpaceMb = freeSpaceMb;
      _scannerBusy = false;
    });
  }

  @override
  void dispose() {
    widget.audioService.state.removeListener(_onAudioState);
    QuranTranslationDownloadService.instance.state
        .removeListener(_onTranslationState);
    super.dispose();
  }

  /// Asks the user to explicitly confirm a talaawah download before it
  /// starts — talaawah is sacred content and should never be stored offline
  /// by accident (e.g. a stray tap on «کل قرآن»).
  Future<bool> _confirmDownload(String what, {String extra = ''}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('دانلود تلاوت'),
        content: Text(
          '«$what» دانلود شود و در حافظهٔ دستگاه ذخیره شود؟$extra',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('دانلود'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _onAudioState() {
    final running = widget.audioService.state.value.running;
    if (!running && _wasAudioRunning) {
      _scanAudio();
      unawaited(_refreshManageCounts());
    }
    _wasAudioRunning = running;
    if (mounted) setState(() {});
  }

  Future<void> _scanAudio() async {
    if (mounted) setState(() => _scanningAudio = true);
    final reciterId = _reciterId;
    var ready = false;
    if (reciterId != null) {
      ready = await widget.audioService
          .isSurahCached(reciterId, widget.currentSurah);
    }
    if (!mounted) return;
    setState(() {
      _audioSurahReady = ready;
      _scanningAudio = false;
    });
  }

  void _onTranslationState() {
    final running =
        QuranTranslationDownloadService.instance.state.value.running;
    if (!running && _wasTranslationRunning) {
      _scanTranslation();
      unawaited(_refreshManageCounts());
    }
    _wasTranslationRunning = running;
    if (mounted) setState(() {});
  }

  Future<void> _scanTranslation() async {
    if (mounted) setState(() => _scanningTranslation = true);
    final ready = await QuranTranslationDownloadService.instance
        .isSurahCached(widget.currentSurah);
    if (!mounted) return;
    setState(() {
      _translationSurahReady = ready;
      _scanningTranslation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The handle + title + explainer are PINNED above the scroll.
            // They used to be the first children of the scroll view, so a
            // long sheet scrolled the title up under the status bar and left
            // the sheet with no visible name (bug: "page title is clipped").
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _p.surfaceText.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'دانلود برای استفادهٔ آفلاین',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _p.surfaceText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'صفحات مصحف از سرور دانلود می‌شوند؛ می‌توانید پیشاپیش '
                    'آن‌ها را دانلود کنید تا بدون نیاز به اینترنت در دسترس باشند.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      height: 1.6,
                      color: _p.surfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            // Always-scrollable: the download page is the one sheet that is
            // reliably taller than a phone. `MushafSheetScroll` cannot be used
            // here because it stays NeverScrollable until it observes an
            // overflow, and on first open there are no metrics to observe yet —
            // which is exactly why the page felt glued in place.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StorageHero(
                      palette: _p,
                      pagesDone: _storagePages,
                      fontsDone: _storageFonts,
                      pagesTotal: 604,
                      fontsTotal: 48,
                      freeSpaceMb: _freeSpaceMb,
                      canDelete: _storagePages > 0 || _storageFonts > 0,
                      deleting: _scannerBusy,
                      onDelete: _confirmStorageWipe,
                    ),
                    const SizedBox(height: 12),
                    _buildWifiToggle(),
                    const SizedBox(height: 18),
                    _buildQcf4Section(),
                    const SizedBox(height: 18),
                    _buildAudioSection(),
                    const SizedBox(height: 18),
                    _buildTranslationSection(),
                    const SizedBox(height: 18),
                    _buildManageSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQcf4Section() {
    return _Qcf4DownloadSheet(
      palette: _p,
      manager: Qcf4DownloadManager.instance,
      onStart: () async {
        if (await _wifiAllowsDownload()) {
          Qcf4DownloadManager.instance.download();
        }
      },
      onCancel: Qcf4DownloadManager.instance.cancel,
      onDataDeleted: () => unawaited(_refreshStorageCounts()),
      embedded: true,
    );
  }

  Widget _buildAudioSection() {
    final reciterId = widget.reciterId;
    final as = widget.audioService.state.value;
    final canStart = reciterId != null && !as.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.headphones_rounded, size: 18, color: _p.accent),
            const SizedBox(width: 6),
            Text(
              'تلاوت آفلاین',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _p.surfaceText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickReciter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _p.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _p.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 18, color: _p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reciterId == null
                        ? 'انتخاب قاری برای دانلود تلاوت'
                        : 'قاری: $_reciterName',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _p.surfaceText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: _p.surfaceMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (as.running) ...[
          _buildAudioProgressCard(as),
          const SizedBox(height: 10),
        ],
        if (as.error != null && !as.running) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _p.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              as.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: _p.surfaceText,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canStart
                    ? () async {
                        if (await _confirmDownload(
                                'تلاوت سورهٔ ${NumberFormat.normalizeDigits('${widget.currentSurah}')}') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          widget.audioService
                              .startSurah(reciterId, widget.currentSurah);
                        }
                      }
                    : null,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  'سورهٔ ${NumberFormat.normalizeDigits('${widget.currentSurah}')}',
                  style:
                      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: _p.accent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: canStart
                    ? () async {
                        if (await _confirmDownload('تلاوت کل قرآن',
                                extra: ' این کار حجم زیادی از حافظه را میگیرد.') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          widget.audioService.startAll(reciterId);
                        }
                      }
                    : null,
                icon: const Icon(Icons.headphones_rounded, size: 18),
                label: Text(
                    'کل قرآن (~${NumberFormat.normalizeDigits((QuranApiConfig.talaawahWholeQuranSizeMB / 1000).toStringAsFixed(1))} گیگابایت)',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 12)),
                style: FilledButton.styleFrom(backgroundColor: _p.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _scanningAudio
              ? 'در حال بررسی سورهٔ فعلی…'
              : _audioSurahReady
                  ? 'سورهٔ فعلی در حافظهٔ دستگاه است.'
                  : 'سورهٔ فعلی هنوز دانلود نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: _p.surfaceMuted,
          ),
        ),
        if (!_scanningAudio && _audioSurahReady) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('حذف تلاوت'),
                  content: Text(
                    'تلاوت سورهٔ '
                    '${NumberFormat.normalizeDigits('${widget.currentSurah}')} '
                    'از حافظهٔ دستگاه حذف شود؟',
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
              if (ok == true && mounted) {
                if (_reciterId != null) {
                  await Mp3QuranService.deleteSurah(
                      _reciterId!, widget.currentSurah);
                }
                if (mounted) _scanAudio();
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text('حذف تلاوت سورهٔ فعلی',
                style:
                    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12)),
            style: OutlinedButton.styleFrom(
                foregroundColor: _p.accent,
                side: BorderSide(color: _p.accent.withValues(alpha: 0.5))),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'دانلود تلاوت جزء به جزء',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _p.surfaceText,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var j = 1; j <= 30; j++)
              InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: canStart
                    ? () async {
                        if (await _confirmDownload(
                                'تلاوت جزء ${NumberFormat.normalizeDigits('$j')}') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          widget.audioService.startJuz(reciterId, j);
                        }
                      }
                    : null,
                child: Container(
                  width: 34,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _p.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                    border:
                        Border.all(color: _p.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    NumberFormat.normalizeDigits('$j'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _p.surfaceText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTranslationSection() {
    final ts = QuranTranslationDownloadService.instance.state.value;
    final canStart = !ts.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.volume_up_rounded, size: 18, color: _p.accent),
            const SizedBox(width: 6),
            Text(
              'ترجمهٔ صوتی',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _p.surfaceText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (ts.running) ...[
          _buildTranslationProgressCard(ts),
          const SizedBox(height: 10),
        ],
        if (ts.error != null && !ts.running) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _p.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ts.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: _p.surfaceText,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canStart
                    ? () async {
                        if (await _confirmTranslationDownload(
                                'ترجمهٔ سورهٔ ${NumberFormat.normalizeDigits('${widget.currentSurah}')}') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          QuranTranslationDownloadService.instance
                              .startSurah(widget.currentSurah);
                        }
                      }
                    : null,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  'سورهٔ ${NumberFormat.normalizeDigits('${widget.currentSurah}')}',
                  style:
                      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: _p.accent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: canStart
                    ? () async {
                        if (await _confirmTranslationDownload(
                                'ترجمهٔ صوتی کل قرآن',
                                extra: ' حدود 1٫7 گیگابایت فضا اشغال می‌شود.') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          QuranTranslationDownloadService.instance.startAll();
                        }
                      }
                    : null,
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: Text(
                  'کل قرآن (~1٫7 گیگابایت)',
                  style:
                      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12),
                ),
                style: FilledButton.styleFrom(backgroundColor: _p.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _scanningTranslation
              ? 'در حال بررسی سورهٔ فعلی…'
              : _translationSurahReady
                  ? 'ترجمهٔ سورهٔ فعلی در حافظهٔ دستگاه است.'
                  : 'ترجمهٔ سورهٔ فعلی هنوز دانلود نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: _p.surfaceMuted,
          ),
        ),
        if (!_scanningTranslation && _translationSurahReady) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('حذف ترجمهٔ صوتی'),
                  content: Text(
                    'ترجمهٔ صوتی سورهٔ '
                    '${NumberFormat.normalizeDigits('${widget.currentSurah}')} '
                    'از حافظهٔ دستگاه حذف شود؟',
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
              if (ok == true && mounted) {
                await QuranTranslationDownloadService.instance
                    .deleteSurah(widget.currentSurah);
                if (mounted) _scanTranslation();
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text('حذف ترجمهٔ سورهٔ فعلی',
                style:
                    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12)),
            style: OutlinedButton.styleFrom(
                foregroundColor: _p.accent,
                side: BorderSide(color: _p.accent.withValues(alpha: 0.5))),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'دانلود ترجمهٔ صوتی جزء به جزء',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _p.surfaceText,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var j = 1; j <= 30; j++)
              InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: canStart
                    ? () async {
                        if (await _confirmTranslationDownload(
                                'ترجمهٔ صوتی جزء ${NumberFormat.normalizeDigits('$j')}') &&
                            await _wifiAllowsDownload()) {
                          if (!mounted) return;
                          QuranTranslationDownloadService.instance.startJuz(j);
                        }
                      }
                    : null,
                child: Container(
                  width: 34,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _p.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                    border:
                        Border.all(color: _p.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    NumberFormat.normalizeDigits('$j'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _p.surfaceText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTranslationProgressCard(QuranAudioDownloadState ts) {
    final progress = ts.total > 0 ? (ts.done / ts.total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _p.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ts.wholeQuran
                      ? 'دانلود ترجمهٔ کل قرآن'
                      : 'دانلود ترجمهٔ سورهٔ '
                          '${NumberFormat.normalizeDigits('${ts.surah}')}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _p.surfaceText,
                  ),
                ),
              ),
              Text(
                NumberFormat.fraction(ts.done, ts.total),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: _p.surfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: _p.accent.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(_p.accent),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: QuranTranslationDownloadService.instance.cancel,
              icon: const Icon(Icons.close, size: 14),
              label: Text('لغو',
                  style:
                      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11)),
              style: TextButton.styleFrom(
                  foregroundColor: _p.surfaceMuted,
                  visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmTranslationDownload(String what,
      {String extra = ''}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('دانلود ترجمهٔ صوتی'),
        content: Text(
          '«$what» دانلود شود و در حافظهٔ دستگاه ذخیره شود؟$extra',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('دانلود'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// The shared reciter picker (report §6.3/§7.2). Tapping a row switches the
  /// download target (and the reader's active reciter); tapping a row's download
  /// action fetches the current surah from that reciter without switching, so a
  /// reader can pull a surah from someone else without losing their place.
  Future<void> _pickReciter() async {
    final list = widget.reciters;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content:
              Text('لیست قاریان در دسترس نیست؛ اتصال اینترنت را بررسی کنید.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    final picked = await showModalBottomSheet<ReciterPick>(
      context: context,
      backgroundColor: _p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => ReciterPickerSheet(
        palette: _p,
        reciters: list,
        selectedId: _reciterId,
        downloadSurahNumber: widget.currentSurah,
        sizeLabel: _reciterSizeLabel,
        onSelect: (pick) => Navigator.pop(ctx, pick),
      ),
    );
    if (picked == null || !mounted) return;

    if (picked.downloadSurah) {
      final name = _reciterNameOf(picked.id) ?? picked.id;
      final surah = NumberFormat.normalizeDigits('${widget.currentSurah}');
      final ok = await _confirmDownload('تلاوت سورهٔ $surah — «$name»');
      if (ok && await _wifiAllowsDownload()) {
        if (!mounted) return;
        widget.audioService.startSurah(picked.id, widget.currentSurah);
      }
      return;
    }

    if (picked.id != _reciterId) {
      setState(() {
        _reciterId = picked.id;
        _reciterName = _reciterNameOf(picked.id) ?? _reciterName;
      });
      widget.onReciterChanged(picked.id);
      _scanAudio();
    }
  }

  String? _reciterNameOf(String id) {
    for (final r in widget.reciters) {
      if (r.identifier == id) return r.name;
    }
    return null;
  }

  /// The API carries no per-reciter size, so scale the whole-Quran figure by
  /// the reciter's own surah count — a good proxy for how much they recorded —
  /// and mark it approximate.
  String _reciterSizeLabel(Mp3QuranReciter r) {
    final mb =
        (QuranApiConfig.talaawahWholeQuranSizeMB * r.surahCount / 114).round();
    return '~${NumberFormat.normalizeDigits('$mb')} مگابایت';
  }

  Widget _buildAudioProgressCard(QuranAudioDownloadState s) {
    final label = 'سورهٔ ${NumberFormat.normalizeDigits('${s.surah}')}';
    final progress = s.total > 0 ? s.done / s.total : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _p.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _p.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'در حال دانلود تلاوت — $label',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: _p.surfaceText,
                  ),
                ),
              ),
              Text(
                NumberFormat.fraction(s.done, s.total),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _p.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: _p.accent.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(_p.accent),
          ),
          const SizedBox(height: 8),
          Align(
            child: TextButton.icon(
              onPressed: widget.audioService.cancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text('توقف دانلود',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
              style: TextButton.styleFrom(foregroundColor: _p.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download manager (delete stored data) ─────────────────────────────────

  Future<void> _refreshManageCounts() async {
    if (mounted) setState(() => _countsLoading = true);
    var audioCount = 0;
    var translationCount = 0;
    try {
      final reciterId = _reciterId;
      if (reciterId != null) {
        audioCount = await widget.audioService.countCachedSurahs(reciterId);
      }
      translationCount =
          await QuranTranslationDownloadService.instance.countCachedSurahs();
    } catch (_) {
      AppLogger.warning('quran_mushaf_view', 'operation failed');
    }
    if (!mounted) return;
    setState(() {
      _audioCachedSurahs = audioCount;
      _translationCachedSurahs = translationCount;
      _countsLoading = false;
    });
  }

  Widget _buildManageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.storage_rounded, size: 18, color: _p.accent),
            const SizedBox(width: 6),
            Text(
              'مدیریت دانلودها',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _p.surfaceText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _manageRow(
          icon: Icons.headphones_rounded,
          label: 'تلاوت آفلاین',
          detail: _countsLoading
              ? 'در حال بررسی…'
              : _audioCachedSurahs > 0
                  ? '${NumberFormat.normalizeDigits('$_audioCachedSurahs')} سوره (قاری فعلی) ذخیره شده است'
                  : 'چیزی ذخیره نشده است',
          enabled: !_countsLoading && _audioCachedSurahs > 0,
          onDelete: _deleteAllTalaawah,
        ),
        const SizedBox(height: 8),
        _manageRow(
          icon: Icons.volume_up_rounded,
          label: 'ترجمهٔ صوتی',
          detail: _countsLoading
              ? 'در حال بررسی…'
              : _translationCachedSurahs > 0
                  ? '${NumberFormat.normalizeDigits('$_translationCachedSurahs')} سوره ذخیره شده است'
                  : 'چیزی ذخیره نشده است',
          enabled: !_countsLoading && _translationCachedSurahs > 0,
          onDelete: _deleteAllTranslation,
        ),
      ],
    );
  }

  Widget _manageRow({
    required IconData icon,
    required String label,
    required String detail,
    required bool enabled,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _p.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _p.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _p.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _p.surfaceText,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: _p.surfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: enabled ? onDelete : null,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text('حذف همه',
                style:
                    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllTalaawah() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف تلاوت آفلاین'),
        content: const Text(
          'همهٔ تلاوت‌های دانلودشده از حافظهٔ دستگاه حذف شود؟',
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
    if (ok == true && mounted) {
      await Mp3QuranService.deleteAllReciters();
      if (mounted) {
        _scanAudio();
        unawaited(_refreshManageCounts());
      }
    }
  }

  Future<void> _deleteAllTranslation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف ترجمهٔ صوتی'),
        content: const Text(
          'همهٔ ترجمه‌های صوتی دانلودشده از حافظهٔ دستگاه حذف شود؟',
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
    if (ok == true && mounted) {
      await QuranTranslationDownloadService.instance.deleteAll();
      if (mounted) {
        _scanTranslation();
        unawaited(_refreshManageCounts());
      }
    }
  }
}
