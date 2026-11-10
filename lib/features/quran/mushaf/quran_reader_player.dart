// Recitation player — collapsed floating panel + expanded bottom sheet.
//
// Spec A: the collapsed panel is a gradient card (radius 24) with a 3dp gold
// progress line, a chevron to expand, the verse title, a "<reciter> · mm:ss"
// subtitle and prev / play-pause / next. Everything that used to crowd the
// reader header (reciter, speed, repeat, sleep, offline state, stop) lives in
// the expanded sheet instead.
//
// The button shows a determinate ring while loading — the old hourglass gave
// no sense of progress and looked like a dead control.

part of 'quran_mushaf_view.dart';

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.audio,
    required this.palette,
    required this.onToggle,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onContinuous,
    required this.onSetRepeat,
    required this.onSetSpeed,
    required this.onPlayChapter,
    required this.onHide,
    this.onShowRepeatRange,
    this.onShowSleepTimer,
    this.sleepRemaining,
    this.onShowReciter,
    this.reciterName = '',
  });

  final QuranAudioController audio;
  final MushafPalette palette;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final ValueChanged<bool> onContinuous;
  final ValueChanged<int> onSetRepeat;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onPlayChapter;
  final VoidCallback onHide;
  final VoidCallback? onShowRepeatRange;
  final VoidCallback? onShowSleepTimer;
  final ValueListenable<Duration?>? sleepRemaining;

  /// Opens the reciter picker — was a header chip, now the sheet's first row.
  final VoidCallback? onShowReciter;
  final String reciterName;

  @override
  Widget build(BuildContext context) {
    final visible =
        audio.hasSession || audio.isLoading || audio.errorMessage != null;
    if (!visible) return const SizedBox.shrink();

    final progress = audio.duration.inMilliseconds > 0
        ? (audio.position.inMilliseconds / audio.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Padding(
      // 10dp side margins so the card floats above the bottom nav instead of
      // bleeding into it.
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _readerChromeColor(),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 3dp gold progress line pinned to the top edge.
                LinearProgressIndicator(
                  value: audio.isLoading ? null : progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppPalette.heroGold),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'گزینه‌های پخش',
                        icon: const Icon(Icons.keyboard_arrow_up_rounded,
                            color: AppPalette.heroGold, size: 24),
                        onPressed: () => _showPlayerSheet(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              audio.errorMessage ?? audio.verseLabel,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.cream,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              audio.isLoading
                                  ? 'در حال بارگذاری…'
                                  : audio.isStalled
                                      ? 'اتصال ضعیف…'
                                      : '${reciterName.isEmpty ? 'قاری' : reciterName} · ${_fmt(audio.position)}',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                color:
                                    AppPalette.heroGold.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Media transport keeps the universal player layout
                      // (prev | play | next, left→right) even inside this RTL
                      // screen — otherwise skip icons point opposite to their
                      // action.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'آیه‌ی بعدی',
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: AppPalette.cream, size: 22),
                              onPressed: onNext,
                            ),
                            _PlayButton(
                              loading: audio.isLoading,
                              playing: audio.isPlaying,
                              onPressed: onToggle,
                            ),
                            IconButton(
                              tooltip: 'آیه‌ی قبلی',
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: AppPalette.cream, size: 22),
                              onPressed: onPrev,
                            ),
                          ],
                        ),
                      ),
                      // Tuck the panel away without stopping playback — the
                      // page comes back and a small resume pill replaces the
                      // bar (any new play-tap restores it too).
                      IconButton(
                        tooltip: 'مخفی کردن نوار پخش',
                        icon: const Icon(Icons.expand_more_rounded,
                            color: AppPalette.heroGold, size: 24),
                        onPressed: onHide,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The expanded bottom sheet: reciter, speed, repeat, sleep, offline state
  /// and stop — everything the header used to carry.
  void _showPlayerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.surfaceText.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تنظیمات پخش',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.surfaceText,
                ),
              ),
              const SizedBox(height: 12),
              _sheetRow(
                context,
                Icons.record_voice_over_rounded,
                title: 'قاری',
                subtitle: reciterName.isEmpty ? 'انتخاب نشده' : reciterName,
                trailing: const Icon(Icons.expand_more, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  onShowReciter?.call();
                },
              ),
              _sheetRow(
                context, Icons.speed,
                title: 'سرعت پخش',
                subtitle:
                    '${audio.playbackRate}x · نگه‌داشتن: ${_speedFlipTarget}x',
                onTap: () => _pickSpeed(ctx),
                // Report §7.6: a long-press jumps straight between the two
                // rates a reader actually needs — 1× to listen, 2× to review —
                // so the picker is only opened for the in-between steps.
                onLongPress: () => onSetSpeed(_speedFlipTarget),
              ),
              _sheetRow(
                context,
                Icons.repeat_rounded,
                title: 'تکرار',
                subtitle: _repeatLabel(),
                onTap: () => _pickRepeat(ctx),
              ),
              if (onShowRepeatRange != null)
                _sheetRow(
                  context,
                  Icons.repeat_on_rounded,
                  title: 'تکرار بازه‌ای',
                  subtitle: 'برای حفظ',
                  onTap: () {
                    Navigator.pop(ctx);
                    onShowRepeatRange!();
                  },
                ),
              if (onShowSleepTimer != null)
                _sheetRow(
                  context,
                  Icons.bedtime_outlined,
                  title: 'تایمر خواب',
                  subtitle: sleepRemaining?.value == null
                      ? 'خاموش'
                      : _fmt(sleepRemaining!.value!),
                  onTap: () {
                    Navigator.pop(ctx);
                    onShowSleepTimer!();
                  },
                ),
              _sheetRow(
                context,
                Icons.play_circle_outline,
                title: 'پخش از ابتدای سوره',
                subtitle: 'سورهٔ ${audio.chapter}',
                onTap: () {
                  Navigator.pop(ctx);
                  onPlayChapter();
                },
              ),
              _sheetRow(
                context,
                audio.continuous
                    ? Icons.repeat_rounded
                    : Icons.stop_circle_outlined,
                title: 'پخش پیوسته',
                subtitle: audio.continuous ? 'روشن' : 'خاموش',
                onTap: () => onContinuous(!audio.continuous),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onStop();
                },
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('توقف پخش'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.walnut,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel() => switch (audio.repeatCount) {
        0 => 'خاموش',
        1 => '2 بار',
        _ => '${audio.repeatCount + 1} بار',
      };

  /// Where the speed row's long-press jumps to (report §7.6): from 2×/1.5×
  /// back to 1×, and from anything slower up to 2×.
  double get _speedFlipTarget => audio.playbackRate >= 1.5 ? 1.0 : 2.0;

  Widget _sheetRow(
    BuildContext context,
    IconData icon, {
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    // The player's options sheet is a list like any other, so it wears the
    // same kit row as the reciter, downloads and search lists — one design
    // language across the reader. The sheet already pads 16 horizontally, so
    // the row contributes only its vertical rhythm.
    return QuranKitRow(
      palette: palette,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(vertical: 5),
    );
  }

  void _pickSpeed(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The engine clamps to 0.5–2.0, so the picker now reaches the
              // ceiling: the reader asked for up to 2× for review listening.
              for (final r in [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]) ...[
                QuranKitRow(
                  palette: palette,
                  icon: Icons.speed_rounded,
                  title: '${r}x',
                  selected: audio.playbackRate == r,
                  trailing: audio.playbackRate == r
                      ? Icon(Icons.check_rounded,
                          color: palette.accent, size: 20)
                      : null,
                  onTap: () {
                    onSetSpeed(r);
                    Navigator.pop(c);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _pickRepeat(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in [0, 1, 2, 3]) ...[
                QuranKitRow(
                  palette: palette,
                  icon: Icons.repeat_rounded,
                  title: switch (n) {
                    0 => 'خاموش',
                    1 => '2 بار',
                    _ => '${n + 1} بار',
                  },
                  selected: audio.repeatCount == n,
                  trailing: audio.repeatCount == n
                      ? Icon(Icons.check_rounded,
                          color: palette.accent, size: 20)
                      : null,
                  onTap: () {
                    onSetRepeat(n);
                    Navigator.pop(c);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// The 44dp gold-gradient transport button. While loading it shows a
/// determinate ring instead of the old hourglass, so the control reads as
/// busy rather than dead.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.loading,
    required this.playing,
    required this.onPressed,
  });

  final bool loading;
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'توقف' : 'پخش',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Ink(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppPalette.heroGold, AppPalette.heroGoldDeep],
                ),
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.espresso,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppTheme.espresso,
                        size: 26,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranslationMiniPlayer extends StatelessWidget {
  const _TranslationMiniPlayer({
    required this.audio,
    required this.palette,
    required this.onToggle,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onContinuous,
    required this.onCombined,
    required this.onSetSpeed,
    required this.onHide,
  });

  final QuranTranslationAudioController audio;
  final MushafPalette palette;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final ValueChanged<bool> onContinuous;

  /// «تلاوت سپس ترجمه» — plays the ayah's recitation before its translation.
  final ValueChanged<bool> onCombined;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    if (!audio.hasSession && audio.errorMessage == null) {
      return const SizedBox.shrink();
    }

    final progress = audio.duration.inMilliseconds > 0
        ? (audio.position.inMilliseconds / audio.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    // The panel wears the SAME shape as the talaawah player (reader request):
    // a floating 24-radius gradient card with a 3dp gold progress line pinned
    // to its top edge, the verse title over a muted second line, and the
    // universal prev | play | next transport in one cluster. Its own settings
    // (speed, continuous, stop) moved behind the tune button so the two
    // players are the same object visually.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _readerChromeColor(),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: audio.isLoading ? null : progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppPalette.heroGold),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'تنظیمات پخش',
                        icon: const Icon(Icons.tune,
                            color: AppPalette.heroGold, size: 24),
                        color: palette.surface,
                        onSelected: (value) {
                          if (value == 'continuous') {
                            onContinuous(!audio.continuous);
                          } else if (value == 'combined') {
                            onCombined(!audio.combinedWithRecitation);
                          } else if (value == 'stop') {
                            onStop();
                          } else if (value.startsWith('speed:')) {
                            onSetSpeed(double.parse(value.substring(6)));
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'combined',
                            child: _menuRow(
                              audio.combinedWithRecitation
                                  ? Icons.playlist_play_rounded
                                  : Icons.g_translate,
                              audio.combinedWithRecitation
                                  ? 'تلاوت سپس ترجمه'
                                  : 'فقط ترجمه',
                              audio.combinedWithRecitation,
                              palette,
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'continuous',
                            child: _menuRow(
                              audio.continuous
                                  ? Icons.repeat_rounded
                                  : Icons.stop_circle_outlined,
                              audio.continuous
                                  ? 'پخش پیوسته (ترجمه)'
                                  : 'توقف بعد از هر آیه',
                              audio.continuous,
                              palette,
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'speed:0.5',
                            child: _menuRow(Icons.speed, 'سرعت: 0٫5×',
                                audio.playbackRate == 0.5, palette),
                          ),
                          PopupMenuItem(
                            value: 'speed:0.75',
                            child: _menuRow(Icons.speed, 'سرعت: 0٫75×',
                                audio.playbackRate == 0.75, palette),
                          ),
                          PopupMenuItem(
                            value: 'speed:1.0',
                            child: _menuRow(Icons.speed, 'سرعت: 1×',
                                audio.playbackRate == 1.0, palette),
                          ),
                          PopupMenuItem(
                            value: 'speed:1.25',
                            child: _menuRow(Icons.speed, 'سرعت: 1٫25×',
                                audio.playbackRate == 1.25, palette),
                          ),
                          PopupMenuItem(
                            value: 'speed:1.5',
                            child: _menuRow(Icons.speed, 'سرعت: 1٫5×',
                                audio.playbackRate == 1.5, palette),
                          ),
                          PopupMenuItem(
                            value: 'speed:2.0',
                            child: _menuRow(Icons.speed, 'سرعت: 2×',
                                audio.playbackRate == 2.0, palette),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'stop',
                            child: _menuRow(
                                Icons.stop_rounded, 'توقف پخش', false, palette),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              audio.errorMessage ?? audio.verseLabel,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.cream,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              audio.isLoading
                                  ? 'در حال بارگذاری…'
                                  : '${audio.isPlayingRecitation ? 'تلاوت' : 'ترجمهٔ صوتی'} · ${audio.positionLabel}',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                color:
                                    AppPalette.heroGold.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Universal player layout (prev | play | next,
                      // left→right) inside this RTL screen, exactly like the
                      // talaawah panel.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'آیه‌ی بعدی',
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: AppPalette.cream, size: 22),
                              onPressed: onNext,
                            ),
                            _PlayButton(
                              loading: audio.isLoading,
                              playing: audio.isPlaying,
                              onPressed: onToggle,
                            ),
                            IconButton(
                              tooltip: 'آیه‌ی قبلی',
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: AppPalette.cream, size: 22),
                              onPressed: onPrev,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'مخفی کردن نوار پخش',
                        icon: const Icon(Icons.expand_more_rounded,
                            color: AppPalette.heroGold, size: 24),
                        onPressed: onHide,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _menuRow(
      IconData icon, String label, bool selected, MushafPalette palette) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: selected ? palette.accent : palette.surfaceText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: palette.surfaceText,
            ),
          ),
        ),
        if (selected) Icon(Icons.check, size: 16, color: palette.accent),
      ],
    );
  }
}
