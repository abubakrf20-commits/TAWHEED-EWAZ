import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Which rite the counter is counting. Both are seven rounds; only the labels
/// differ — and for sa'i the leg direction alternates.
enum CounterKind { tawaf, sai }

/// The leg of sa'i that round [round] (1-based) covers.
///
/// Round 1 sets out from صفا, so the odd rounds go and the even ones return —
/// four out, three back, which is the count the guide states.
String saiLeg(int round) => round.isOdd ? 'صفا به مروه' : 'مروه به صفا';

const int kRoundsPerRite = 7;

/// Opens the tawaf/sa'i counter.
///
/// WHY a counter at all: in the mataf the count is the one thing that gets
/// lost. This is the only control in the guide that is used *during* the rite
/// rather than before it, so it is a sheet — one tap per round, no scrolling,
/// and the number survives the app being killed in a crowd.
Future<void> showRiteCounterSheet(
  BuildContext context, {
  CounterKind kind = CounterKind.tawaf,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    // No local `shape:` — the sheet radius belongs to the theme, so this sheet
    // and every other one in the app open with the same corner.
    builder: (_) => _RiteCounterSheet(initialKind: kind),
  );
}

class _RiteCounterSheet extends StatefulWidget {
  const _RiteCounterSheet({required this.initialKind});

  final CounterKind initialKind;

  @override
  State<_RiteCounterSheet> createState() => _RiteCounterSheetState();
}

class _RiteCounterSheetState extends State<_RiteCounterSheet> {
  late CounterKind _kind = widget.initialKind;
  int _round = 0;

  /// The stored count for [_kind] has been read. Taps stay inert until then so
  /// an early tap cannot be overwritten by the arriving value.
  bool _loaded = false;

  String _key(CounterKind kind) => 'hajj_counter_${kind.name}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var round = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      round = prefs.getInt(_key(_kind)) ?? 0;
    } catch (e) {
      AppLogger.warning('rite_counter', 'counter read failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _round = round.clamp(0, kRoundsPerRite);
      _loaded = true;
    });
  }

  Future<void> _persist(int round) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(_kind), round);
    } catch (e) {
      AppLogger.warning('rite_counter', 'counter write failed: $e');
    }
  }

  void _setKind(CounterKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      _round = 0;
      _loaded = false;
    });
    _load();
  }

  void _add() {
    if (!_loaded || _round >= kRoundsPerRite) return;
    final next = _round + 1;
    HapticFeedback.mediumImpact();
    setState(() => _round = next);
    _persist(next);
  }

  void _undo() {
    if (!_loaded || _round == 0) return;
    HapticFeedback.selectionClick();
    final next = _round - 1;
    setState(() => _round = next);
    _persist(next);
  }

  void _restart() {
    HapticFeedback.selectionClick();
    setState(() => _round = 0);
    _persist(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.hajjUmrah;
    final isSai = _kind == CounterKind.sai;
    final done = _round >= kRoundsPerRite;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: t.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSai ? 'شمارنده سعی' : 'شمارنده طواف',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'هر دور یک تپ · شمارش در حافظه می‌ماند',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'بستن',
                icon: Icon(Icons.close, size: 20, color: t.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _KindSwitch(kind: _kind, accent: accent, onChanged: _setKind),
          const SizedBox(height: 18),
          _CounterButton(
            round: _round,
            done: done,
            accent: accent,
            onTap: _add,
            caption: isSai
                ? (_round == 0 ? 'شروع از صفا' : saiLeg(_round))
                : (_round == 0 ? 'آمادهٔ شمارش' : 'دور $_round'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= kRoundsPerRite; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 26,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= _round
                          ? accent
                          : accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (done)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _restart,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  isSai ? 'سعی کامل شد — سعی جدید' : 'طواف کامل شد — طواف جدید',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _round == 0 ? null : _undo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.outline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.undo, size: 17),
                    label: Text(
                      'یک دور عقب',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _round == 0 ? null : _restart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.outline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 17),
                    label: Text(
                      'شروع از نو',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            isSai
                ? 'سعی هفت دور است: چهار دور از صفا به مروه و سه دور بازگشت.'
                : 'طواف هفت دور گرد کعبه است، از حجرالاسود و به حجرالاسود.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              height: 1.6,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// طواف / سعی — two pills, the active one filled.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({
    required this.kind,
    required this.accent,
    required this.onChanged,
  });

  final CounterKind kind;
  final Color accent;
  final ValueChanged<CounterKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    Widget pill(CounterKind value, String label) {
      final active = value == kind;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: active ? accent.withValues(alpha: 0.45) : t.outline,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? accent : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(CounterKind.tawaf, 'طواف'),
        const SizedBox(width: 8),
        pill(CounterKind.sai, 'سعی'),
      ],
    );
  }
}

/// The tap target: one huge numeral inside a ring that fills as rounds pass.
class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.round,
    required this.done,
    required this.accent,
    required this.onTap,
    required this.caption,
  });

  final int round;
  final bool done;
  final Color accent;
  final VoidCallback onTap;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const diameter = 178.0;
    return Semantics(
      button: true,
      label: done
          ? 'شمارش کامل شد'
          : 'شمارنده؛ با هر تپ یک دور اضافه می‌شود. اکنون $round از ۷',
      child: GestureDetector(
        key: const ValueKey('rite-counter-tap'),
        onTap: onTap,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CounterRingPainter(
                    progress: round / kRoundsPerRite,
                    accent: accent,
                    track: accent.withValues(alpha: 0.14),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done ? Icons.check_rounded : Icons.touch_app_outlined,
                    size: 20,
                    color: done ? accent : t.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$round',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 54),
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: done ? accent : t.textPrimary,
                    ),
                  ),
                  Text(
                    caption,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: done ? accent : t.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterRingPainter extends CustomPainter {
  const _CounterRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CounterRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      accent != oldDelegate.accent ||
      track != oldDelegate.track;
}
