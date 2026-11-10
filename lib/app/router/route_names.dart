class RouteNames {
  const RouteNames._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String shell = '/';

  // NOTE: shell tabs (home/quran/azkar/calendar/evaluation/more) are NOT
  // GoRoutes — they live in MainShell's IndexedStack and are selected via
  // shellTabIndexProvider (see shell_nav.dart). Do NOT add path constants
  // for them here: pushing such a path 404s (there was never a matching
  // GoRoute, and a duplicate top-level /evaluation once stacked a second
  // copy over the tab).
  static const String zakat = '/zakat';

  // Prayer times image/text share
  static const String prayerTimesShare = '/prayer/times-share';

  // Full-screen feature routes
  static const String prayer = '/prayer';
  static const String prayerSettings = '/prayer/settings';
  static const String mapPicker = '/prayer/map-picker';
  static const String qibla = '/qibla';
  static const String batteryOptimization = '/prayer/battery';
  static const String period = '/prayer/period';
  static const String khatm = '/khatm';
  static const String hifz = '/hifz';
  static const String reminders = '/reminders';
  static const String reminderEditor = '/reminders/edit';
  static const String noteEditor = '/notes/edit';
  static const String worshipNotes = '/notes';
  static const String worshipChecklist = '/worship-checklist';
  static const String tasks = '/tasks';
  static const String expenses = '/expenses';
  static const String expenseReport = '/expenses/report';
  static const String hadithBooks = '/hadith/books';

  // جستجوی احادیث — الدرر السنية (dorar.net)
  static const String dorarHadithSearch = '/dorar-hadith/search';
  static const String dorarHadithDetails = '/dorar-hadith/details/:id';
  static String dorarHadithDetailsPath(String id) =>
      '/dorar-hadith/details/$id';
  static const String riyad = '/riyad';
  static const String taraghib = '/taraghib';
  static const String maalim = '/maalim';
  static const String fatwa = '/fatwa';
  static const String hadeethEnc = '/hadeeth-enc';
  static const String hadeethEncDetail = '/hadeeth-enc/:id';
  static String hadeethEncDetailPath(int id) => '/hadeeth-enc/$id';
  static const String duas = '/duas';

  // Home timeline adhkar: the category list and the single-zikr share card.
  // Opened from the home actions timeline with `extra` (never a bare path —
  // the payload cannot travel in the URL), so a deep link without args falls
  // back to the not-found screen instead of crashing.
  static const String azkarCategory = '/azkar/category';
  static const String azkarShare = '/azkar/share';
  static const String ketabkhaneh = '/books';
  static const String sciences = '/sciences';
  static const String yaqeen = '/yaqeen';
  static const String audioLibrary = '/audio-library';
  static const String scienceDetail = '/sciences/:id';

  /// Concrete location for the science [id]; the literal `/sciences` route is
  /// distinct, so the id can never collide with it.
  static String scienceDetailPath(String id) => '/sciences/$id';
  static const String study = '/study';
  static const String dateConverter = '/tools/date-converter';
  static const String purification = '/tools/purification';
  static const String inheritance = '/tools/inheritance';
  static const String calculator = '/tools/calculator';
  static const String pomodoro = '/tools/pomodoro';
  static const String dangi = '/tools/dangi';
  static const String moon = '/tools/moon';

  static const String fasting = '/fasting';
  static const String hajjUmrah = '/hajj-umrah';
  static const String ruqyah = '/ruqyah';
  static const String settings = '/settings';
  static const String widgetSettings = '/settings/widget';
  static const String notificationSettings = '/settings/notifications';
  static const String notificationDiagnostics =
      '/settings/notifications/diagnostics';

  /// نگهداری: اسکن فایل‌های بی‌صاحب و ارجاع‌های شکستهٔ پیوست‌های «اطلاعات من».
  static const String attachmentDiagnostics =
      '/settings/attachments/diagnostics';
  static const String fontSettings = '/settings/font';
  static const String arcStyle = '/settings/arc-style';

  /// «امتیازدهی عبادات» — the six point values, in three tabs.
  static const String worshipScoring = '/settings/scoring';

  /// The same page with one tab already selected: 0 نماز · 1 اذکار · 2 طاعات.
  /// Const strings, not a helper — the settings registry is a `const` table.
  static const String worshipScoringPrayer = '$worshipScoring?tab=0';
  static const String worshipScoringAdhkar = '$worshipScoring?tab=1';
  static const String worshipScoringTaaat = '$worshipScoring?tab=2';
  static const String storageSettings = '/settings/storage';
  static const String about = '/settings/about';
  static const String suggestions = '/settings/suggestions';
  static const String announcements = '/settings/announcements';
  static const String account = '/settings/account';

  // Duas from sources
  static const String dua = '/dua';

  // In-app browser (external sites opened inside the app)
  static const String inAppBrowser = '/web';

  // «اطلاعات من» — صندوق شخصی
  static const String personalInfo = '/personal-info';
  static const String personalProfiles = '/personal-info/profiles';
  static const String personalProfileEditor = '/personal-info/profiles/edit';
  static const String personalDocuments = '/personal-info/documents';
  static const String personalCredentials = '/personal-info/credentials';
  static const String personalAssets = '/personal-info/assets';
  static const String personalInsurance = '/personal-info/insurance';
  static const String personalEmergencyContacts = '/personal-info/emergency';
  static const String personalExpiry = '/personal-info/expiry';
  // «خودرو» و «خانه» — the two stage-1 personal tools (no hub).
  static const String personalCar = '/personal-info/car';
  static const String personalCarHistory = '/personal-info/car/history';
  static const String personalHomeCare = '/personal-info/home';
  static const String personalHomeHistory = '/personal-info/home/history';
  // «دفتر مالی» — stage 2 of the personal tools (one page, two tabs) and a
  // person's ledger page.
  static const String personalFinance = '/personal-info/finance';
  static String personalFinancePerson(String personId) =>
      '/personal-info/finance/person/$personId';
  static const String personalFinancePersonPattern =
      '/personal-info/finance/person/:id';

  // Stage 3 of the personal tools — kaffara moved into عبادات و مناسک.
  static const String silatAlRahim = '/worship/silat-al-rahim';
  static const String kaffara = '/worship/kaffara';
  static const String personalSavings = '/personal-info/savings';
  static String personalSavingsGoal(String goalId) =>
      '/personal-info/savings/$goalId';
  static const String personalSavingsGoalPattern = '/personal-info/savings/:id';

  // «هدف‌گذاری»
  static const String goals = '/goals';

  // ═══ ابزارهای شخصی — مجموعهٔ ۲ (دفتر عادت کودک + دفتر مربی قرآن) ═══
  //
  // Registered inside the personal-tools family (the vault's own list), not on
  // Home and not in «بیشتر»: the brief forbids a hub page and forbids Home
  // entries for these two.
  static const String kidsHome = '/personal-tools/kids';
  static const String kidsChildSetup = '/personal-tools/kids/setup';
  static const String kidsChildMode = '/personal-tools/kids/child';
  static const String kidsHabits = '/personal-tools/kids/habits';
  static const String kidsRewards = '/personal-tools/kids/rewards';
  static const String kidsApprovals = '/personal-tools/kids/approvals';
  static const String kidsReport = '/personal-tools/kids/report';

  // ═══ ابزارهای شخصی — مجموعهٔ ۲، مرحلهٔ ۲ (حساب مغازه) ═══
  static const String shopHome = '/personal-tools/shop';
  static const String shopPos = '/personal-tools/shop/pos';
  static const String shopSettings = '/personal-tools/shop/settings';
  static const String shopCustomers = '/personal-tools/shop/customers';
  static const String shopCustomerDetail = '/personal-tools/shop/customer';
  static const String shopProducts = '/personal-tools/shop/products';
  static const String shopReport = '/personal-tools/shop/report';

  static const String quranTeacherHome = '/worship/quran-teacher';
  static const String quranTeacherLesson = '/worship/quran-teacher/lesson';
  static const String quranTeacherStudent = '/worship/quran-teacher/student';
  static const String quranTeacherReport = '/worship/quran-teacher/report';
  static const String quranTeacherClasses = '/worship/quran-teacher/classes';
  static const String quranTeacherSessionHistory =
      '/worship/quran-teacher/history';

  // ═══ Legacy route aliases ═══
  // The "move to worship" commit renamed these paths. Three legacy callers
  // still read the old names: `section_colors.dart` (theme lookup),
  // `boot_coordinator.dart` (notification deep links) and
  // `personal_info_screen.dart` (vault tiles). Those are protected files, so
  // the aliases live here and resolve to the SAME registered route — a dead
  // path here would silently break deep links and section colours.
  static const String teacherHome = quranTeacherHome;
  static const String teacherLesson = quranTeacherLesson;
  static const String teacherStudent = quranTeacherStudent;
  static const String teacherReport = quranTeacherReport;
  static const String teacherClasses = quranTeacherClasses;
  static const String personalRelatives = silatAlRahim;
  static const String personalKaffara = kaffara;
  static const String personalQaza = qaza;

  /// «قضایار» — no longer listed in the More grid, but the vault tile and the
  /// `family_qaza_*` notification payloads still deep-link into it, so the
  /// route must stay registered until those callers are retired too.
  static const String qaza = '/personal-info/qaza';

  /// Pattern route for a single goal — the `:id` parameter is what
  /// [goalDetailPath] produces, so it must be a real path parameter.
  static const String goalDetail = '/goals/:id';
  static const String goalEditor = '/goals/edit';

  /// Concrete location for [id]; kept separate from the [goalDetail] pattern so
  /// navigation never confuses the literal `/goals/edit` route with an id.
  static String goalDetailPath(String id) => '/goals/$id';
}
