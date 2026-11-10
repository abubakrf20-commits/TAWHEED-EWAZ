import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tawheeed/core/constants/legal_links.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_flash.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_section_hues.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';
import 'package:tawheeed/features/settings/services/update_checker.dart';
import 'package:tawheeed/features/settings/services/update_installer.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Side padding for kit rows living inside an [AppCard] (which pads zero).
Widget _row(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: child,
    );

/// Public Telegram channel shown on this screen and in the privacy policy.
/// Keep the privacy policy contact section in sync with this value.
const String kTelegramUrl = 'https://t.me/TAWHEED_EWAZ1';

/// The About «تغییرات نسخه‌ها» source — the app owner's OWN release notes,
/// edited directly in this file. It is deliberately NOT a copy of the repo's
/// developer CHANGELOG.md: only what the owner writes here is shown to users
/// (user request «فقط چیزی که خودم وارد میکنم»). Shipped offline in the APK.
const String kChangelogAsset = 'assets/changelog.md';

/// A card of setting rows with hairline dividers between them.
Widget _card(List<Widget> rows) => AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            rows[i],
          ],
        ],
      ),
    );

/// One «امکانات برنامه» feature — its own accent so the grid reads as
/// colourful as the More page (reusing the shared topic hues).
typedef _AboutFeature = ({IconData icon, String label, Color accent});

/// One feature cell — the More Style-2 squircle verbatim (flat accent fill,
/// 1dp hairline border, top-end corner dot, readable glyph), sized by the
/// shared `moreTileSize` so four fit a row at every supported width. No card
/// behind it and no IconTile back-circle: a feature reads exactly like a More
/// tile, minus the tap.
class _AboutFeatureTile extends StatelessWidget {
  const _AboutFeatureTile({required this.feature, required this.tileSize});

  final _AboutFeature feature;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    final s = tileSize;
    final t = TimeThemeKit.of(context).palette;
    final d = MoreDuotone.of(
      feature.accent,
      isDark: Theme.of(context).brightness == Brightness.dark,
      cardSurface: t.card,
    );
    return Column(
      children: [
        Container(
          width: s,
          height: s,
          // The 1dp accent hairline is drawn ON TOP of the clipped children so
          // it stays a crisp edge (the More recipe).
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s * .32),
            border: Border.all(color: d.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(s * .32),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: d.fill)),
                Center(
                  child: Icon(feature.icon, size: s * .48, color: d.glyph),
                ),
                PositionedDirectional(
                  top: s * .12,
                  end: s * .12,
                  child: _FeatureDot(diameter: s * .10, color: d.dot),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: _AboutFeatureLabel(text: feature.label, color: t.textPrimary),
        ),
      ],
    );
  }
}

class _FeatureDot extends StatelessWidget {
  const _FeatureDot({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Two lines at most: the text wraps first and is only scaled down when even
/// two lines do not fit (the More label recipe).
class _AboutFeatureLabel extends StatelessWidget {
  const _AboutFeatureLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: constraints.maxWidth,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact identity header: the real app logo, the version chip and the
/// tagline — flat on the page, with no box around the mark. The logo is the
/// brand (user request: 50 % larger, and the duplicate «توحید» word under it
/// removed — the AppBar title and the footer already carry the name). The gold
/// of the tagline follows the surface (heroGold on dark, goldDark on light),
/// so one recipe stays readable in every theme.
class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logo2.png',
                width: 140,
                height: 140,
                cacheWidth: 280,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
            SettingsValueChip(
                text: version.isEmpty ? 'نسخه' : 'نسخه $version'),
            const SizedBox(height: 6),
            Text(
              'همراه عبادت روزانه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: isDark ? AppPalette.heroGold : AppPalette.goldDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SettingsHighlight<AboutScreen> {
  String _appVersion = '';
  UpdateInfo? _update;
  bool _checkingUpdate = false;

  late final Map<String, GlobalKey> _anchors = {
    'features': GlobalKey(),
    'support': GlobalKey(),
  };

  @override
  Map<String, GlobalKey> get highlightAnchors => _anchors;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindSettingsHighlight();
  }

  @override
  void dispose() {
    disposeSettingsHighlight();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    } catch (e) {
      // The version chip is decoration: a platform-channel failure (or a
      // test binding without PackageInfo) must not break the About page.
      AppLogger.warning('AboutScreen', 'could not read package info: $e');
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final update = await UpdateChecker.instance.check();
    // Read once after the await: [lastCheckFailed] is the verdict of THIS
    // check, and re-reading it inside setState() could race with a newer
    // concurrent check whose flag has already flipped.
    final checkFailed = UpdateChecker.instance.lastCheckFailed;
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      // A failed check keeps the previously advertised update on the tile —
      // a dropped connection must not wipe a banner the user has not acted
      // on. Only a successful "no update" answer clears it.
      if (update != null || !checkFailed) _update = update;
    });
    if (update == null) {
      if (checkFailed) {
        AppSnackBar.error(context,
            'بررسی بروزرسانی ناموفق بود؛ اتصال اینترنت را بررسی کنید.');
      } else {
        AppSnackBar.success(context, 'شما آخرین نسخه را دارید ✓');
      }
      return;
    }
    _showUpdateDialog(context, update);
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('نسخهٔ جدید ${update.versionName}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(dialogContext, 16),
              fontWeight: FontWeight.w700,
              color: TimeThemeKit.of(dialogContext).palette.textPrimary,
            )),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (update.notes.isNotEmpty) Text(update.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('بعداً'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (update.isDirect && update.apkUrl.isNotEmpty) {
                await _downloadAndInstall(update);
                return;
              }
              final url = update.bestUrl;
              if (url.isNotEmpty) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('دریافت نسخهٔ جدید'),
          ),
        ],
      ),
    );
  }

  /// دانلود مستقیم APK داخل برنامه و اجرای نصب‌کنندهٔ اندروید، با نوار پیشرفت.
  Future<void> _downloadAndInstall(UpdateInfo update) async {
    final totalBytes = ValueNotifier<int>(0);
    final receivedBytes = ValueNotifier<int>(0);
    var dialogOpen = true;
    // The progress dialog lives on the navigator, not on this screen: the
    // user can leave the About screen mid-download, disposing this State
    // while the download keeps running. Popping through the navigator
    // captured from the dialog's own context still works then (and is
    // skipped when the app itself went away), while Navigator.of(this
    // .context) would throw a debug-mode exception after unmount.
    NavigatorState? dialogNavigator;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogNavigator = Navigator.of(dialogContext);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('در حال دانلود نسخهٔ جدید…'),
            content: ValueListenableBuilder<int>(
              valueListenable: receivedBytes,
              builder: (context, received, _) {
                final total = totalBytes.value;
                final ratio = total > 0 ? received / total : 0.0;
                final mb = (received / (1024 * 1024)).toStringAsFixed(1);
                final totalMb = total > 0
                    ? ' از ${(total / (1024 * 1024)).toStringAsFixed(1)} مگابایت'
                    : '';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: ratio > 0 ? ratio : null),
                    const SizedBox(height: 12),
                    Text('$mb$totalMb',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: TimeThemeKit.of(context).palette.textMuted,
                        )),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogOpen = false;
                  cancelActiveDownload();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('لغو'),
              ),
            ],
          ),
        );
      },
    );

    final result = await downloadAndInstall(
      update,
      onProgress: (received, total) {
        totalBytes.value = total;
        receivedBytes.value = received;
      },
    );
    // Close the progress dialog even when this screen is gone — the
    // dialog is rooted on the navigator, not on this widget's context.
    if (dialogOpen) dialogNavigator?.pop();
    if (!mounted) return;
    if (result.launched) {
      AppSnackBar.show(context,
          'نسخهٔ جدید دانلود شد؛ اگر صفحهٔ نصب باز نشد، از تنظیمات → برنامه‌ها → توحید → «نصب برنامه‌های ناشناس» را اجازه دهید.');
      return;
    }
    if (result.error == kUpdateCancelledMessage) return; // لغو توسط کاربر
    AppSnackBar.error(
        context, result.error ?? 'دانلود ناموفق بود؛ دوباره تلاش کنید.');
  }

  /// Opens the owner's release notes («تغییرات نسخه‌ها» — [kChangelogAsset]).
  /// The asset is read only on tap, so the About page itself never touches the
  /// bundle while rendering. An empty file (no notes written yet) still opens
  /// the dialog with a polite empty state instead of a blank surface.
  Future<void> _showChangelog() async {
    final String content;
    try {
      content = await rootBundle.loadString(kChangelogAsset);
    } catch (e) {
      AppLogger.warning('AboutScreen', 'changelog asset missing: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'متن تغییرات در دسترس نیست.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تغییرات نسخه‌ها',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(dialogContext, 16),
              fontWeight: FontWeight.w700,
              color: TimeThemeKit.of(dialogContext).palette.textPrimary,
            )),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: content.trim().isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'هنوز متنی ثبت نشده است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(dialogContext, 13),
                        color: TimeThemeKit.of(dialogContext)
                            .palette
                            .textMuted,
                      ),
                    ),
                  )
                : _ChangelogBody(text: content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SettingsAppBar(title: 'درباره توحید'),
      body: ListView(
        // The route-driven highlight (see SettingsHighlight) walks the lazy
        // list down to the anchored row.
        controller: highlightScrollController,
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 24),
        children: [
          _AboutHero(version: _appVersion),
          const SizedBox(height: 12),
          _buildDescriptionCard(context),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'نسخه و تغییرات',
            accent: SettingsSectionHues.on(context, SettingsSectionHues.about),
            margin: const EdgeInsets.only(bottom: 8, right: 4),
          ),
          _card([
            _row(SettingRow(
              icon: Icons.history_rounded,
              title: 'تغییرات نسخه‌ها',
              subtitle: 'سابقهٔ تغییرات و به‌روزرسانی‌های توحید',
              onTap: _showChangelog,
            )),
          ]),
          const SizedBox(height: 16),
          SettingsFlashSection(
            rowKey: 'features',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['features'],
              title: 'امکانات برنامه',
              accent:
                  SettingsSectionHues.on(context, SettingsSectionHues.about),
            ),
          ),
          _buildFeatureGrid(context),
          const SizedBox(height: 16),
          SettingsFlashSection(
            rowKey: 'support',
            flashKey: highlightFlashKey,
            child: SectionHeader(
              key: _anchors['support'],
              title: 'ارتباط با ما',
              accent:
                  SettingsSectionHues.on(context, SettingsSectionHues.about),
            ),
          ),
          _buildSupportList(context),
          const SizedBox(height: 20),
          _buildFooter(context),
        ],
      ),
    );
  }

  /// The one-paragraph «what is this app» card, on the shared card surface
  /// like every other block — the old bare centered paragraph floated without
  /// a container and read as a caption.
  Widget _buildDescriptionCard(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Text(
        'توحید، یک همراه دیجیتال برای مسلمانان است که اوقات نماز، قبله‌نما، اذکار و دعاها، حدیث، تسبیح دیجیتال و قرآن کریم را در یک برنامه یکپارچه و آفلاین در اختیار شما قرار می‌دهد.',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          height: 1.9,
          color: t.textSecondary,
        ),
      ),
    );
  }

  /// The «امکانات برنامه» grid — the SAME Style-2 recipe the More page uses
  /// (`MoreDuotone` + `moreTileSize`): four flat duotone squircles per row,
  /// each derived from its own feature accent, with the top-end corner dot.
  /// No per-cell card and no IconTile back-circle (user request: «ایکون‌ها
  /// دقیقا مثل ایکون‌ها در بخش بیشتر … گرادیان پس زمینه حذف»). Informative
  /// only — a feature has no route of its own, so the tile carries no tap.
  Widget _buildFeatureGrid(BuildContext context) {
    const features = <_AboutFeature>[
      (icon: Icons.mosque, label: 'اوقات شرعی', accent: TopicHues.prayer),
      (
        icon: Icons.nightlight_round,
        label: 'ویجت اوقات شرعی',
        accent: TopicHues.reminders,
      ),
      (icon: Icons.tv, label: 'ویجت تسبیح', accent: TopicHues.zakat),
      (icon: Icons.auto_awesome, label: 'اذکار روزانه', accent: TopicHues.dua),
      (
        icon: Icons.notifications,
        label: 'اعلان اذان',
        accent: TopicHues.audioLibrary,
      ),
      (icon: Icons.menu_book, label: 'قرآن کامل', accent: TopicHues.khatm),
      (
        icon: Icons.library_books,
        label: 'کتب حدیث',
        accent: TopicHues.hadithBooks,
      ),
      (
        icon: Icons.book_online,
        label: 'کتابخانه',
        accent: TopicHues.ketabkhaneh,
      ),
      (
        icon: Icons.compass_calibration,
        label: 'قبله‌نما',
        accent: TopicHues.qibla,
      ),
      (icon: Icons.calendar_month, label: 'مناسبت‌ها', accent: TopicHues.study),
      (icon: Icons.search, label: 'جستجوی هوشمند', accent: TopicHues.tasks),
      (
        icon: Icons.palette_outlined,
        label: 'شخصی‌سازی',
        accent: TopicHues.personalTools,
      ),
      (
        icon: Icons.analytics_outlined,
        label: 'آمار و ارزیابی عبادات',
        accent: TopicHues.worshipChecklist,
      ),
      (
        icon: Icons.rocket_launch,
        label: 'سرعت بالا',
        accent: TopicHues.sciences,
      ),
      (
        icon: Icons.offline_bolt,
        label: 'آفلاین کامل',
        accent: TopicHues.yaqeen,
      ),
      (
        icon: Icons.date_range,
        label: 'تقویم اسلامی',
        accent: TopicHues.moon,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // crossAxisSpacing stays 0: the air around a tile is part of the tile
        // size formula, so the visual gap scales with the screen (More parity).
        final cell = constraints.maxWidth / 4;
        final s = moreTileSize(cell);
        // Cell height = tile + 7 + two label lines — the More formula.
        final cellHeight = s + 7 + AppTheme.scaledFontSize(context, 12.5) * 2.4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            childAspectRatio: cell / cellHeight,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) =>
              _AboutFeatureTile(feature: features[index], tileSize: s),
        );
      },
    );
  }

  Widget _buildSupportList(BuildContext context) {
    return _card([
      _row(SettingRow(
        icon: Icons.share,
        title: 'اشتراک‌گذاری برنامه',
        onTap: shareApp,
      )),
      _row(SettingRow(
        icon: Icons.privacy_tip,
        title: 'حریم خصوصی و دسترسی‌ها',
        onTap: () => _showPrivacy(context),
      )),
      _row(SettingRow(
        icon: Icons.star_rate,
        title: 'امتیاز به توحید',
        onTap: _rateApp,
      )),
      _row(_updateTile(context)),
    ]);
  }

  Widget _updateTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUpdate = _update != null;
    return SettingRow(
      icon: hasUpdate ? Icons.system_update_alt : Icons.update,
      color: hasUpdate
          ? (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess)
          : null,
      title: hasUpdate
          ? 'نسخهٔ جدید ${_update!.versionName} موجود است'
          : 'بررسی بروزرسانی',
      subtitle: _appVersion.isNotEmpty && !hasUpdate
          ? 'نسخهٔ فعلی: $_appVersion'
          : null,
      trailing: _checkingUpdate
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      // A checking row is inert — no chevron while the check runs.
      showChevron: !_checkingUpdate,
      onTap: _checkingUpdate ? null : _checkForUpdate,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        Text(
          'فروغی - اوز',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 16),
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // تلگرام — brand hue.
            Semantics(
              button: true,
              label: 'تلگرام',
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () async {
                  final uri = Uri.parse(kTelegramUrl);
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF229ED9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // گوگل درایو — دانلود مستقیم فایل‌ها; brand hue.
            Semantics(
              button: true,
              label: 'گوگل درایو',
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () async {
                  final uri = Uri.parse(
                      'https://drive.google.com/drive/folders/1YjazUu-A-oMwB7AW7sc7RMSSINUqwXUj?usp=drive_link');
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1FA463),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_to_drive,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '\u00A9 1404 - توحید',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> shareApp() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.islamic.tawheeed');
    // The tile promises a share sheet, so use it; only devices without one
    // fall back to opening the store page.
    try {
      await SharePlus.instance.share(ShareParams(
          text: 'برنامهٔ توحید — اوقات نماز، اذکار صبح و شب، تسبیح و قرآن\n'
              '$uri'));
    } catch (e) {
      AppLogger.warning('AboutScreen', 'share sheet failed, trying store: $e');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        AppSnackBar.error(context, 'اشتراک‌گذاری روی این دستگاه ممکن نیست');
      }
    }
  }

  Future<void> _rateApp() async {
    final market = Uri.parse('market://details?id=com.islamic.tawheeed');
    final web = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.islamic.tawheeed');
    if (await canLaunchUrl(market)) {
      await launchUrl(market, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens a public legal page in the browser. The dialog is a summary; Play
  /// and first-time readers need the hosted text (A-03), so a launch failure
  /// must be visible, not a tap with no reaction.
  Future<void> _openLegal(BuildContext context, String url) async {
    try {
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        AppSnackBar.error(context, 'باز کردن صفحهٔ حقوقی ممکن نشد');
      }
    } catch (e) {
      AppLogger.warning('AboutScreen', 'open legal page failed: $e');
      if (context.mounted) {
        AppSnackBar.error(context, 'باز کردن صفحهٔ حقوقی ممکن نشد');
      }
    }
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حریم خصوصی و دسترسی‌ها'),
        content: const SingleChildScrollView(
          child: Text(
            'بیشتر داده‌های توحید روی همان دستگاه شما می‌مانند:\n\n'
            '• موقعیت مکانی: فقط برای محاسبهٔ اوقات نماز و جهت قبله، روی دستگاه (برای کار آفلاین).\n'
            '• اعلان‌ها: یادآوری نماز، اذکار و آیه/حدیث روز.\n'
            '• تنظیمات، آمار عبادات و بخش «اطلاعات من»: روی دستگاه.\n\n'
            'فقط این قابلیت‌های اختیاری از اینترنت/حساب استفاده می‌کنند:\n'
            '• ارسال پیشنهاد یا انتقاد (Firebase): متن پیام و یک شناسهٔ ناشناس — بدون ایمیل و موقعیت.\n'
            '• پشتیبان‌گیری ابری (اختیاری): نسخهٔ ZIP در فضای ابری برنامه یا Google Drive خودتان.\n'
            '• گزارش خطا (در نسخه‌های منتشرشده): اطلاعات فنیِ خطا، بدون محتوای شخصی شما.\n\n'
            'هیچ تبلیغاتی وجود ندارد و داده‌ای فروخته نمی‌شود.\n\n'
            'راه تماس: کانال تلگرام — $kTelegramUrl',
            textAlign: TextAlign.right,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openLegal(context, LegalLinks.terms);
            },
            child: const Text('شرایط استفاده'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openLegal(context, LegalLinks.privacy);
            },
            child: const Text('نسخهٔ آنلاین'),
          ),
        ],
      ),
    );
  }
}

/// Renders the bundled changelog markdown the way this dialog wants it: a
/// tiny line-based pass over `##`/`###` headings, `-` bullets, `>` blockquote
/// lines and plain paragraphs, with `**bold**` inline emphasis honoured.
/// Purposefully NOT a full markdown renderer — the changelog is a
/// hand-authored document, not user content.
class _ChangelogBody extends StatelessWidget {
  const _ChangelogBody({required this.text});

  final String text;

  /// Version sections newest-first: the owner appends each release at the END
  /// of the asset (oldest → newest), but the dialog must open on the newest
  /// version. Lines are regrouped by their `## ` version heading and the
  /// sections are emitted in reverse; any preamble above the first heading
  /// stays where it is.
  static List<String> newestFirst(List<String> lines) {
    final head = <String>[];
    final sections = <List<String>>[];
    for (final line in lines) {
      if (line.trim().startsWith('## ')) {
        sections.add([line]);
      } else if (sections.isEmpty) {
        head.add(line);
      } else {
        sections.last.add(line);
      }
    }
    return [
      ...head,
      for (var i = sections.length - 1; i >= 0; i--) ...sections[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.scaledFontSize(context, 13),
      height: 1.9,
      color: t.textSecondary,
    );
    final heading = base.copyWith(
      fontSize: AppTheme.scaledFontSize(context, 15),
      fontWeight: FontWeight.w800,
      color: t.textPrimary,
    );
    final subHeading = base.copyWith(
      fontSize: AppTheme.scaledFontSize(context, 14),
      fontWeight: FontWeight.w700,
      color: t.textPrimary,
    );

    final rows = <Widget>[];
    var blankPending = false;
    for (final raw in newestFirst(text.split('\n'))) {
      final line = raw.trim();
      if (line.isEmpty) {
        blankPending = true;
        continue;
      }
      if (blankPending) {
        rows.add(const SizedBox(height: 6));
        blankPending = false;
      }
      if (line.startsWith('## ')) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(line.substring(3), style: heading),
        ));
      } else if (line.startsWith('### ')) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(line.substring(4), style: subHeading),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 6),
              child: Text('• ',
                  style: base.copyWith(
                    color: AppPalette.heroGold,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            Expanded(
              child: _RichLine(line.substring(2), style: base),
            ),
          ],
        ));
      } else if (line.startsWith('> ')) {
        rows.add(_RichLine(
          line.substring(2),
          style: base.copyWith(color: t.textMuted),
        ));
      } else {
        rows.add(_RichLine(line, style: base));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

/// A line of changelog text with `**bold**` emphasis turned into bold spans.
class _RichLine extends StatelessWidget {
  const _RichLine(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!text.contains('**')) {
      return Text(text, style: style);
    }
    final bold = style.copyWith(fontWeight: FontWeight.w800);
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(
                text: parts[i],
                style: i.isOdd ? bold : null,
              ),
        ],
      ),
    );
  }
}
