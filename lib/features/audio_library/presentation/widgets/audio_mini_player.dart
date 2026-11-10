import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/sheet_handle.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Persistent bottom playback bar shown while a track is loaded in the audio
/// library. Card keeps all advanced player controls (skip ±15s, speed, repeat,
/// auto-next, sleep timer) in one place, so the track cards stay scannable.
/// The progress bar is a live seek bar: drag anywhere to jump in the lesson.
class AudioMiniPlayer extends StatefulWidget {
  final AudioLibraryPlayer player;
  final Color accent;

  const AudioMiniPlayer(
      {super.key, required this.player, required this.accent});

  @override
  State<AudioMiniPlayer> createState() => _AudioMiniPlayerState();
}

class _AudioMiniPlayerState extends State<AudioMiniPlayer> {
  /// While the user drags the slider, live position updates are suppressed so
  /// the thumb does not fight with the drag gesture.
  double? _dragValue;

  AudioLibraryPlayer get player => widget.player;

  /// Persistent bottom playback bar shown while a track is loaded in the audio
  /// library. Card keeps all advanced player controls (skip ±15s, speed, repeat,
  /// auto-next, sleep timer) in one place, so the track cards stay scannable.
  /// The progress bar is a live seek bar: drag anywhere to jump in the lesson.
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void didUpdateWidget(covariant AudioMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.activeTrack?.id != widget.player.activeTrack?.id) {
      _dragValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = player.activeTrack;
    if (track == null) return const SizedBox.shrink();
    final st = player.activeState ?? const AudioLibraryTrackState();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final remaining = player.sleepRemaining;
    final sleepOn = player.sleepTimerActive;
    final byline = player.bylineOf(track.id);

    // Seek bar limit: the reported duration, or the farthest position seen so
    // far (or a duration persisted earlier) so the bar works even when the
    // streamed duration never arrives on some devices.
    final seekLimit = player.seekLimitOf(track);
    final hasSeek = seekLimit > Duration.zero;
    final canSeek = hasSeek && !st.downloading;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: st.playing ? 'توقف' : 'پخش',
                child: GestureDetector(
                  onTap: () => player.togglePlay(track),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: widget.accent.withValues(alpha: 0.5)),
                    ),
                    child: st.loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: widget.accent),
                          )
                        : Icon(
                            st.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: widget.accent,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      byline == null ? track.title : '${track.title} ($byline)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<Duration>(
                      valueListenable: player.positionListenable,
                      builder: (context, livePos, _) => Text(
                        '${_fa(AudioLibraryPlayer.formatDuration(livePos))}'
                        ' / '
                        '${hasSeek ? _fa(AudioLibraryPlayer.formatDuration(seekLimit)) : '…'}',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (sleepOn) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bedtime_outlined,
                          size: 13, color: widget.accent),
                      const SizedBox(width: 4),
                      Text(
                        _fa(AudioLibraryPlayer.formatDuration(remaining!)),
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Seek bar: draggable anywhere on the track.
          ValueListenableBuilder<Duration>(
            valueListenable: player.positionListenable,
            builder: (context, livePos, _) => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _dragValue ??
                    (canSeek
                        ? livePos.inMilliseconds
                            .clamp(0.0, seekLimit.inMilliseconds)
                            .toDouble()
                        : 0),
                max: canSeek ? seekLimit.inMilliseconds.toDouble() : 0,
                onChanged:
                    canSeek ? (v) => setState(() => _dragValue = v) : null,
                onChangeEnd: canSeek
                    ? (v) {
                        player.seek(Duration(milliseconds: v.round()));
                        setState(() => _dragValue = null);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Same convention as the mushaf transport bar: keep the universal
          // player layout left→right, so each skip icon points the way time
          // actually moves instead of being mirrored by hand.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Ctrl(
                  icon: Icons.fast_rewind,
                  tooltip: '15 ثانیه به عقب',
                  accent: widget.accent,
                  onTap: () => player.seekBy(const Duration(seconds: -15)),
                ),
                _Ctrl(
                  text: _formatSpeed(player.speed),
                  tooltip: 'سرعت پخش',
                  accent: widget.accent,
                  active: player.speed != 1.0,
                  onTap: () => _showSpeedSheet(context),
                ),
                _Ctrl(
                  icon: _repeatIcon(player.repeatMode),
                  tooltip: 'تکرار',
                  accent: widget.accent,
                  active: player.repeatMode != AudioPlaybackMode.off,
                  onTap: player.cycleRepeatMode,
                ),
                _Ctrl(
                  icon: Icons.playlist_play_rounded,
                  tooltip: 'پخش خودکار درس بعدی',
                  accent: widget.accent,
                  active: player.autoNext,
                  onTap: () => player.setAutoNext(!player.autoNext),
                ),
                _Ctrl(
                  icon: Icons.shuffle_rounded,
                  tooltip: 'پخش تصادفی در همان گروه',
                  accent: widget.accent,
                  active: player.shuffle,
                  onTap: () => player.setShuffle(!player.shuffle),
                ),
                _Ctrl(
                  icon:
                      sleepOn ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                  tooltip: 'تایمر خواب',
                  accent: widget.accent,
                  active: sleepOn,
                  onTap: () => _showSleepSheet(context),
                ),
                _Ctrl(
                  icon: Icons.fast_forward,
                  tooltip: '15 ثانیه به جلو',
                  accent: widget.accent,
                  onTap: () => player.seekBy(const Duration(seconds: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _repeatIcon(AudioPlaybackMode mode) {
    switch (mode) {
      case AudioPlaybackMode.off:
        return Icons.repeat;
      case AudioPlaybackMode.one:
        return Icons.repeat_one;
      case AudioPlaybackMode.category:
        return Icons.repeat_on;
    }
  }

  static String _formatSpeed(double v) {
    final t = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return '${NumberFormat.toLatin(t).replaceAll('.', '٫')}×';
  }

  static String _fa(String s) => NumberFormat.toLatin(s);

  Future<void> _showSpeedSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PlayerSheet(
        title: 'سرعت پخش',
        children: [
          for (final s in _speeds)
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text(_formatSpeed(s).replaceAll('×', '')),
              trailing: s == player.speed
                  ? Icon(Icons.check_circle, color: widget.accent)
                  : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (selected != null) {
      await player.setSpeed(selected);
    }
  }

  Future<void> _showSleepSheet(BuildContext context) async {
    final st = player.activeState ?? const AudioLibraryTrackState();
    final endOfLesson = st.hasDuration && st.duration > st.position
        ? st.duration - st.position
        : null;
    final pick = await showModalBottomSheet<_SleepPick>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PlayerSheet(
        title: 'تایمر خواب',
        children: [
          ListTile(
            leading: const Icon(Icons.bedtime_off_outlined),
            title: const Text('خاموش'),
            onTap: () => Navigator.pop(ctx, const _SleepPick()),
          ),
          if (endOfLesson != null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('پایان این درس'),
              onTap: () => Navigator.pop(ctx, _SleepPick(endOfLesson)),
            ),
          for (final m in const [15, 30, 45, 60])
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('${NumberFormat.toLatin('$m')} دقیقه'),
              onTap: () => Navigator.pop(ctx, _SleepPick(Duration(minutes: m))),
            ),
        ],
      ),
    );
    if (pick != null) {
      player.setSleepTimer(pick.duration);
    }
  }
}

/// Distinguishes an explicit «خاموش» pick (null duration) from dismissing the
/// sheet (pick == null).
class _SleepPick {
  final Duration? duration;
  const _SleepPick([this.duration]);
}

class _PlayerSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PlayerSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 10),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 8)),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ctrl extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final String tooltip;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _Ctrl({
    this.icon,
    this.text,
    required this.tooltip,
    required this.accent,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: text != null
              ? Text(
                  text!,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w800,
                    color: active ? accent : t.textSecondary,
                  ),
                )
              : Icon(
                  icon,
                  size: 23,
                  color: active ? accent : t.textSecondary,
                ),
        ),
      ),
    );
  }
}
