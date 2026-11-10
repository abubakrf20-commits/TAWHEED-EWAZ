import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

/// ═══════════════════════════════════════════════════════════════
/// The «بیشتر» item registry — the SINGLE source of truth for the
/// redesigned More page: the grid, the search field and the tests all read
/// this list, so an entry can never exist in one and be missing in another.
///
/// Rules encoded here (and pinned by `more_registry_test.dart`):
///  • every tile keeps the accent color the page already used (TopicHues —
///    phase-independent, so a section is recognizable in every theme);
///  • every item belongs to exactly one group; empty groups are hidden by
///    the page, never by the registry;
///  • navigation is described by [MoreItem.kind] + [MoreItem.destination]
///    only — there is no `route: ''` sentinel that could push an empty path.
///
/// «مصحف توحید» and «آمارهٔ پیشرفت» are deliberately absent: both sections
/// were removed from the app by user decision, and
/// `more_screen_no_duplicate_stats_test.dart` fails if they reappear.
/// ═══════════════════════════════════════════════════════════════

/// The page's sections, in display order. [MoreGroup.app] is rendered as a
/// SettingRow list («تنظیمات و بیشتر»), the others as duotone tile grids.
///
/// «قرآن و ادعیه» is not a section any more: by user decision its items read
/// inside «عبادات و مناسک», together with ماه و منازل and میراث, so the whole
/// act-of-worship family opens from one grid.
enum MoreGroup {
  worship('عبادات و مناسک'),
  hadith('حدیث و مطالعه'),
  audio('کتابخانه صوتی'),
  tools('ابزارها و پیشرفت'),
  app('تنظیمات و بیشتر');

  const MoreGroup(this.title);
  final String title;
}

/// What tapping an item does. Keep in sync with the page's `_open`.
enum MoreKind {
  /// In-app route ([MoreItem.destination] = the path).
  route,

  /// In-app route gated behind a session password
  /// ([MoreItem.lockCode] = the unlock code).
  lockedRoute,

  /// External URL opened in the app's in-app browser.
  web,

  /// The audio library focused on one subcategory
  /// ([MoreItem.destination] = the category id).
  audioCategory,
}

@immutable
class MoreItem {
  const MoreItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.group,
    required this.kind,
    required this.destination,
    this.lockCode,
    this.subtitle,
    this.iconScale = 1.0,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final IconData icon;

  /// The topic hue every duotone tile color is derived from.
  final Color accent;
  final MoreGroup group;
  final MoreKind kind;

  /// A route path, an https URL or an audio category id, per [kind].
  final String destination;

  /// Password for [MoreKind.lockedRoute]; null otherwise.
  final String? lockCode;

  /// Only shown by the SettingRow list of [MoreGroup.app].
  final String? subtitle;

  /// Optical size multiplier for the tile glyph (0.9–1.1), so silhouettes of
  /// different density (mosque vs droplet vs compass) read equally big.
  /// Only tiles use it; list rows draw their own fixed mini tile.
  final double iconScale;

  /// Extra search terms (synonyms, Arabic spellings, Latin transliterations).
  final List<String> keywords;

  bool get isLocked => kind == MoreKind.lockedRoute;
}

/// The locked sections are still under construction.
///
/// Audit U6-01: the legacy hardcoded `'2323'` was extractable from the APK
/// with `strings`, so the «قفل» read as fake security. Now the code comes
/// from a `--dart-define=YAQEEN_LOCK_CODE=…` (build-time, not shipped as a
/// literal). Debug/test builds keep the legacy fallback so local flows and
/// the More-screen tests keep working; a release build without the define
/// yields an empty code — every entry is rejected and the section honestly
/// stays locked until its feature ships.
const String _yaqeenLockDefine = String.fromEnvironment('YAQEEN_LOCK_CODE');
const String _yaqeenLockDebugFallback = '2323';
final String yaqeenLockCode = _yaqeenLockDefine.isNotEmpty
    ? _yaqeenLockDefine
    : (kReleaseMode ? '' : _yaqeenLockDebugFallback);

// Non-const since U6-01: [yaqeenLockCode] is build-define driven, so the
// registry is now constructed at runtime (search indexes it once anyway).
final List<MoreItem> kMoreItems = [
  // ── عبادات و مناسک ──────────────────────────────────────────────
  // Order is the user's: قبله، then ماه و منازل، then طهارت، then the rest of
  // the rites, then the Qur'an/dua family that merged in here, then میراث.
  MoreItem(
    id: 'qibla',
    title: 'قبله‌نما',
    icon: Icons.explore_rounded,
    accent: TopicHues.qibla,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.qibla,
    keywords: ['کعبه', 'جهت', 'قِبلة', 'qibla'],
  ),
  MoreItem(
    id: 'moon',
    title: 'ماه و منازل',
    icon: Icons.nights_stay_rounded,
    accent: TopicHues.moon,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.moon,
    keywords: ['هلال', 'منازل', 'تقویم قمری', 'moon'],
  ),
  MoreItem(
    id: 'purification',
    title: 'وضو و طهارت',
    icon: Icons.water_drop_rounded,
    accent: TopicHues.purification,
    iconScale: 1.06,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.purification,
    keywords: ['تطهر', 'غسل', 'تیمم', 'وضو', 'taharat'],
  ),
  MoreItem(
    id: 'prayer',
    title: 'نماز',
    icon: Icons.mosque_rounded,
    accent: TopicHues.prayer,
    iconScale: 0.94,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.prayer,
    keywords: ['صلوه', 'اذان', 'namaz', 'salah'],
  ),
  MoreItem(
    id: 'fasting',
    title: 'روزه',
    icon: Icons.no_meals_rounded,
    accent: TopicHues.fasting,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.fasting,
    keywords: ['صوم', 'سحری', 'افطار', 'رمضان', 'rowzeh'],
  ),
  MoreItem(
    id: 'zakat',
    title: 'زکات',
    icon: Icons.account_balance_rounded,
    accent: TopicHues.zakat,
    iconScale: 0.95,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.zakat,
    keywords: ['زکات', 'نصاب', 'فطریه', 'zakat'],
  ),
  MoreItem(
    id: 'hajj-umrah',
    title: 'حج و عمره',
    icon: Icons.travel_explore_rounded,
    accent: TopicHues.hajjUmrah,
    iconScale: 0.94,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.hajjUmrah,
    keywords: ['مناسک', 'احرام', 'طواف', 'سعی', 'hajj'],
  ),
  MoreItem(
    id: 'inheritance',
    title: 'میراث',
    icon: Icons.account_tree_rounded,
    accent: TopicHues.inheritance,
    iconScale: 0.94,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.inheritance,
    keywords: ['فرائض', 'سهام', 'میرات', 'faraid'],
  ),
  MoreItem(
    id: 'khatm',
    title: 'ختم قرآن',
    icon: Icons.menu_book_rounded,
    accent: TopicHues.khatm,
    iconScale: 0.95,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.khatm,
    keywords: ['تلاوت روزانه', 'جزء', 'ختم', 'khatm'],
  ),
  MoreItem(
    id: 'hifz',
    title: 'حفظ قرآن',
    icon: Icons.workspace_premium_rounded,
    accent: TopicHues.hifz,
    iconScale: 0.98,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.hifz,
    keywords: ['حفظ', 'مراجعه', 'سوره', 'hifz'],
  ),
  MoreItem(
    id: 'mushaf-hafiz',
    title: 'مصحف حافظ',
    icon: Icons.psychology_rounded,
    accent: TopicHues.hifz,
    iconScale: 0.98,
    group: MoreGroup.worship,
    kind: MoreKind.web,
    destination: 'https://muhaffidh.app/',
    keywords: ['تمرین حفظ', 'مصحف', 'hafiz'],
  ),
  MoreItem(
    id: 'dua',
    title: 'دعا',
    icon: Icons.bookmark_rounded,
    accent: TopicHues.dua,
    iconScale: 1.06,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.dua,
    keywords: ['مناجات', 'ذکر', 'دعاهای قرآنی', 'dua'],
  ),
  MoreItem(
    id: 'duas',
    title: 'حصن المسلم',
    icon: Icons.umbrella_rounded,
    accent: TopicHues.duas,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.duas,
    keywords: ['اذکار', 'حصن', 'صبح و شب', 'hisn'],
  ),
  MoreItem(
    id: 'ruqyah',
    title: 'رقیه شرعی',
    icon: Icons.healing_rounded,
    accent: TopicHues.ruqyah,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.ruqyah,
    keywords: ['شفاء', 'چشم‌زخم', 'اذکار', 'ruqyah'],
  ),
  MoreItem(
    id: 'silat-al-rahim',
    title: 'صله رحم',
    icon: Icons.family_restroom_rounded,
    accent: TopicHues.relatives,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.silatAlRahim,
    keywords: ['صله رحم', 'اقوام', 'خویشاوند', 'دیدار', 'هدیه', 'family'],
  ),
  MoreItem(
    id: 'quran-teacher',
    title: 'دفتر مربی قرآن',
    icon: Icons.menu_book_rounded,
    accent: TopicHues.teacherLedger,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.quranTeacherHome,
    keywords: ['مربی', 'قرآن', 'شاگرد', 'حضور', 'تلاوت', 'teacher'],
  ),
  // The habit ledger counts the day's prayers and good deeds, so it is a
  // worship tracker, not a personal-data tool (user's move, 2026-11-09). It
  // still opens like any other route; its sensitive actions keep their own
  // ParentLock inside.
  MoreItem(
    id: 'kids-habits',
    title: 'دفتر عادت کودک',
    icon: Icons.child_care_rounded,
    accent: TopicHues.kidsHabits,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.kidsHome,
    keywords: ['کودک', 'عادت', 'ستاره', 'جایزه', 'نماز کودک', 'kids'],
  ),
  // ── حدیث و مطالعه ───────────────────────────────────────────────
  MoreItem(
    id: 'riyad',
    title: 'ریاض الصالحین',
    icon: Icons.local_florist_rounded,
    accent: TopicHues.riyad,
    iconScale: 1.04,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.riyad,
    keywords: ['باغ صالحان', 'نووی', 'ریاض'],
  ),
  MoreItem(
    id: 'taraghib',
    title: 'صحیح الترغیب',
    icon: Icons.menu_book_rounded,
    accent: TopicHues.taraghib,
    iconScale: 1.04,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.taraghib,
    keywords: ['ترغیب', 'ترهیب', 'صحیح ترغیب'],
  ),
  MoreItem(
    id: 'maalim',
    title: 'معالم السنه النبویه',
    icon: Icons.local_library_rounded,
    accent: TopicHues.maalim,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.maalim,
    keywords: ['معالم', 'سنه نبویه', 'الشامي', 'شاکر الذهبي', '14 کتاب', 'maalim'],
  ),
  MoreItem(
    id: 'hadith-books',
    title: 'کتب حدیث',
    icon: Icons.import_contacts_rounded,
    accent: TopicHues.hadithBooks,
    iconScale: 0.96,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.hadithBooks,
    keywords: ['بخاری', 'مسلم', 'کتب ستته', 'hadith'],
  ),
  MoreItem(
    id: 'dorar-hadith',
    title: 'جستجوی احادیث',
    icon: Icons.search_rounded,
    accent: TopicHues.dorarHadith,
    iconScale: 1.08,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.dorarHadithSearch,
    keywords: ['الدرر السنية', 'دorar', 'حدیث', 'search'],
  ),
  MoreItem(
    id: 'fatwa',
    title: 'فتاوای شرعی',
    icon: Icons.gavel_rounded,
    accent: TopicHues.fatwa,
    iconScale: 1.02,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.fatwa,
    keywords: ['فتوی', 'احکام', 'fatwa'],
  ),
  MoreItem(
    id: 'hadeeth-enc',
    title: 'موسوعه احادیث',
    icon: Icons.auto_awesome_mosaic_rounded,
    accent: TopicHues.hadeethEnc,
    iconScale: 0.96,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.hadeethEnc,
    keywords: ['دائرة المعارف', 'musawwa'],
  ),
  MoreItem(
    id: 'ketabkhaneh',
    title: 'کتابخانه',
    icon: Icons.library_books_rounded,
    accent: TopicHues.ketabkhaneh,
    iconScale: 0.96,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.ketabkhaneh,
    keywords: ['کتاب', 'کتابخوان', 'books'],
  ),
  MoreItem(
    id: 'sciences',
    title: 'علوم اسلامی',
    icon: Icons.school_rounded,
    accent: TopicHues.sciences,
    iconScale: 0.96,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.sciences,
    keywords: ['درس', 'رشته', 'آموزش', 'uloom'],
  ),
  MoreItem(
    id: 'study',
    title: 'مطالعه آزاد',
    icon: Icons.auto_stories_rounded,
    accent: TopicHues.study,
    iconScale: 0.96,
    group: MoreGroup.hadith,
    kind: MoreKind.route,
    destination: RouteNames.study,
    keywords: ['مطالعه', 'کتابخوانی', 'study'],
  ),
  MoreItem(
    id: 'yaqeen',
    title: 'تثبیت یقین',
    icon: Icons.verified_user_rounded,
    accent: TopicHues.yaqeen,
    group: MoreGroup.hadith,
    kind: MoreKind.lockedRoute,
    destination: RouteNames.yaqeen,
    lockCode: yaqeenLockCode,
    keywords: ['اعتقاد', 'یقین', 'شبهه', 'yaqeen'],
  ),
  MoreItem(
    id: 'qaf-ai',
    title: 'هوش مصنوعی شرعی قاف',
    icon: Icons.auto_awesome_rounded,
    accent: TopicHues.qafAi,
    iconScale: 1.04,
    group: MoreGroup.hadith,
    kind: MoreKind.web,
    destination: 'https://qaf.ai/fa',
    keywords: ['هوش مصنوعی', 'پرسش شرعی', 'qaf'],
  ),
  // ── کتابخانه صوتی ───────────────────────────────────────────────
  MoreItem(
    id: 'audio-shubuhat',
    title: 'رد شبهات',
    icon: Icons.policy_rounded,
    accent: TopicHues.yaqeen,
    group: MoreGroup.audio,
    kind: MoreKind.audioCategory,
    destination: 'yaqeen',
    keywords: ['شبهات', 'پادکست', 'صوت', 'audio'],
  ),
  MoreItem(
    id: 'audio-anasheed',
    title: 'اناشید اسلامی',
    icon: Icons.music_note_rounded,
    accent: TopicHues.anasheed,
    iconScale: 1.06,
    group: MoreGroup.audio,
    kind: MoreKind.audioCategory,
    destination: 'anasheed',
    keywords: ['سرود', 'اناشید', 'nasheed'],
  ),
  MoreItem(
    id: 'audio-lectures',
    title: 'سخنرانی',
    icon: Icons.record_voice_over_rounded,
    accent: TopicHues.lectures,
    group: MoreGroup.audio,
    kind: MoreKind.audioCategory,
    destination: 'lectures',
    keywords: ['سخنرانی', 'درس', 'medhia', 'lecture'],
  ),

  // ── ابزارها و پیشرفت ────────────────────────────────────────────
  // ماه و منازل and میراث live in عبادات و مناسک now; the personal-data tools
  // are what this grid is about.
  MoreItem(
    id: 'goals',
    title: 'هدف‌گذاری',
    icon: Icons.flag_rounded,
    accent: TopicHues.goals,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.goals,
    keywords: ['هدف', 'برنامه', 'پیشرفت', 'goals'],
  ),
  MoreItem(
    id: 'personal-info',
    title: 'اطلاعات من',
    icon: Icons.shield_rounded,
    accent: TopicHues.personalInfo,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.personalInfo,
    keywords: ['صندوق', 'اسناد', 'اطلاعات', 'vault'],
  ),
  MoreItem(
    id: 'tasks',
    title: 'مدیریت کارها',
    icon: Icons.checklist_rounded,
    accent: TopicHues.tasks,
    iconScale: 0.98,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.tasks,
    keywords: ['کارها', 'چک‌لیست', 'todo', 'tasks'],
  ),
  MoreItem(
    id: 'expenses',
    title: 'هزینه‌ها',
    icon: Icons.monetization_on_rounded,
    accent: TopicHues.expenses,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.expenses,
    keywords: ['خرج', 'بودجه', 'هزینه', 'expenses'],
  ),
  MoreItem(
    id: 'worship-notes',
    title: 'یادداشت‌ها',
    icon: Icons.note_alt_rounded,
    accent: TopicHues.worshipNotes,
    iconScale: 0.98,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.worshipNotes,
    keywords: ['یادداشت', 'دفترچه', 'notes'],
  ),
  MoreItem(
    id: 'reminders',
    title: 'یادآورها',
    icon: Icons.notifications_rounded,
    accent: TopicHues.reminders,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.reminders,
    keywords: ['یادآوری', 'اخطار', 'reminder'],
  ),
  MoreItem(
    id: 'period',
    title: 'دوره ماهانه',
    icon: Icons.woman_rounded,
    accent: TopicHues.period,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.period,
    keywords: ['حیض', 'بانوان', 'چرخه', 'period'],
  ),
  MoreItem(
    id: 'calculator',
    title: 'ماشین حساب',
    icon: Icons.calculate_rounded,
    accent: TopicHues.calculator,
    iconScale: 0.98,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.calculator,
    keywords: ['حساب', 'محاسبه', 'calc'],
  ),
  MoreItem(
    id: 'pomodoro',
    title: 'پومودور',
    icon: Icons.timer_rounded,
    accent: TopicHues.pomodoro,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.pomodoro,
    keywords: ['تایمر', 'تمرکز', 'پومودورو', 'timer'],
  ),
  MoreItem(
    id: 'dangi',
    title: 'دنگی',
    icon: Icons.groups_rounded,
    accent: TopicHues.dangi,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.dangi,
    keywords: ['شریک', 'تقسیم هزینه', 'dangi'],
  ),

  // ── ابزارهای شخصی — مجموعهٔ ۲ (مرحلهٔ ۱ تا ۳) ─────────────────────
  // Registered here in the tools grid (the user's call): the vault keeps its
  // own data, these tools open directly like every other tool — their
  // sensitive ACTIONS keep their own locks (ParentLock) inside.
  MoreItem(
    id: 'shop-ledger',
    title: 'حساب مغازه',
    icon: Icons.storefront_rounded,
    accent: TopicHues.shopLedger,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.shopHome,
    keywords: ['مغازه', 'فروش', 'صندوق', 'انبار', 'مشتری', 'چک', 'shop', 'pos'],
  ),

  // ── خودرو و خانه — ابزارهای مرحلهٔ ۱ ────────────────────────────────
  // They had routes and complete screens but NO door: the only way in was a
  // hand-typed URL, so the care engine was as good as invisible (audit P0-1).
  // User decision (2026-11-05): everything personal lives in «ابزارها و پیشرفت»
  // — no hub, no second list inside «اطلاعات من».
  MoreItem(
    id: 'car',
    title: 'خودرو',
    icon: Icons.directions_car_rounded,
    accent: TopicHues.car,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.personalCar,
    keywords: ['ماشین', 'سرویس', 'روغن', 'کیلومتر', 'سوخت', 'بیمه', 'car'],
  ),
  MoreItem(
    id: 'home-care',
    title: 'خانه',
    icon: Icons.home_rounded,
    accent: TopicHues.homeCare,
    iconScale: 0.98,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.personalHomeCare,
    keywords: ['منزل', 'سرویس', 'قبض', 'گارانتی', 'اشتراک', 'home'],
  ),

  // ── ابزارهای شخصی — مرحلهٔ ۳ (کفاره به عبادات منتقل شد؛ قلک باقی‌مانده) ──
  // کفاره و فدیه by user decision now lives in «عبادات و مناسک» (below); the
  // remaining personal-tools screen is قلک. These open directly like every
  // other tool, and their own sensitive actions keep the locks they carry.
  MoreItem(
    id: 'kaffara',
    title: 'کفاره و فدیه',
    icon: Icons.volunteer_activism_rounded,
    accent: TopicHues.kaffara,
    group: MoreGroup.worship,
    kind: MoreKind.route,
    destination: RouteNames.kaffara,
    keywords: ['کفاره', 'فدیه', 'اطعام', 'روزه', 'قسم', 'ظهار', 'نذر', 'kaffara'],
  ),
  MoreItem(
    id: 'finance',
    title: 'دفتر مالی',
    icon: Icons.account_balance_wallet_rounded,
    accent: TopicHues.personalTools,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.personalFinance,
    keywords: ['دفتر مالی', 'دَین', 'طلب', 'قسط', 'چک', 'پرداخت', 'finance'],
  ),
  MoreItem(
    id: 'savings',
    title: 'قلک',
    icon: Icons.monetization_on_rounded,
    accent: TopicHues.savings,
    group: MoreGroup.tools,
    kind: MoreKind.route,
    destination: RouteNames.personalSavings,
    keywords: ['قلک', 'پس‌انداز', 'هدف مالی', 'پول', 'savings'],
  ),

  // ── تنظیمات و بیشتر (SettingRow list, not tiles) ────────────────
  MoreItem(
    id: 'settings',
    title: 'تنظیمات',
    icon: Icons.settings_rounded,
    accent: TopicHues.app, // قهوه‌ای گرم — هویت برنامه
    group: MoreGroup.app,
    kind: MoreKind.route,
    destination: RouteNames.settings,
    subtitle: 'شخصی‌سازی و پیکربندی برنامه',
    keywords: ['تنظیمات', 'پیکربندی', 'settings'],
  ),
  MoreItem(
    id: 'backup',
    title: 'حساب و پشتیبان',
    icon: Icons.backup_rounded,
    accent: TopicHues.personalInfo, // blue-grey — the safe/vault family
    group: MoreGroup.app,
    kind: MoreKind.route,
    destination: RouteNames.account,
    subtitle: 'حساب ابری، پشتیبان و بازیابی اطلاعات',
    keywords: [
      'حساب',
      'پشتیبان',
      'نسخه',
      'بازیابی',
      'انتقال',
      'ابر',
      'account',
      'backup',
      'restore',
    ],
  ),
  MoreItem(
    id: 'announcements',
    title: 'پیام‌های مدیریت',
    icon: Icons.campaign_rounded,
    accent: TopicHues.reminders, // orange — the message family
    group: MoreGroup.app,
    kind: MoreKind.route,
    destination: RouteNames.announcements,
    subtitle: 'اطلاعیه‌ها و پیام‌های رسمی برنامه',
    keywords: ['پیام', 'اطلاعیه', 'مدیریت', 'announcements'],
  ),
  MoreItem(
    id: 'suggestions',
    title: 'ارسال پیشنهاد',
    icon: Icons.rate_review_rounded,
    accent: TopicHues.reminders, // orange — the message family
    group: MoreGroup.app,
    kind: MoreKind.route,
    destination: RouteNames.suggestions,
    subtitle: 'پیشنهاد، انتقاد یا گزارش خطا',
    keywords: [
      'پیشنهاد',
      'انتقاد',
      'خطا',
      'راهنما',
      'پشتیبانی',
      'help',
      'support',
    ],
  ),
  MoreItem(
    id: 'about',
    title: 'درباره برنامه',
    icon: Icons.info_rounded,
    accent: TopicHues.app, // قهوه‌ای گرم — هویت برنامه
    group: MoreGroup.app,
    kind: MoreKind.route,
    destination: RouteNames.about,
    subtitle: 'نسخه و اطلاعات برنامه',
    keywords: ['درباره', 'نسخه', 'برنامه', 'about', 'version'],
  ),
];

/// Groups in display order.
const List<MoreGroup> kMoreGroupOrder = MoreGroup.values;

// ═══════════════════════════════════════════════════════════════
// SEARCH — one normalization for the whole page
// ═══════════════════════════════════════════════════════════════

/// Persian-tolerant match key: folds Arabic ي/ك and hamza carriers to their
/// Persian forms, strips every haraka/tatweel, converts ۰-۹/٠-٩ to ASCII
/// digits, and removes ZWNJ plus spaces so a typed «قبله نما» finds
/// «قبله‌نما» and «کتاب خانه» finds «کتابخانه». The page's one normalization:
/// titles, keywords and section content all fold through it (see
/// `normalizeSearchKey`).
String normalizeMoreText(String input) => normalizeSearchKey(input);

/// True when [item]'s title or any keyword contains the already-normalized
/// [query]. An empty query matches everything.
bool moreItemMatches(MoreItem item, String query) {
  if (query.isEmpty) return true;
  if (normalizeMoreText(item.title).contains(query)) return true;
  return item.keywords.any((k) => normalizeMoreText(k).contains(query));
}

/// Items of [group] matching [query], in registry order.
List<MoreItem> moreItemsIn(MoreGroup group, String query) => [
      for (final item in kMoreItems)
        if (item.group == group && moreItemMatches(item, query)) item,
    ];

/// The item with [id], or null. The content search resolves the tile a hit
/// belongs to through this, so a result can never name a section that the
/// page does not draw.
MoreItem? moreItemById(String id) {
  for (final item in kMoreItems) {
    if (item.id == id) return item;
  }
  return null;
}
