import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';
import 'package:tawheeed/features/audio_library/audio_library_repository.dart';
import 'package:tawheeed/features/audio_library/presentation/widgets/audio_mini_player.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/expandable_text.dart';
import 'package:tawheeed/shared/widgets/service_unavailable_banner.dart';

/// Per-category hue — the same fixed ids as the legacy section table.
Color _categoryHue(String categoryId) {
  switch (categoryId) {
    case 'yaqeen':
      return TopicHues.yaqeen;
    case 'anasheed':
      return TopicHues.anasheed;
    case 'lectures':
      return TopicHues.lectures;
    case 'misc':
      return TopicHues.misc;
    default:
      return TopicHues.audioLibrary;
  }
}

/// «کتابخانه صوتی» — فهرست دسته‌های صوتی (رد شبهات / اناشید اسلامی /
/// سخنرانی) با پخش استریمی/آفلاین.
///
/// هر دسته تب خودش را دارد و در یک IndexedStack زنده نگه داشته می‌شود تا
/// جای پخش و وضعیت کارت‌های هر دسته هنگام جابه‌جایی بین تب‌ها حفظ شود.
/// پخش‌کنندهٔ پیشرفته (کنترل سرعت، تکرار، پخش خودکار، تایمر خواب، پرش
/// ±15 ثانیه، دانلود دسته) زیر صفحه به صورت نوار ثابت دیده می‌شود.
class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({
    super.key,
    this.loader,
    this.initialCategoryId,
    this.initialSpeakerId,
  });

  /// Test-only manifest loader override (defaults to the repository).
  @visibleForTesting
  final Future<AudioLibraryManifest> Function()? loader;

  /// Category to focus on first (matched against manifest category ids), e.g.
  /// when opened from the «اناشید اسلامی» tile.
  final String? initialCategoryId;

  /// Speaker to open inside the initial category (matched against speaker
  /// ids), e.g. when opened from the «سخنرانی» tile.
  final String? initialSpeakerId;

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final AudioLibraryPlayer _player = AudioLibraryPlayer.instance;

  AudioLibraryManifest? _manifest;
  String? _error;
  bool _loading = true;
  int _selected = 0;

  /// True when the screen is showing the on-device library because the audio
  /// host could not be reached (see [AudioLibraryPlayer.buildLocalManifest]).
  bool _localOnly = false;

  /// Live search query — non-null opens the search view over ALL categories.
  String? _query;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Currently open speaker inside the selected category (null = speaker list).
  String? _openSpeakerId;

  List<AudioCategory> get _categories => _manifest?.categories ?? const [];

  @override
  void initState() {
    super.initState();
    _player.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _player.removeListener(_onChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    // Playback deliberately keeps running when the section closes — that is
    // the library's background-listening behavior (user request): the
    // lock-screen / notification card stays in control, and returning to
    // the screen re-attaches to the same session. The app-wide player is
    // never disposed here.
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.loader ?? AudioLibraryRepository.instance.load;
      final manifest = await loader();
      if (!mounted) return;
      // A 200 that parses to zero categories is a broken payload, not a library
      // that is still being prepared. It used to fall through to a permanent
      // «کتابخانه در حال آماده‌سازی است.» with no retry — a server fault
      // reported to the listener as "not ready yet", forever.
      if (manifest.categories.isEmpty) {
        setState(() {
          _error = 'فهرست کتابخانه خالی بود؛ سرور پاسخ ناقص داد.';
          _localOnly = false;
          _loading = false;
        });
        return;
      }
      setState(() {
        _manifest = manifest;
        _localOnly = false;
        _loading = false;
        final start = manifest.categories
            .indexWhere((c) => c.id == widget.initialCategoryId);
        _selected = start >= 0 ? start : 0;
        final initial = widget.initialSpeakerId;
        if (initial != null &&
            start >= 0 &&
            manifest.categories[start].speakers.any((s) => s.id == initial)) {
          _openSpeakerId = initial;
        } else {
          _openSpeakerId = null;
        }
      });
      _wirePlayer(manifest, markSeen: true);
    } catch (e) {
      AppLogger.warning('audio_library_screen', 'error: $e');
      if (!mounted) return;
      // An unreachable host used to mean a dead end: every track already on
      // the device became unplayable because the list came only from the
      // server. Fall back to the on-disk library first, and only then show the
      // failure — with the reason the host actually gave.
      final local = await _player.buildLocalManifest();
      if (!mounted) return;
      if (local == null) {
        setState(() {
          _error = e is AudioLibraryException
              ? e.message
              : 'بارگذاری کتابخانه ناموفق بود.';
          _localOnly = false;
          _loading = false;
        });
        return;
      }
      setState(() {
        _manifest = local;
        _localOnly = true;
        _selected = 0;
        _openSpeakerId = null;
        _loading = false;
      });
      // «New» badges are not cleared here: with no server list the sweep would
      // flag unplayed arrivals during an outage.
      _wirePlayer(local, markSeen: false);
    }
  }

  /// Playlist wiring + downloaded-flag scan, run after the list is on screen:
  /// they only affect playback controls and download badges.
  void _wirePlayer(AudioLibraryManifest manifest, {required bool markSeen}) {
    unawaited(() async {
      await _player.configureCategories(manifest.categories);
      await _player.refresh(manifest.allTracks);
      if (!markSeen) return;
      await Future<void>.delayed(const Duration(seconds: 4));
      await _player.markAllTracksSeen();
    }());
  }

  Color get _selectedAccent => _categoryHue(
      _selected < _categories.length ? _categories[_selected].id : '');

  Color _accentOfCategory(String categoryId) => _categoryHue(categoryId);

  Color _accentOfTrack(AudioTrack? track) {
    if (track == null) return _selectedAccent;
    for (final c in _categories) {
      if (c.tracks.any((t) => t.id == track.id)) {
        return _accentOfCategory(c.id);
      }
    }
    return _selectedAccent;
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'کتابخانه صوتی',
        titleWidget: _query == null
            ? null
            : TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: t.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'جستجوی همهٔ درس‌ها…',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
        actions: [
          if (_query == null) ...[
            IconButton(
              tooltip: 'جستجو',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _query = ''),
            ),
            IconButton(
              tooltip: 'مدیریت فضای دانلودی',
              icon: const Icon(Icons.storage_rounded),
              onPressed: _showStorageSheet,
            ),
          ] else
            IconButton(
              tooltip: 'بستن جستجو',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = null);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _query != null
            ? _SearchResults(
                query: _query!,
                categories: _categories,
                accentOf: _accentOfCategory,
              )
            : _buildBody(context),
      ),
    );
  }

  Future<void> _showStorageSheet() async {
    final manifest = _manifest;
    if (manifest == null) return;
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    final bytes = await _player.downloadedBytes();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StorageSheet(
        usedBytes: bytes,
        trackCount: manifest.allTracks.length,
        accent: _selectedAccent,
        onDeleteAll: () async {
          final navigator = Navigator.of(ctx);
          final confirmed = await showDialog<bool>(
            context: ctx,
            builder: (dctx) => AlertDialog(
              backgroundColor: TimeThemeKit.of(dctx).palette.card,
              surfaceTintColor: Colors.transparent,
              title: const Text('حذف همهٔ فایل‌های دانلودی'),
              content: const Text(
                  'همهٔ درس‌های ذخیره‌شده برای پخش آفلاین حذف می‌شوند. پخش استریم همچنان کار می‌کند.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: const Text('انصراف')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: danger),
                    onPressed: () => Navigator.pop(dctx, true),
                    child: const Text('حذف')),
              ],
            ),
          );
          if (confirmed == true) {
            await _player.deleteAllDownloaded(manifest.allTracks);
            if (ctx.mounted) navigator.pop();
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return FailureView(
        id: 'audio_library_load',
        title: 'فهرست کتابخانهٔ صوتی باز نشد',
        detail: 'این فهرست از سرور می‌آید؛ آنچه روی این دستگاه دانلود شده '
            'جایی نرفته و پخشش به اینترنت نیاز ندارد.',
        onRetry: _load,
        layout: FailureLayout.page,
        icon: Icons.cloud_off_outlined,
        error: error,
      );
    }

    if (_categories.isEmpty) {
      // Unreachable for the server path now (an empty payload is an error), but
      // a dead sentence with no way out is never the right answer — if some
      // future path lands here, offer the reload.
      return AppEmptyState(
        icon: Icons.library_music_outlined,
        message: 'کتابخانه خالی است',
        subtitle: 'سرور فهرست خالی برگرداند. اگر انتظار کتابی را دارید، '
            'یک بار دیگر دریافت کنید.',
        actionLabel: 'دریافت دوبارهٔ فهرست',
        onAction: _load,
      );
    }

    return Column(
      children: [
        if (_localOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 12, DsSpacing.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ServiceUnavailableBanner(
                  detail:
                      'فهرست سرور کتابخانه صوتی در دسترس نیست؛ آنچه روی این '
                      'دستگاه دانلود شده نمایش داده می‌شود و پخشش به اینترنت '
                      'نیاز ندارد.',
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش دوباره برای دریافت فهرست'),
                  ),
                ),
              ],
            ),
          ),
        _CategoryTabs(
          categories: _categories,
          selected: _selected,
          onSelect: (i) => setState(() {
            _selected = i;
            _openSpeakerId = null;
          }),
        ),
        Expanded(
          child: IndexedStack(
            index: _selected,
            children: [
              for (final category in _categories)
                _CategoryList(
                  category: category,
                  accent: _accentOfCategory(category.id),
                  speakerId: _openSpeakerId,
                  onSpeakerChanged: (id) => setState(() => _openSpeakerId = id),
                ),
            ],
          ),
        ),
        AudioMiniPlayer(
          player: _player,
          accent: _accentOfTrack(_player.activeTrack),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY TABS — pills با رنگ هر دسته
// ═══════════════════════════════════════════════════════════════

class _CategoryTabs extends StatelessWidget {
  final List<AudioCategory> categories;
  final int selected;
  final ValueChanged<int> onSelect;
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: DsSpacing.page, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = categories[i];
          final accent = _categoryHue(category.id);
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: isDark ? 0.28 : 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? accent.withValues(alpha: 0.55) : t.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(category.icon,
                      size: 16, color: active ? accent : t.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    category.displayTitle,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? accent : t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY LIST — هدر + کارت درس‌ها + راهنمای آفلاین
// ═══════════════════════════════════════════════════════════════

class _CategoryList extends StatelessWidget {
  final AudioCategory category;
  final Color accent;
  final String? speakerId;
  final ValueChanged<String?> onSpeakerChanged;
  const _CategoryList({
    required this.category,
    required this.accent,
    this.speakerId,
    required this.onSpeakerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSpeakers = category.hasSpeakers;
    final openSpeaker = hasSpeakers && speakerId != null
        ? category.speakers.firstWhere((s) => s.id == speakerId,
            orElse: () => category.speakers.first)
        : null;
    // Speaker-grouped categories list only the speakers (e.g. شیخ ضیایی /
    // عربی و فارسی) on the main page; the flattened `category.tracks` are
    // hidden until a group is opened.
    final showFlatTracks = openSpeaker != null || !hasSpeakers;
    final tracks = showFlatTracks
        ? (openSpeaker?.tracks ?? category.tracks)
        : const <AudioTrack>[];
    final middleCount = showFlatTracks
        ? tracks.length
        : (hasSpeakers ? category.speakers.length : 0);

    final header = openSpeaker != null
        ? _SpeakerHeader(
            speaker: openSpeaker,
            category: category,
            accent: accent,
            onBack: () => onSpeakerChanged(null),
          )
        : hasSpeakers
            ? _CategoryHeader(
                category: category,
                accent: accent,
                hideBatchDownload: true,
              )
            : _CategoryHeader(category: category, accent: accent);

    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 32),
      itemCount: 2 + middleCount,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            children: [header, const SizedBox(height: 10)],
          );
        }
        if (i > middleCount) {
          return _OfflineNote(accent: accent);
        }
        final j = i - 1;
        if (showFlatTracks) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AudioTrackCard(
              track: tracks[j],
              category: category,
              lessonNumber: j + 1,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: j == middleCount - 1 ? 24 : 12),
          child: _SpeakerTile(
            speaker: category.speakers[j],
            category: category,
            accent: accent,
            index: j + 1,
            onTap: () => onSpeakerChanged(category.speakers[j].id),
          ),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final AudioCategory category;
  final Color accent;
  final bool hideBatchDownload;
  const _CategoryHeader({
    required this.category,
    required this.accent,
    this.hideBatchDownload = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = AudioLibraryPlayer.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final accentInk = dsContentColor(context, accent);
    final tracks = category.tracks.length;
    final mb = category.totalSizeBytes / (1024 * 1024);
    final sizeText = mb >= 100 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
    final allDownloaded =
        category.tracks.every((t) => player.stateOf(t).downloaded);
    final batch = player.downloadingCategory &&
        player.downloadingCategoryId == category.id;

    return AppCard(
      padding: const EdgeInsets.all(14),
      color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
      borderColor: accent.withValues(alpha: 0.30),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(category.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayTitle,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${NumberFormat.toLatin('$tracks')} درس • '
                          '${NumberFormat.toLatin(sizeText)} مگابایت',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            color: t.textMuted,
                          ),
                        ),
                        if (player.newCountForCategory(category.id) > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: warn,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${NumberFormat.toLatin(player.newCountForCategory(category.id).toString())} جدید',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: dsContentColor(context, warn),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (batch && !hideBatchDownload)
                IconButton(
                  tooltip: 'لغو دانلود دسته',
                  onPressed: player.cancelDownload,
                  icon: Icon(Icons.close_rounded, color: danger),
                )
              else if (allDownloaded && !hideBatchDownload)
                Icon(
                  Icons.check_circle_outline,
                  color: t.textMuted,
                )
              else if (!hideBatchDownload)
                IconButton(
                  tooltip: 'دانلود همه برای پخش آفلاین',
                  onPressed: () =>
                      player.downloadCategory(category.id, category.tracks),
                  icon: Icon(Icons.cloud_download_outlined, color: accent),
                ),
              if (!hideBatchDownload && batch) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: player.categoryProgress ?? 0,
                    minHeight: 7,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'در حال دانلود درس‌ها…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${NumberFormat.toLatin('${player.categoryDownloadDone}')}'
                      ' از '
                      '${NumberFormat.toLatin('${player.categoryDownloadTotal}')}',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: accentInk,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SPEAKER TILE + SPEAKER HEADER
// ═══════════════════════════════════════════════════════════════

class _SpeakerTile extends StatelessWidget {
  final AudioSpeaker speaker;
  final AudioCategory category;
  final Color accent;
  final int index;
  final VoidCallback onTap;
  const _SpeakerTile({
    required this.speaker,
    required this.category,
    required this.accent,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tracks = speaker.tracks.length;
    final mb = speaker.totalSizeBytes / (1024 * 1024);
    final sizeText = mb >= 100 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final player = AudioLibraryPlayer.instance;
    final batch = player.downloadingCategory &&
        player.downloadingCategoryId == '${category.id}:${speaker.id}';
    final progress = player.categoryProgress ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: batch ? null : onTap,
        padding: const EdgeInsets.all(12),
        color: accent.withValues(alpha: isDark ? 0.16 : 0.07),
        borderColor: accent.withValues(alpha: 0.30),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.mic_external_on_outlined, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    speaker.title,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.toLatin('$tracks')} درس • '
                    '${NumberFormat.toLatin(sizeText)} مگابایت',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (player.newCountForSpeaker(category.id, speaker.id) > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: warn,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${NumberFormat.toLatin(player.newCountForSpeaker(category.id, speaker.id).toString())} جدید',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w800,
                    color: dsContentColor(context, warn),
                  ),
                ),
              ),
            ],
            if (batch)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  value: progress,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.18),
                ),
              )
            else
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: t.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerHeader extends StatelessWidget {
  final AudioSpeaker speaker;
  final AudioCategory category;
  final Color accent;
  final VoidCallback onBack;
  const _SpeakerHeader({
    required this.speaker,
    required this.category,
    required this.accent,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final accentInk = dsContentColor(context, accent);
    final player = AudioLibraryPlayer.instance;
    final tracks = speaker.tracks.length;
    final mb = speaker.totalSizeBytes / (1024 * 1024);
    final sizeText = mb >= 100 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
    final allDownloaded =
        speaker.tracks.every((t) => player.stateOf(t).downloaded);
    final batch = player.downloadingCategory &&
        player.downloadingCategoryId == '${category.id}:${speaker.id}';
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
      borderColor: accent.withValues(alpha: 0.30),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'بازگشت',
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaker.title,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${NumberFormat.toLatin('$tracks')} درس • '
                          '${NumberFormat.toLatin(sizeText)} مگابایت',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            color: t.textMuted,
                          ),
                        ),
                        // The speaker's OWN count. This header used to read
                        // the category's, so opening one speaker showed the
                        // other speaker's «۳ جدید» over a list that had none.
                        if (player.newCountForSpeaker(category.id, speaker.id) > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: warn,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${NumberFormat.toLatin(player.newCountForSpeaker(category.id, speaker.id).toString())} جدید',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: dsContentColor(context, warn),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (batch)
                IconButton(
                  tooltip: 'لغو دانلود',
                  onPressed: player.cancelDownload,
                  icon: Icon(Icons.close_rounded, color: danger),
                )
              else if (allDownloaded)
                Icon(Icons.check_circle_outline, color: t.textMuted)
              else
                IconButton(
                  tooltip: 'دانلود همه برای پخش آفلاین',
                  onPressed: () => player.downloadCategory(
                    '${category.id}:${speaker.id}',
                    speaker.tracks,
                  ),
                  icon: Icon(Icons.cloud_download_outlined, color: accent),
                ),
            ],
          ),
          if (batch) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: player.categoryProgress ?? 0,
                minHeight: 7,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'در حال دانلود درس‌ها…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${NumberFormat.toLatin('${player.categoryDownloadDone}')}'
                  ' از '
                  '${NumberFormat.toLatin('${player.categoryDownloadTotal}')}',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TRACK CARD
// ═══════════════════════════════════════════════════════════════

class _AudioTrackCard extends StatefulWidget {
  final AudioTrack track;
  final AudioCategory category;
  final int lessonNumber;
  const _AudioTrackCard({
    required this.track,
    required this.category,
    required this.lessonNumber,
  });

  @override
  State<_AudioTrackCard> createState() => _AudioTrackCardState();
}

class _AudioTrackCardState extends State<_AudioTrackCard> {
  /// While the user drags the slider, live position updates are suppressed so
  /// the thumb does not fight with the drag gesture.
  double? _dragValue;

  AudioTrack get track => widget.track;

  @override
  Widget build(BuildContext context) {
    final service = AudioLibraryPlayer.instance;
    final category = widget.category;
    final accent = _categoryHue(category.id);
    final title = category.trackDisplayTitle(track);
    final st = service.stateOf(track);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final accentInk = dsContentColor(context, accent);
    final isPlaying = st.playing;
    final isDownloading = st.downloading;
    final isActive = isPlaying ||
        st.loading ||
        _dragValue != null ||
        st.position > Duration.zero;
    final isCurrent = service.playingId == track.id;

    // Seek-bar limit: the reported duration, or the farthest position seen so
    // far (or a duration persisted earlier) so the bar works even when the
    // streamed duration never arrives on some devices.
    final seekLimit = service.seekLimitOf(track);
    final hasSeek = seekLimit > Duration.zero;
    final canSeek = hasSeek && !isDownloading;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: isCurrent ? accent.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                enabled: !isDownloading,
                label: isDownloading
                    ? 'در حال دانلود'
                    : (isPlaying ? 'توقف' : 'پخش'),
                child: GestureDetector(
                  onTap:
                      isDownloading ? null : () => service.togglePlay(track),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          accent.withValues(alpha: isPlaying ? 0.18 : 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.45), width: 1.2),
                    ),
                    child: st.loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: warn),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 30,
                            color: accent,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            NumberFormat.toLatin('${widget.lessonNumber}'),
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w800,
                              color: accentInk,
                            ),
                          ),
                        ),
                        if (service.isNewTrack(track.id)) ...[
                          const SizedBox(width: 6),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: warn,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'جدید',
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: dsContentColor(context, warn),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          // Long titles are never cut silently: the shared
                          // «بیشتر» recipe shows one line by default (short
                          // titles render pixel-identical, no toggle) and
                          // opens the full title on tap — the card keeps its
                          // compact size unless the user expands it.
                          child: ExpandableText(
                            title,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      st.error != null
                          ? st.error!
                          : isPlaying
                              ? 'در حال پخش…'
                              : isDownloading
                                  ? 'در حال دانلود…'
                                  : st.position > Duration.zero
                                      ? 'ادامه از ${AudioLibraryPlayer.formatDuration(st.position)}'
                                      : '${track.approxSizeMb.toStringAsFixed(1)} مگابایت',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: st.error != null ? danger : t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AudioActionButton(track: track),
            ],
          ),
          if (isActive && hasSeek) ...[
            const SizedBox(height: 4),
            ValueListenableBuilder<Duration>(
              valueListenable: service.positionListenable,
              builder: (context, livePos, _) {
                // The notifier carries the active track's playhead; a paused
                // card that merely has a saved resume point must use its own
                // stored position instead.
                final pos = isCurrent ? livePos : st.position;
                final shown = _dragValue != null
                    ? Duration(seconds: _dragValue!.round())
                    : pos;
                return Row(
                  children: [
                    Text(
                      AudioLibraryPlayer.formatDuration(shown),
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: t.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _dragValue ??
                              (canSeek
                                  ? pos.inMilliseconds
                                      .clamp(0.0, seekLimit.inMilliseconds)
                                      .toDouble()
                                  : 0),
                          max:
                              canSeek ? seekLimit.inMilliseconds.toDouble() : 0,
                          onChanged: canSeek
                              ? (v) => setState(() => _dragValue = v)
                              : null,
                          onChangeEnd: canSeek
                              ? (v) {
                                  service
                                      .seek(Duration(milliseconds: v.round()));
                                  setState(() => _dragValue = null);
                                }
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      AudioLibraryPlayer.formatDuration(seekLimit),
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: t.textMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (isDownloading && st.progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: st.progress,
                minHeight: 7,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(st.progress! * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  ),
                ),
                Text(
                  '${(st.received / (1024 * 1024)).toStringAsFixed(1)} / '
                  '${track.approxSizeMb.toStringAsFixed(1)} MB',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// دکمه کناری کارت: دانلود / لغو دانلود / حذف فایل — بسته به وضعیت.
class _AudioActionButton extends StatelessWidget {
  final AudioTrack track;
  const _AudioActionButton({required this.track});

  @override
  Widget build(BuildContext context) {
    final service = AudioLibraryPlayer.instance;
    final st = service.stateOf(track);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final accent = _categoryHue(service.categoryOf(track.id) ?? '');

    if (st.downloading) {
      return IconButton(
        tooltip: 'لغو دانلود',
        onPressed: service.cancelDownload,
        icon: Icon(Icons.close_rounded, color: danger),
      );
    }
    if (st.downloaded) {
      return IconButton(
        tooltip: 'حذف فایل',
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: TimeThemeKit.of(ctx).palette.card,
              surfaceTintColor: Colors.transparent,
              title: const Text('حذف فایل صوتی'),
              content: Text('فایل «${track.title}» از حافظه دستگاه حذف شود؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('حذف', style: TextStyle(color: danger)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await service.delete(track);
          }
        },
        icon: Icon(Icons.delete_outline_rounded, color: t.textMuted),
      );
    }
    return IconButton(
      tooltip: 'دانلود برای پخش آفلاین',
      iconSize: 26,
      onPressed: () => service.download(track),
      icon: Icon(Icons.download_rounded, color: accent),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INFO BOX — راهنمای آفلاین
// ═══════════════════════════════════════════════════════════════

class _OfflineNote extends StatelessWidget {
  final Color accent;
  const _OfflineNote({required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.download_for_offline_outlined, color: warn, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'برای پخش آفلاین، «دانلود همه» را در هر دسته بزنید یا کنار هر درس'
              ' «دانلود» کنید؛ فایل روی دستگاه ذخیره می‌شود و پخش بعدی به اینترنت'
              ' نیاز ندارد.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.6,
                color: t.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH RESULTS — جستجوی زندهٔ سراسری روی همهٔ دسته‌ها
// ═══════════════════════════════════════════════════════════════

class _SearchResults extends StatelessWidget {
  final String query;
  final List<AudioCategory> categories;
  final Color Function(String) accentOf;
  const _SearchResults({
    required this.query,
    required this.categories,
    required this.accentOf,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final q = query.trim().toLowerCase();
    final hits = <(AudioCategory, AudioTrack)>[];
    if (q.isNotEmpty) {
      for (final c in categories) {
        for (final t in c.tracks) {
          final title = c.trackDisplayTitle(t).toLowerCase();
          if (title.contains(q)) hits.add((c, t));
        }
      }
    }
    if (q.isEmpty) {
      return Center(
        child: Text(
          'چیزی بنویسید تا در همهٔ درس‌ها جستجو شود…',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12.5),
            color: t.textMuted,
          ),
        ),
      );
    }
    if (hits.isEmpty) {
      return Center(
        child: Text(
          'نتیجه‌ای یافت نشد.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12.5),
            color: t.textMuted,
          ),
        ),
      );
    }
    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 32),
      itemCount: hits.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${NumberFormat.toLatin('${hits.length}')} نتیجه',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                color: t.textMuted,
              ),
            ),
          );
        }
        final (category, track) = hits[i - 1];
        // The number is the track's place in its own category. Passing a
        // literal 1 labelled every search result «درس ۱».
        final index = category.tracks.indexOf(track);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AudioTrackCard(
            track: track,
            category: category,
            lessonNumber: index >= 0 ? index + 1 : 1,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STORAGE SHEET — مدیریت فضای دانلودی
// ═══════════════════════════════════════════════════════════════

class _StorageSheet extends StatelessWidget {
  final int usedBytes;
  final int trackCount;
  final Color accent;
  final Future<void> Function() onDeleteAll;
  const _StorageSheet({
    required this.usedBytes,
    required this.trackCount,
    required this.accent,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final mb = usedBytes / (1024 * 1024);
    final sizeText = mb >= 100 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مدیریت فضای دانلودی',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.storage_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'فضای اشغال‌شده توسط درس‌های ذخیره‌شده',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      color: t.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${NumberFormat.toLatin(sizeText)} مگابایت',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'حذف فایل‌ها پخش استریم را مختل نمی‌کند؛ هر درس را می‌توان دوباره دانلود کرد.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              style: FilledButton.styleFrom(foregroundColor: danger),
              onPressed: onDeleteAll,
              child: const Text('حذف همهٔ فایل‌های دانلودی'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
