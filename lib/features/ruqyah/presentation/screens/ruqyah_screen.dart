import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    hide SectionHeader;
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/features/ruqyah/data/ruqyah_content.dart';
import 'package:tawheeed/features/ruqyah/data/ruqyah_practical_content.dart';
import 'package:tawheeed/features/ruqyah/services/ruqyah_audio_service.dart';
import 'package:tawheeed/shared/services/share_service.dart';

/// «رقیه شرعی» — درمان با قرآن و سنت.
///
/// سه بخش: «مطالعه» (مقدمه، فصل‌های نظری و احادیث، خاتمه و توصیه‌ها)، «عملی»
/// (آیات، دعاها، دستورالعمل رقیه و اذکار حفاظتی روزانه) و «صوتی» (رقیه کامل
/// با صدای قاریان — دانلود از سرور و پخش آفلاین).
class RuqyahScreen extends StatelessWidget {
  const RuqyahScreen({super.key});

  static const Color _accent = TopicHues.ruqyah;

  /// رنگ هر بخش عملی — از سبز درمانی تا آبی، بنفش، نارنجی و سبز اذکار.
  static const List<Color> _sectionAccents = [
    Color(0xFF00695C),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    AppTheme.warning,
    AppTheme.success,
  ];

  static const List<String> _tabs = ['مطالعه', 'عملی', 'صوتی'];

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      id: 'ruqyah',
      title: 'رقیه شرعی',
      tabs: _tabs,
      searchEntries: ruqyahSearchEntries(),
      children: const [
        _StudyTab(),
        _PracticalTab(),
        _AudioTab(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1: مطالعه — مقدمه، فصل‌ها، خاتمه و توصیه‌ها
// ═══════════════════════════════════════════════════════════════

class _StudyTab extends StatelessWidget {
  const _StudyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const _Hero(),
        const SizedBox(height: 16),

        // ── مقدمه ────────────────────────────────────────────────────────
        const SectionHeader(
            title: 'مقدمه',
            icon: Icons.auto_stories,
            accentColor: RuqyahScreen._accent),
        const SizedBox(height: 8),
        ...RuqyahContent.intro.map((item) => _ItemCard(item: item)),
        const SizedBox(height: 16),

        // ── فصل‌ها ───────────────────────────────────────────────────────
        for (final chapter in RuqyahContent.chapters) ...[
          _ChapterCard(chapter: chapter),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),

        // ── خاتمه ────────────────────────────────────────────────────────
        const SectionHeader(
            title: 'خاتمه',
            icon: Icons.flag_outlined,
            accentColor: RuqyahScreen._accent),
        const SizedBox(height: 8),
        ...RuqyahContent.conclusion.map((item) => _ItemCard(item: item)),
        const SizedBox(height: 16),

        // ── توصیه‌های نهایی ──────────────────────────────────────────────
        const SectionHeader(
            title: 'توصیه‌های نهایی',
            icon: Icons.volunteer_activism_outlined,
            accentColor: RuqyahScreen._accent),
        const SizedBox(height: 8),
        const _RecommendationsCard(items: RuqyahContent.finalRecommendations),
        const SizedBox(height: 16),

        // ── هشدار مهم ────────────────────────────────────────────────────
        const InfoBox(
          text:
              'رقیه شرعی جایگزین درمان پزشکی نیست؛ در هنگام بیماری ابتدا به پزشک مراجعه کنید و از درمان‌های پزشکی غافل نشوید. رقیه تنها یکی از اسباب شفاست و شفا تنها از جانب خداوند است.',
          icon: Icons.medical_services_outlined,
          color: RuqyahScreen._accent,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2: عملی — آیات، دعاها، دستورالعمل و اذکار روزانه
// ═══════════════════════════════════════════════════════════════

class _PracticalTab extends StatelessWidget {
  const _PracticalTab();

  @override
  Widget build(BuildContext context) {
    const sections = RuqyahPracticalContent.sections;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const _PracticalIntro(),
        const SizedBox(height: 16),
        for (var i = 0; i < sections.length; i++) ...[
          _PracticalSectionCard(index: i, section: sections[i]),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _PracticalIntro extends StatelessWidget {
  const _PracticalIntro();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16322E) : const Color(0xFFE4F2EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'راهنمای عملی رقیه شرعی: آیات، دعاها، دستورالعمل کامل و اذکار حفاظتی روزانه. برای کپی، روی دکمه کپی کنار هر متن عربی بزنید.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                height: 1.7,
                color: t.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticalSectionCard extends StatelessWidget {
  final int index;
  final RuqyahPracticalSection section;
  const _PracticalSectionCard({required this.index, required this.section});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = RuqyahScreen
        ._sectionAccents[index % RuqyahScreen._sectionAccents.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── سربرگ بخش ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
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
                child: Icon(section.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    if (section.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        section.subtitle!,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11.5),
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...section.items.map((item) => _ItemCard(item: item)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// TAB 3: صوتی — رقیه کامل با صدای قاریان (دانلود از سرور + پخش آفلاین)
// ═══════════════════════════════════════════════════════════════

class _AudioTab extends StatefulWidget {
  const _AudioTab();

  @override
  State<_AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<_AudioTab>
    with AutomaticKeepAliveClientMixin {
  final RuqyahAudioService _service = RuqyahAudioService.instance;

  @override
  void initState() {
    super.initState();
    _service.refresh();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    // Leaving the screen stops playback; the app-wide service is never
    // disposed here.
    _service.stop();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const tracks = RuqyahAudioService.tracks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        for (final track in tracks) ...[
          _AudioTrackCard(track: track),
          const SizedBox(height: 14),
        ],
        const InfoBox(
          text:
              'فایل‌های صوتی پس از دانلود به‌صورت همیشگی روی دستگاه ذخیره می‌شوند و برای پخش مجدد به اینترنت نیاز ندارید.',
          icon: Icons.download_for_offline_outlined,
          color: RuqyahScreen._accent,
        ),
      ],
    );
  }
}

/// کارت هر صوت: نام قاری، دکمه پخش/توقف، نوار پیشرفت دانلود،
/// نوار جابجایی (seek) با زمان سپری‌شده/کل و حذف فایل.
class _AudioTrackCard extends StatefulWidget {
  final RuqyahAudioTrack track;
  const _AudioTrackCard({required this.track});

  @override
  State<_AudioTrackCard> createState() => _AudioTrackCardState();
}

class _AudioTrackCardState extends State<_AudioTrackCard> {
  /// While the user drags the slider, live position updates are suppressed
  /// so the thumb does not fight with the drag gesture.
  double? _dragValue;

  RuqyahAudioTrack get track => widget.track;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    final service = RuqyahAudioService.instance;
    final st = service.stateOf(track);
    final isPlaying = st.playing;
    final isDownloading = st.downloading;
    // The seek row stays visible while playing, while the user drags the
    // thumb, and after pausing mid-track (position > 0) so elapsed/total
    // times remain readable.
    final isActive = isPlaying ||
        st.loading ||
        _dragValue != null ||
        st.position > Duration.zero;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? accent.withValues(alpha: 0.6)
              : t.outline,
          width: isPlaying ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── دکمه پخش/توقف ──────────────────────────────────
              GestureDetector(
                onTap: isDownloading ? null : () => service.togglePlay(track),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isPlaying ? 0.18 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accent.withValues(alpha: 0.45), width: 1.2),
                  ),
                  child: st.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: accent),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.reciter,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
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
                                      ? 'ادامه از ${RuqyahAudioService.formatDuration(st.position)}'
                                      : 'رقیه کامل • ${track.approxSizeMb.toStringAsFixed(1)} مگابایت',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: st.error != null
                            ? Colors.red.shade400
                            : t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AudioActionButton(track: track),
            ],
          ),
          // ── نوار جابجایی (seek) — فقط برای فعال ─────────────
          if (isActive && st.hasDuration) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  RuqyahAudioService.formatDuration(_dragValue != null
                      ? Duration(seconds: _dragValue!.round())
                      : st.position),
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
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _dragValue ??
                          (st.hasDuration
                              ? st.position.inMilliseconds
                                  .clamp(0.0, st.duration.inMilliseconds)
                                  .toDouble()
                              : 0),
                      max: st.duration.inMilliseconds.toDouble(),
                      onChanged: st.hasDuration && !isDownloading
                          ? (v) => setState(() => _dragValue = v)
                          : null,
                      onChangeEnd: st.hasDuration && !isDownloading
                          ? (v) {
                              service.seek(Duration(milliseconds: v.round()),
                                  track: track);
                              setState(() => _dragValue = null);
                            }
                          : null,
                    ),
                  ),
                ),
                Text(
                  RuqyahAudioService.formatDuration(st.duration),
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ],
          // ── نوار پیشرفت دانلود ─────────────────────────────
          if (isDownloading && st.progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: st.progress,
                minHeight: 7,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(accent),
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
                    color: accent,
                  ),
                ),
                Text(
                  '${(st.received / (1024 * 1024)).toStringAsFixed(1)} / ${track.approxSizeMb.toStringAsFixed(1)} MB',
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
  final RuqyahAudioTrack track;
  const _AudioActionButton({required this.track});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final service = RuqyahAudioService.instance;
    final st = service.stateOf(track);
    const accent = RuqyahScreen._accent;

    if (st.downloading) {
      // لغو دانلود
      return IconButton(
        tooltip: 'لغو دانلود',
        onPressed: service.cancelDownload,
        icon: Icon(Icons.close_rounded, color: Colors.red.shade300),
      );
    }
    if (st.downloaded) {
      // حذف فایل
      return IconButton(
        tooltip: 'حذف فایل',
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: t.card,
              surfaceTintColor: Colors.transparent,
              title: const Text('حذف فایل صوتی'),
              content: Text('فایل «${track.reciter}» از حافظه دستگاه حذف شود؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      Text('حذف', style: TextStyle(color: Colors.red.shade400)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await service.delete(track);
          }
        },
        icon: Icon(Icons.delete_outline_rounded,
            color: t.textMuted),
      );
    }
    // دانلود دستی (پخش هم خودش دانلود را شروع می‌کند)
    return IconButton(
      tooltip: 'دانلود',
      iconSize: 26,
      onPressed: () => service.download(track),
      icon: const Icon(Icons.download_rounded, color: accent),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = RuqyahScreen._accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16322E) : const Color(0xFFE4F2EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child:
                    const Icon(Icons.healing_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقیه شرعی',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 19),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'درمان با قرآن و سنت — شفای بیماری‌های روحی و جسمی',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                SelectableText(
                  '﴿وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ﴾',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14.5),
                    height: 1.8,
                    color: t.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'الإسراء: 82',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ITEM CARD — یک قطعه محتوا (عنوان / عربی / ترجمه / توضیح / نکات)
// ═══════════════════════════════════════════════════════════════

class _ItemCard extends StatelessWidget {
  final RuqyahItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final children = <Widget>[];

    if (item.title != null) {
      children.add(Text(
        item.title!,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 14),
          fontWeight: FontWeight.w700,
          color: t.textPrimary,
        ),
      ));
    }

    if (item.body != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(Text(
        item.body!,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 13),
          height: 1.7,
          color: t.textSecondary,
        ),
      ));
    }

    if (item.arabic != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(_ArabicBlock(arabic: item.arabic!));
    }

    if (item.translation != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(Text(
        item.translation!,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 12.5),
          height: 1.7,
          fontStyle: FontStyle.italic,
          color: t.textMuted,
        ),
      ));
    }

    if (item.bullets.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(_BulletList(bullets: item.bullets));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkOutline
              : AppTheme.lightOutline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ArabicBlock extends StatelessWidget {
  final String arabic;
  const _ArabicBlock({required this.arabic});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: 'کپی متن',
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => ShareService.copyText(context, arabic),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 15.5),
              height: 1.9,
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> bullets;
  const _BulletList({required this.bullets});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      height: 1.7,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHAPTER CARD — قابل باز و بسته شدن
// ═══════════════════════════════════════════════════════════════

class _ChapterCard extends StatefulWidget {
  final RuqyahChapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  /// All chapters start open so the whole treatise is readable without taps;
  /// the header still toggles to collapse a chapter when desired.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.outline,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Icon(widget.chapter.icon, size: 18, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chapter.title,
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          if (widget.chapter.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.chapter.subtitle!,
                              style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: t.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more,
                          size: 20, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(height: 1, color: t.divider),
                    const SizedBox(height: 12),
                    ...widget.chapter.items
                        .map((item) => _ItemCard(item: item)),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RECOMMENDATIONS — توصیه‌های نهایی شماره‌دار
// ═══════════════════════════════════════════════════════════════

class _RecommendationsCard extends StatelessWidget {
  final List<String> items;
  const _RecommendationsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = RuqyahScreen._accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkOutline
              : AppTheme.lightOutline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        height: 1.7,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH — the book's own index
// ════════════════════════════════════════════════════════════════

List<SectionSearchEntry>? _searchCache;

/// Every verse, hadith and ruling the book carries, tagged with its tab.
///
/// Ruqyah is read by symptom («وسوسه»، «نظر»، «سحر»), and the eight chapters
/// are long enough that a reader gave up scrolling and left. The index is built
/// once — the content is a compile-time constant.
List<SectionSearchEntry> ruqyahSearchEntries() {
  final cached = _searchCache;
  if (cached != null) return cached;

  String text(RuqyahItem i) => [
        if (i.arabic != null) i.arabic!,
        if (i.translation != null) i.translation!,
        if (i.body != null) i.body!,
        ...i.bullets,
      ].join(' ');

  final entries = <SectionSearchEntry>[
    for (final item in RuqyahContent.intro)
      SectionSearchEntry(
        tab: 0,
        tabLabel: 'مطالعه',
        title: item.title ?? 'مقدمه',
        body: text(item),
      ),
    for (final chapter in RuqyahContent.chapters)
      for (final item in chapter.items)
        SectionSearchEntry(
          tab: 0,
          tabLabel: 'مطالعه',
          title: '${chapter.title} · ${item.title ?? 'متن'}',
          body: text(item),
        ),
    for (final item in RuqyahContent.conclusion)
      SectionSearchEntry(
        tab: 0,
        tabLabel: 'مطالعه',
        title: item.title ?? 'خاتمه',
        body: text(item),
      ),
    for (final r in RuqyahContent.finalRecommendations)
      SectionSearchEntry(
          tab: 0, tabLabel: 'مطالعه', title: 'توصیه', body: r),
    for (final section in RuqyahPracticalContent.sections)
      for (final item in section.items)
        SectionSearchEntry(
          tab: 1,
          tabLabel: 'عملی',
          title: '${section.title} · ${item.title ?? 'متن'}',
          body: text(item),
        ),
  ];
  _searchCache = entries;
  return entries;
}
