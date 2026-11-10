import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/tool_identity.dart';

/// ═══════════════════════════════════════════════════════════════
/// New theme core (2026 redesign) — the single source of every color.
///
/// Two theme kinds, both built from [AppPalette]:
/// - [ThemeKind.gold]  — the brand parchment-and-gold look (the app's
///   logo identity); stable across the day.
/// - [ThemeKind.live]  — four time-of-day phases (dawn / day / sunset /
///   night) that follow the shar'i prayer schedule; each phase has a
///   light and a dark palette.
///
/// [AppTheme.applyTheme] copies the active palettes into the legacy
/// static accessors (lightPrimary, darkSurfaceAltTint, …) so the whole
/// app — every `AppTheme.*` / `AppColors.*` call site — follows the
/// selected palette without touching each screen. New-design widgets
/// read [TimeThemeKit.of] instead and get the animated transitions.
/// ═══════════════════════════════════════════════════════════════

enum TimePhase { dawn, day, sunset, night }

extension TimePhaseX on TimePhase {
  String get label => switch (this) {
        TimePhase.dawn => 'سحر',
        TimePhase.day => 'روز',
        TimePhase.sunset => 'غروب',
        TimePhase.night => 'شب',
      };
}

/// User-selectable themes: the brand gold, the automatic live phase, or any
/// phase pinned as a fixed theme.
enum ThemeKind { gold, live, dawn, day, sunset, night }

/// Normalizes the persisted selection. The field was historically the
/// accent-preset id; the redesign replaces presets, and any legacy value
/// ('classic', 'green', …) — i.e. every install that never picked a theme
/// since the redesign — lands on the app default, the blue «شب» theme.
ThemeKind themeKindFromStored(String? stored) => switch (stored) {
      'gold' => ThemeKind.gold,
      'live' => ThemeKind.live,
      'dawn' => ThemeKind.dawn,
      'day' => ThemeKind.day,
      'sunset' => ThemeKind.sunset,
      'night' => ThemeKind.night,
      _ => ThemeKind.night,
    };

/// Fixed identity hues shared by every palette (from the design's
/// colored-pill language). Not phase-dependent: a section keeps its
/// color in every theme.
class SectionHues {
  SectionHues._();

  static const Color home = Color(0xFF1565C0); // bold blue — home tab
  static const Color quran = Color(0xFF1B7A4B); // green — the single green tab (user request: match the calendar tab's green)
  static const Color tasbih = Color(0xFFB8860B); // bold gold — tasbih section + tab
  static const Color calendar = Color(0xFF6D4C41); // coffee brown — taa'at / calendar tab
  static const Color evaluation = Color(0xFFC25A33);
  static const Color more = Color(0xFFD85A30);
}

/// Fixed per-prayer identity hues from the redesign spec (HOME §3) — the
/// muted design family that replaces the legacy Material accents. Phase
/// independent like [SectionHues]: a row's [IconTile] is tinted with the
/// hue and the icon prints at full strength.
class PrayerHues {
  PrayerHues._();

  static const Color fajr = Color(0xFF534AB7);
  static const Color sunrise = Color(0xFFBA7517);
  static const Color dhuhr = Color(0xFFBA7517);
  static const Color asr = Color(0xFFC9822B);
  static const Color maghrib = Color(0xFFD85A30);
  static const Color isha = Color(0xFF534AB7);
}

/// Fixed topic hues for the «بیشتر» feature tiles and their home quick
/// shortcuts — canonical copies of the legacy SectionColors values (spec: a
/// tile keeps its current accent color). Phase independent; a parity test
/// pins each value to SectionColors so the two tables cannot drift.
class TopicHues {
  TopicHues._();

  static const Color qibla = Color(0xFF2E7D32);
  static const Color purification = Color(0xFF1976D2);
  static const Color prayer = Color(0xFF00897B);
  static const Color fasting = Color(0xFF8E24AA);
  static const Color zakat = Color(0xFFF9A825);
  static const Color khatm = Color(0xFF1B5E20);
  static const Color dua = Color(0xFF2E7D32);
  static const Color duas = Color(0xFF00897B);
  static const Color worshipChecklist = Color(0xFFEF6C00);
  static const Color hajjUmrah = Color(0xFF795548);
  static const Color inheritance = Color(0xFF6A1B9A);
  static const Color ruqyah = Color(0xFF00A86B);
  static const Color hadithBooks = Color(0xFF00838F);
  static const Color dorarHadith = Color(0xFFBF360C);
  static const Color ketabkhaneh = Color(0xFF8D6E63);
  static const Color sciences = Color(0xFF3F51B5);
  static const Color study = Color(0xFF0097A7);
  static const Color tasks = Color(0xFF1E88E5);
  static const Color expenses = Color(0xFFE53935);
  static const Color worshipNotes = Color(0xFFF9A825);
  static const Color reminders = Color(0xFFFB8C00);
  static const Color period = Color(0xFFEC407A);
  static const Color calculator = Color(0xFF607D8B);
  static const Color hifz = Color(0xFF00695C);
  static const Color pomodoro = Color(0xFFE53935);
  static const Color dangi = Color(0xFF00ACC1);
  static const Color hadeethEnc = Color(0xFF1565C0);
  static const Color moon = Color(0xFF283593);
  static const Color qafAi = Color(0xFF673AB7);
  static const Color riyad = Color(0xFF558B2F);
  static const Color taraghib = Color(0xFF880E4F);

  /// اخرایی تیره — هویت «معالم السنه النبویه»؛ خانوادهٔ طلایی/نارنجی صفحه،
  /// نه سبزِ ریاض و نه عنابیِ ترغیب (برگهٔ «بیشتر» هر سه را کنار هم دارد).
  static const Color maalim = Color(0xFFB8860B);
  static const Color fatwa = Color(0xFF00695C);
  static const Color yaqeen = Color(0xFF37474F);
  static const Color audioLibrary = Color(0xFFE64A19);
  static const Color anasheed = Color(0xFF00838F);
  static const Color lectures = Color(0xFF7B1FA2);
  static const Color misc = Color(0xFF8D6E63);
  static const Color goals = Color(0xFF00897B);
  static const Color personalTools = Color(0xFF5E35B1);

  /// ابزارهای شخصی — هر کدام هویت خودش را دارد تا در گریدِ «ابزارها و پیشرفت»
  /// از بقیه جدا دیده شوند. این چهار مقدار قبلاً با رنگِ خودِ صفحهٔ ابزار
  /// یکی نبودند (کاشی قهوه‌ای، صفحه رز؛ کاشی زرشکی، صفحه کهربایی)؛ حالا هر دو
  /// از یک منبع می‌خوانند: `core/theme/tool_identity.dart`.
  static const Color relatives = ToolIdentity.relatives;
  static const Color kaffara = ToolIdentity.kaffara;
  static const Color savings = ToolIdentity.savings;

  /// «خودرو» و «خانه» — دو ابزار مرحلهٔ ۱ که تا امروز هیچ کاشی‌ای نداشتند.
  static const Color car = ToolIdentity.car;
  static const Color homeCare = ToolIdentity.home;
  /// قهوه‌ای گرم — هویت گروه «برنامه» در «بیشتر» (تنظیمات، دربارهٔ برنامه).
  /// همان secondary پالت روز است؛ بازتابی در SectionColors ندارد چون
  /// صفحات تنظیمات/درباره رنگ اکسنتِ تم را می‌گیرند، نه هویت بخش.
  static const Color app = Color(0xFF6D5A4A);

  static const Color personalInfo = Color(0xFF37474F);
  static const Color personalProfile = Color(0xFF5C6BC0);
  static const Color personalDocs = Color(0xFF26A69A);
  static const Color personalCredentials = Color(0xFFEF6C00);
  static const Color personalAssets = Color(0xFF8D6E63);
  static const Color personalInsurance = Color(0xFF00897B);
  static const Color personalEmergency = Color(0xFFE53935);
  static const Color personalExpiry = Color(0xFFF9A825);
  /// نارنجی گرم — «دفتر عادت کودک».
  static const Color kidsHabits = Color(0xFFE58A2B);
  /// سبز دریاچه‌ای — «دفتر مربی قرآن».
  static const Color teacherLedger = Color(0xFF7C4DFF);
  /// فیروزه‌ای تیره — «حساب مغازه».
  static const Color shopLedger = Color(0xFF0E7C86);
}

/// One complete color palette for the app.
@immutable
class AppPalette {
  const AppPalette({
    required this.pageBg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.card,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.outline,
    required this.divider,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.tertiary,
    required this.tertiarySoft,
    required this.accent,
    required this.heroTop,
    required this.heroMid,
    required this.heroBottom,
    required this.heroInk,
  });

  // Surfaces (deepest → lightest in light mode, reversed in dark)
  final Color pageBg; // scaffold background
  final Color surface; // nav, sheets, base
  final Color surfaceAlt; // inputs, chips
  final Color surfaceMuted; // subtle fills
  final Color card; // default card
  final Color elevated; // dialogs, bottom sheets

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Lines
  final Color outline;
  final Color divider;

  // Accents
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color secondary;
  final Color secondarySoft;
  final Color tertiary;
  final Color tertiarySoft;

  /// The accent that *identifies this theme*, and the only one chrome is
  /// allowed to read: a section-header bar, a slider's active track, a
  /// selected segment, a settings tile. The brand palette answers with its
  /// own gold; every phase palette answers with its phase hue, so selecting
  /// «شب» cannot leave a brown mark on a blue page.
  ///
  /// Deliberately NOT `tertiary`: that field is the app's sacred gold and is
  /// gold in every palette, which is why ~60 call sites had to write the
  /// `isDark ? t.primary : t.tertiary` ternary by hand. One named field per
  /// palette removes that whole class of drift.
  final Color accent;

  // Hero gradient (the design's signature card)
  final Color heroTop;
  final Color heroMid;
  final Color heroBottom;
  final Color heroInk; // text color on the hero gradient

  /// The dark chrome every surface that paints *this* palette's hero field
  /// reads: the home hero card, the reader header band, the player pads and a
  /// selected pill. One accessor, so no surface keeps the retired fixed brown
  /// and every one of them turns with the selected theme / time-of-day phase.
  List<Color> get heroGradient => <Color>[heroTop, heroMid, heroBottom];

  /// Soft gold used for accents drawn ON the hero gradient (stars, dots,
  /// countdown). Shared by every palette — gold is the app's sacred accent.
  static const Color heroGold = Color(0xFFF3D58B);
  static const Color heroGoldDeep = Color(0xFFE0B25C);

  /// Deep gold — for gold text/marks on LIGHT surfaces (the spec's contrast
  /// rule: heroGold is only for dark hero surfaces).
  static const Color goldDark = Color(0xFFB8862B);
  static const Color cream = Color(0xFFFFF6E0);

  /// The app's done/completed green, shared by every palette. Set to the same
  /// green the Calendar tab wears (user request 2026-11-09) so «done» reads
  /// green everywhere — tasbih after-goal, checkmarks, excellent ratings,
  /// fasting marks, the khatm indicator.
  static const Color emerald = Color(0xFF1B7A4B);

  AppPalette copyWith({
    Color? pageBg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceMuted,
    Color? card,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? outline,
    Color? divider,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? secondary,
    Color? secondarySoft,
    Color? tertiary,
    Color? tertiarySoft,
    Color? accent,
    Color? heroTop,
    Color? heroMid,
    Color? heroBottom,
    Color? heroInk,
  }) =>
      AppPalette(
        pageBg: pageBg ?? this.pageBg,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        card: card ?? this.card,
        elevated: elevated ?? this.elevated,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        outline: outline ?? this.outline,
        divider: divider ?? this.divider,
        primary: primary ?? this.primary,
        primaryStrong: primaryStrong ?? this.primaryStrong,
        primarySoft: primarySoft ?? this.primarySoft,
        secondary: secondary ?? this.secondary,
        secondarySoft: secondarySoft ?? this.secondarySoft,
        tertiary: tertiary ?? this.tertiary,
        tertiarySoft: tertiarySoft ?? this.tertiarySoft,
        accent: accent ?? this.accent,
        heroTop: heroTop ?? this.heroTop,
        heroMid: heroMid ?? this.heroMid,
        heroBottom: heroBottom ?? this.heroBottom,
        heroInk: heroInk ?? this.heroInk,
      );
}

/// Field-wise palette interpolation for the MaterialApp theme animation.
/// Every channel blends through a null-safe fallback (the gate forbids
/// null-asserted color blends); the fallback is unreachable with non-null
/// arguments anyway.
AppPalette lerpPalette(AppPalette a, AppPalette b, double t) {
  Color m(Color x, Color y) => Color.lerp(x, y, t) ?? x;
  return AppPalette(
    pageBg: m(a.pageBg, b.pageBg),
    surface: m(a.surface, b.surface),
    surfaceAlt: m(a.surfaceAlt, b.surfaceAlt),
    surfaceMuted: m(a.surfaceMuted, b.surfaceMuted),
    card: m(a.card, b.card),
    elevated: m(a.elevated, b.elevated),
    textPrimary: m(a.textPrimary, b.textPrimary),
    textSecondary: m(a.textSecondary, b.textSecondary),
    textMuted: m(a.textMuted, b.textMuted),
    outline: m(a.outline, b.outline),
    divider: m(a.divider, b.divider),
    primary: m(a.primary, b.primary),
    primaryStrong: m(a.primaryStrong, b.primaryStrong),
    primarySoft: m(a.primarySoft, b.primarySoft),
    secondary: m(a.secondary, b.secondary),
    secondarySoft: m(a.secondarySoft, b.secondarySoft),
    tertiary: m(a.tertiary, b.tertiary),
    tertiarySoft: m(a.tertiarySoft, b.tertiarySoft),
    accent: m(a.accent, b.accent),
    heroTop: m(a.heroTop, b.heroTop),
    heroMid: m(a.heroMid, b.heroMid),
    heroBottom: m(a.heroBottom, b.heroBottom),
    heroInk: m(a.heroInk, b.heroInk),
  );
}

class AppPalettes {
  AppPalettes._();

  // ─────────────────────────────────────────────────────────────
  // GOLD — the brand theme (پیش‌فرض و نماد برنامه)
  // Refined parchment-and-gold carried over from the previous
  // classic palette, expressed in the new token shape.
  // ─────────────────────────────────────────────────────────────
  static const AppPalette goldLight = AppPalette(
    pageBg: Color(0xFFFDF5EB),
    surface: Color(0xFFFFFBF5),
    surfaceAlt: Color(0xFFF5F0E8),
    surfaceMuted: Color(0xFFF0EBE2),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFBF5),
    textPrimary: Color(0xFF3E2723),
    textSecondary: Color(0xFF6B5E52),
    textMuted: Color(0xFF8C7E72),
    outline: Color(0xFFE0D7CD),
    divider: Color(0xFFECE5DC),
    primary: Color(0xFF4A3426),
    primaryStrong: Color(0xFF3B281B),
    primarySoft: Color(0xFFEDE7E0),
    secondary: Color(0xFF6D5A4A),
    secondarySoft: Color(0xFFEFEAE4),
    tertiary: Color(0xFFC48A27),
    tertiarySoft: Color(0xFFF5E6CC),
    accent: Color(0xFFC48A27),
    heroTop: Color(0xFF5C4433),
    heroMid: Color(0xFF3E2C20),
    heroBottom: Color(0xFF241812),
    heroInk: Color(0xFFFFF6E0),
  );

  static const AppPalette goldDark = AppPalette(
    pageBg: Color(0xFF1A1410),
    surface: Color(0xFF221C14),
    surfaceAlt: Color(0xFF2A231A),
    surfaceMuted: Color(0xFF342C20),
    card: Color(0xFF262018),
    elevated: Color(0xFF3A3220),
    textPrimary: Color(0xFFF2EDE6),
    textSecondary: Color(0xFFD4CEC4),
    textMuted: Color(0xFFB8B0A8),
    outline: Color(0xFF3D352E),
    divider: Color(0xFF2D241E),
    primary: Color(0xFFD4B96A),
    primaryStrong: Color(0xFFE8D08A),
    primarySoft: Color(0xFF3A2E1C),
    secondary: Color(0xFFA89888),
    secondarySoft: Color(0xFF1E1814),
    tertiary: Color(0xFFE0C080),
    tertiarySoft: Color(0xFF3D3220),
    accent: Color(0xFFE0C080),
    heroTop: Color(0xFF4A3A24),
    heroMid: Color(0xFF2E2418),
    heroBottom: Color(0xFF1A130C),
    heroInk: Color(0xFFF2EDE6),
  );

  // ─────────────────────────────────────────────────────────────
  // DAWN (سحر) — violet
  // ─────────────────────────────────────────────────────────────
  static const AppPalette dawnLight = AppPalette(
    pageBg: Color(0xFFF4F0FB),
    surface: Color(0xFFFAF8FE),
    surfaceAlt: Color(0xFFF0EDF9),
    surfaceMuted: Color(0xFFE9E5F5),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFAF8FE),
    textPrimary: Color(0xFF2E2A4A),
    textSecondary: Color(0xFF4E4974),
    textMuted: Color(0xFF6A6590),
    outline: Color(0xFFDDD6F3),
    divider: Color(0xFFE8E4F7),
    primary: Color(0xFF5B4FA8),
    primaryStrong: Color(0xFF443A85),
    primarySoft: Color(0xFFE7E3F6),
    secondary: Color(0xFF6A6590),
    secondarySoft: Color(0xFFEEEDF7),
    tertiary: Color(0xFFB8862B),
    tertiarySoft: Color(0xFFF5EEDB),
    accent: Color(0xFF5B4FA8),
    heroTop: Color(0xFF8A7FD6),
    heroMid: Color(0xFF5B4FA8),
    heroBottom: Color(0xFF2E2A5E),
    heroInk: Color(0xFFFFF6E0),
  );

  static const AppPalette dawnDark = AppPalette(
    pageBg: Color(0xFF171524),
    surface: Color(0xFF1F1C30),
    surfaceAlt: Color(0xFF272339),
    surfaceMuted: Color(0xFF322D45),
    card: Color(0xFF241F35),
    elevated: Color(0xFF2E2942),
    textPrimary: Color(0xFFF0EDF8),
    textSecondary: Color(0xFFC9C4DC),
    textMuted: Color(0xFF9A94B5),
    outline: Color(0xFF3A3452),
    divider: Color(0xFF262138),
    primary: Color(0xFF9C91E8),
    primaryStrong: Color(0xFFB5ACF0),
    primarySoft: Color(0xFF2C2745),
    secondary: Color(0xFFA79FC8),
    secondarySoft: Color(0xFF232032),
    tertiary: Color(0xFFE0B25C),
    tertiarySoft: Color(0xFF3A2F1C),
    accent: Color(0xFF9C91E8),
    heroTop: Color(0xFF6F63C2),
    heroMid: Color(0xFF4A3F8F),
    heroBottom: Color(0xFF251F4D),
    heroInk: Color(0xFFFFF6E0),
  );

  // ─────────────────────────────────────────────────────────────
  // DAY (روز) — emerald
  // ─────────────────────────────────────────────────────────────
  static const AppPalette dayLight = AppPalette(
    pageBg: Color(0xFFFFF8E8),
    surface: Color(0xFFFFFDF6),
    surfaceAlt: Color(0xFFF7F1E2),
    surfaceMuted: Color(0xFFF1E9D6),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFDF6),
    textPrimary: Color(0xFF3B2418),
    textSecondary: Color(0xFF5E4636),
    textMuted: Color(0xFF8A7565),
    outline: Color(0xFFF0E2BF),
    divider: Color(0xFFF3EAD2),
    primary: Color(0xFF1F8E75),
    primaryStrong: Color(0xFF156B57),
    primarySoft: Color(0xFFDDF0E9),
    secondary: Color(0xFF8A7565),
    secondarySoft: Color(0xFFF5EFE3),
    tertiary: Color(0xFFB8862B),
    tertiarySoft: Color(0xFFF5EEDB),
    accent: Color(0xFF1F8E75),
    heroTop: Color(0xFF2FAE90),
    heroMid: Color(0xFF1F8E75),
    heroBottom: Color(0xFF0B4F3F),
    heroInk: Color(0xFFFFF6E0),
  );

  static const AppPalette dayDark = AppPalette(
    pageBg: Color(0xFF0F1A16),
    surface: Color(0xFF14211C),
    surfaceAlt: Color(0xFF1B2A24),
    surfaceMuted: Color(0xFF24362F),
    card: Color(0xFF182620),
    elevated: Color(0xFF223129),
    textPrimary: Color(0xFFEDF3EF),
    textSecondary: Color(0xFFC2CFC8),
    textMuted: Color(0xFF8FA39A),
    outline: Color(0xFF2E403A),
    divider: Color(0xFF1C2A24),
    primary: Color(0xFF5BC4A8),
    primaryStrong: Color(0xFF7BD6BE),
    primarySoft: Color(0xFF1B332C),
    secondary: Color(0xFF9BB0A6),
    secondarySoft: Color(0xFF1A2620),
    tertiary: Color(0xFFE0B25C),
    tertiarySoft: Color(0xFF3A2F1C),
    accent: Color(0xFF5BC4A8),
    heroTop: Color(0xFF23957A),
    heroMid: Color(0xFF177561),
    heroBottom: Color(0xFF0A3D31),
    heroInk: Color(0xFFFFF6E0),
  );

  // ─────────────────────────────────────────────────────────────
  // SUNSET (غروب) — amber / rust
  // ─────────────────────────────────────────────────────────────
  static const AppPalette sunsetLight = AppPalette(
    pageBg: Color(0xFFFDEDE6),
    surface: Color(0xFFFFF8F4),
    surfaceAlt: Color(0xFFF8E9E1),
    surfaceMuted: Color(0xFFF2DED4),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFF8F4),
    textPrimary: Color(0xFF4A2418),
    textSecondary: Color(0xFF6B3C2C),
    textMuted: Color(0xFF8A5A4A),
    outline: Color(0xFFF5CDBB),
    divider: Color(0xFFF7DCCF),
    primary: Color(0xFFC25A33),
    primaryStrong: Color(0xFF9A4225),
    primarySoft: Color(0xFFF7DFD4),
    secondary: Color(0xFF8A5A4A),
    secondarySoft: Color(0xFFF6EDE8),
    tertiary: Color(0xFFB8862B),
    tertiarySoft: Color(0xFFF5EEDB),
    accent: Color(0xFFC25A33),
    heroTop: Color(0xFFA34A28),
    heroMid: Color(0xFF7E3A1E),
    heroBottom: Color(0xFF472013),
    heroInk: Color(0xFFFFF6E0),
  );

  static const AppPalette sunsetDark = AppPalette(
    pageBg: Color(0xFF1C120E),
    surface: Color(0xFF241813),
    surfaceAlt: Color(0xFF2D1F18),
    surfaceMuted: Color(0xFF39281F),
    card: Color(0xFF281B14),
    elevated: Color(0xFF33231A),
    textPrimary: Color(0xFFF5EEE9),
    textSecondary: Color(0xFFD9CBC2),
    textMuted: Color(0xFFAA968B),
    outline: Color(0xFF443129),
    divider: Color(0xFF2A1D16),
    primary: Color(0xFFE8965C),
    primaryStrong: Color(0xFFF0AC79),
    primarySoft: Color(0xFF3A2417),
    secondary: Color(0xFFC0A496),
    secondarySoft: Color(0xFF261B14),
    tertiary: Color(0xFFE0B25C),
    tertiarySoft: Color(0xFF3A2F1C),
    accent: Color(0xFFE8965C),
    heroTop: Color(0xFFC96F3D),
    heroMid: Color(0xFF9C4E2B),
    heroBottom: Color(0xFF4A2115),
    heroInk: Color(0xFFFFF6E0),
  );

  // ─────────────────────────────────────────────────────────────
  // NIGHT (شب) — deep blue
  // ─────────────────────────────────────────────────────────────
  static const AppPalette nightLight = AppPalette(
    pageBg: Color(0xFFEAF0F8),
    surface: Color(0xFFF7FAFD),
    surfaceAlt: Color(0xFFE7EEF7),
    surfaceMuted: Color(0xFFDEE8F4),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFF7FAFD),
    textPrimary: Color(0xFF1B2E52),
    textSecondary: Color(0xFF3B5077),
    textMuted: Color(0xFF5C6E91),
    outline: Color(0xFFC9D6EA),
    divider: Color(0xFFDCE5F2),
    primary: Color(0xFF2B4880),
    primaryStrong: Color(0xFF1D335C),
    primarySoft: Color(0xFFDCE6F4),
    secondary: Color(0xFF5C6E91),
    secondarySoft: Color(0xFFEAEEF6),
    tertiary: Color(0xFFB8862B),
    tertiarySoft: Color(0xFFF5EEDB),
    accent: Color(0xFF2B4880),
    heroTop: Color(0xFF3F5F9C),
    heroMid: Color(0xFF2B4880),
    heroBottom: Color(0xFF16294F),
    heroInk: Color(0xFFFFF6E0),
  );

  static const AppPalette nightDark = AppPalette(
    pageBg: Color(0xFF0E1420),
    surface: Color(0xFF141C2B),
    surfaceAlt: Color(0xFF1B2536),
    surfaceMuted: Color(0xFF243044),
    card: Color(0xFF18212F),
    elevated: Color(0xFF212D40),
    textPrimary: Color(0xFFEDF2F8),
    textSecondary: Color(0xFFC6D2E0),
    textMuted: Color(0xFF92A2B8),
    outline: Color(0xFF2E3A4E),
    divider: Color(0xFF1B2432),
    primary: Color(0xFF7C9BD6),
    primaryStrong: Color(0xFF9BB6E4),
    primarySoft: Color(0xFF1E2A40),
    secondary: Color(0xFF9FAEC4),
    secondarySoft: Color(0xFF192230),
    tertiary: Color(0xFFE0B25C),
    tertiarySoft: Color(0xFF3A2F1C),
    accent: Color(0xFF7C9BD6),
    heroTop: Color(0xFF3F5F9C),
    heroMid: Color(0xFF2B4880),
    heroBottom: Color(0xFF16294F),
    heroInk: Color(0xFFFFF6E0),
  );

  /// The two colours the theme-kind chooser paints on each preview chip: the
  /// accent and the deepest hero stop of that kind's LIGHT palette. Deriving
  /// them here keeps the chooser and the theme from ever disagreeing — the
  /// previous hand-copied literals in the settings page had already drifted.
  ///
  /// `sunset` keeps the design's vivid amber pair: that palette's own hero
  /// stops (`A34A28`/`472013`) read as a flat dark rust at chip size, so the
  /// chooser deliberately shows the brighter variant. Everything else is exact.
  static (Color, Color) previewSwatches(ThemeKind kind) => switch (kind) {
        ThemeKind.gold => (goldLight.tertiary, goldLight.primary),
        ThemeKind.dawn => (dawnLight.heroTop, dawnLight.heroBottom),
        ThemeKind.day => (dayLight.heroTop, dayLight.heroBottom),
        ThemeKind.sunset => (const Color(0xFFE58A4F), const Color(0xFF6E2A1E)),
        ThemeKind.night => (nightLight.heroTop, nightLight.heroBottom),
        ThemeKind.live => (dawnLight.heroTop, dayLight.heroTop),
      };

  static AppPalette of({
    required ThemeKind kind,
    required TimePhase phase,
    required bool dark,
  }) {
    // Fixed phase selections ignore the current time; only «live» follows it.
    final TimePhase p;
    switch (kind) {
      case ThemeKind.gold:
        return dark ? goldDark : goldLight;
      case ThemeKind.dawn:
        p = TimePhase.dawn;
      case ThemeKind.day:
        p = TimePhase.day;
      case ThemeKind.sunset:
        p = TimePhase.sunset;
      case ThemeKind.night:
        p = TimePhase.night;
      case ThemeKind.live:
        p = phase;
    }
    return switch (p) {
      TimePhase.dawn => dark ? dawnDark : dawnLight,
      TimePhase.day => dark ? dayDark : dayLight,
      TimePhase.sunset => dark ? sunsetDark : sunsetLight,
      TimePhase.night => dark ? nightDark : nightLight,
    };
  }
}

/// ThemeExtension carrying the active palette so redesign widgets can read
/// it with [TimeThemeKit.of] and inherit MaterialApp's animated transitions
/// when the phase (or theme) changes.
class TimeThemeKit extends ThemeExtension<TimeThemeKit> {
  const TimeThemeKit(this.palette);

  final AppPalette palette;

  static TimeThemeKit of(BuildContext context) =>
      Theme.of(context).extension<TimeThemeKit>() ??
      const TimeThemeKit(AppPalettes.goldLight);

  @override
  TimeThemeKit copyWith() => this;

  @override
  TimeThemeKit lerp(ThemeExtension<TimeThemeKit>? other, double t) {
    if (other is! TimeThemeKit) return this;
    return TimeThemeKit(lerpPalette(palette, other.palette, t));
  }
}
