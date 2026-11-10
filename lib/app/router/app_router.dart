import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/main_shell.dart';
import 'package:tawheeed/app/router/route_accent.dart';
import 'package:tawheeed/app/router/route_guard.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/error/error_boundary.dart';
import 'package:tawheeed/features/splash/presentation/screens/splash_screen.dart';
import 'package:tawheeed/features/splash/presentation/splash_style.dart';
import 'package:tawheeed/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/notification_diagnostics_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/attachment_diagnostics_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/arc_style_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/worship_scoring_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/storage_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/battery_optimization_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/widget_settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';
import 'package:tawheeed/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:tawheeed/features/suggestions/presentation/screens/suggestions_screen.dart';
import 'package:tawheeed/features/account/presentation/screens/account_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/map_picker_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/qibla_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/period_screen.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_times_share_screen.dart';
import 'package:tawheeed/features/hadith/presentation/screens/hadith_books_screen.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/screens/dorar_hadith_search_screen.dart';
import 'package:tawheeed/features/dorar_hadith/presentation/screens/dorar_hadith_details_screen.dart';
import 'package:tawheeed/features/fatwa/presentation/screens/fatwa_screen.dart';
import 'package:tawheeed/features/yaqeen/presentation/screens/yaqeen_home_screen.dart';
import 'package:tawheeed/features/audio_library/presentation/screens/audio_library_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_screen.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_detail_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/duas_screen.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/screens/adhkar_share_screen.dart';
import 'package:tawheeed/features/dua_from_quran/presentation/screens/dua_from_quran_screen.dart';
import 'package:tawheeed/features/home/presentation/widgets/adhkar_category_page.dart';
import 'package:tawheeed/features/books/presentation/screens/ketabkhaneh_screen.dart';
import 'package:tawheeed/features/education/presentation/screens/study_screen.dart';
import 'package:tawheeed/features/education/presentation/screens/sciences_home_screen.dart';
import 'package:tawheeed/features/education/presentation/screens/science_detail_screen.dart';
import 'package:tawheeed/features/notes/presentation/screens/worship_notes_screen.dart';
import 'package:tawheeed/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/khatm/presentation/screens/khatm_screen.dart';
import 'package:tawheeed/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:tawheeed/features/reminders/presentation/screens/reminder_editor_screen.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/features/checklist/presentation/screens/worship_checklist_screen.dart';
import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/features/tools/purification/presentation/screens/purification_screen.dart';
import 'package:tawheeed/features/tools/date_converter/presentation/screens/date_converter_screen.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/screens/inheritance_screen.dart';
import 'package:tawheeed/features/fasting/presentation/screens/fasting_screen.dart';
import 'package:tawheeed/features/hajj_umrah/presentation/screens/hajj_umrah_screen.dart';
import 'package:tawheeed/features/ruqyah/presentation/screens/ruqyah_screen.dart';
import 'package:tawheeed/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expense_report_screen.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_screen.dart';
import 'package:tawheeed/features/tools/calculator/presentation/screens/calculator_screen.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_screen.dart';
import 'package:tawheeed/features/tools/moon/presentation/screens/moon_screen.dart';

import 'package:tawheeed/features/goals/domain/goal_templates.dart';
import 'package:tawheeed/features/goals/presentation/screens/goals_screen.dart';
import 'package:tawheeed/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:tawheeed/features/goals/presentation/screens/goal_editor_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/vault_session.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/personal_info_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/child_mode_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/child_setup_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_approvals_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_habits_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_home_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_report_screen.dart';
import 'package:tawheeed/features/personal2/kids/presentation/screens/kids_rewards_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/class_management_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/session_history_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/lesson_sheet_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/parent_report_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/student_profile_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_home_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_products_tab.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_report_tab.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_settings_screen.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/pos_screen.dart';
import 'package:tawheeed/features/worship/quran_teacher/presentation/screens/quran_teacher_home_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/profiles_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/profile_editor_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/documents_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/credentials_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/assets_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/insurance_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/emergency_contacts_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/expiry_screen.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/presentation/screens/car_screen.dart';
import 'package:tawheeed/features/personal/presentation/screens/care_history_screen.dart';
import 'package:tawheeed/features/personal/presentation/screens/home_care_screen.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_screen.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_screen.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/presentation/screens/relatives_screen.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/savings_screen.dart';

import 'package:tawheeed/shared/widgets/lazy_content.dart';
import 'package:tawheeed/shared/widgets/in_app_browser_screen.dart';
import 'package:tawheeed/features/prayer/data/salah_data.dart';
import 'package:tawheeed/features/fasting/data/fasting_content.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_data.dart';
import 'package:tawheeed/features/tools/purification/data/taharah_data.dart';
import 'package:tawheeed/features/hajj_umrah/data/hajj_content.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/core/theme/theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Cache the router instance. Creating a new GoRouter on every rebuild (which
// happens whenever settings change) resets navigation to `initialLocation`
// (/splash), causing the app to loop back to the splash screen endlessly.
GoRouter? _cachedRouter;

GoRouter buildAppRouter() {
  _cachedRouter ??= GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    // The app always starts at the splash. Android can hand Flutter an
    // initial route it did not ask for (a widget trampoline's
    // `glance-action:/CALLBACK?…`, or a bare `/CALLBACK?…` path), and GoRouter
    // used to render the 404 page for it before the splash gate ran — the app
    // appeared to open on «صفحه پیدا نشد». Nothing in this app arrives through
    // the platform route channel (widget/notification taps travel through the
    // shortcut prefs and the notification channel), so the platform's default
    // location is ignored outright.
    overridePlatformDefaultLocation: true,
    // The first-launch decision still belongs to SplashScreen (shell vs
    // onboarding) after settings load; there is deliberately no auth/DB guard
    // here. A foreign location that arrives *mid-session* (a warm intent) is
    // routed through the splash gate instead of the error screen.
    redirect: (context, state) =>
        isForeignLocation(state.uri) ? RouteNames.splash : null,
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(
        path: RouteNames.splash,
        // The splash never animates in — it is the first thing on screen and
        // the native window has been showing this very field. On the way out
        // it stays painted at full opacity underneath the destination, which
        // is what makes the hand-off a dissolve of the decorations rather
        // than a flash of the platform window.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: SplashTiming.crossFade,
          transitionsBuilder: (context, animation, secondary, child) => child,
        ),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        pageBuilder: (context, state) =>
            _handoffPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: RouteNames.shell,
        pageBuilder: (context, state) => _handoffPage(
          state,
          const AppErrorBoundary(child: MainShell()),
        ),
      ),
      // Settings
      GoRoute(
        path: RouteNames.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const SettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.notificationSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.notificationDiagnostics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const NotificationDiagnosticsScreen()),
      ),
      GoRoute(
        path: RouteNames.attachmentDiagnostics,
        parentNavigatorKey: rootNavigatorKey,
        // Internal maintenance tool: its only entry is kDebugMode-gated, so
        // release deep-links must not open it — bounce to settings instead.
        redirect: (context, state) => kDebugMode ? null : RouteNames.settings,
        builder: (context, state) =>
            _ambient(const AttachmentDiagnosticsScreen()),
      ),
      GoRoute(
        path: RouteNames.batteryOptimization,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const BatteryOptimizationScreen()),
      ),
      GoRoute(
        path: RouteNames.widgetSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const WidgetSettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const AboutScreen()),
      ),
      GoRoute(
        path: RouteNames.suggestions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const SuggestionsScreen()),
      ),
      GoRoute(
        path: RouteNames.announcements,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const AnnouncementsScreen()),
      ),
      GoRoute(
        path: RouteNames.account,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const AccountScreen()),
      ),
      GoRoute(
        path: RouteNames.fontSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const FontDisplayPage()),
      ),
      GoRoute(
        path: RouteNames.arcStyle,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ArcStyleScreen()),
      ),
      GoRoute(
        path: RouteNames.worshipScoring,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(WorshipScoringScreen(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        )),
      ),
      GoRoute(
        path: RouteNames.storageSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const StorageScreen()),
      ),
      // NOTE: no top-level /evaluation route on purpose — EvaluationTab is
      // shell tab 4 (single source). A duplicate GoRoute here used to stack a
      // second copy over the tab and confuse back navigation.
      // Prayer
      GoRoute(
        path: RouteNames.prayer,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: () async {
            await Future.wait([SalahData.load(), SawmData.load()]);
          },
          builder: (_) => const PrayerScreen(),
        )),
      ),
      GoRoute(
        path: RouteNames.prayerSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const PrayerSettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.mapPicker,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const MapPickerScreen()),
      ),
      GoRoute(
        path: RouteNames.qibla,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const QiblaScreen()),
      ),
      GoRoute(
        path: RouteNames.period,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const PeriodScreen()),
      ),
      GoRoute(
        path: RouteNames.prayerTimesShare,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const PrayerTimesShareScreen()),
      ),
      // Hadith books
      GoRoute(
        path: RouteNames.hadithBooks,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const HadithBooksScreen()),
      ),
      // جستجوی احادیث — الدرر السنية (dorar.net)
      GoRoute(
        path: RouteNames.dorarHadithSearch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const DorarHadithSearchScreen()),
      ),
      GoRoute(
        path: RouteNames.dorarHadithDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(DorarHadithDetailsScreen(
          hadithId: state.pathParameters['id'] ?? '',
        )),
      ),
      // ریاض الصالحین — بخش مستقل مطالعه
      GoRoute(
        path: RouteNames.riyad,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const RiyadScreen()),
      ),
      // صحیح الترغیب — هم‌جوار ریاض الصالحین
      GoRoute(
        path: RouteNames.taraghib,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const TaraghibScreen()),
      ),
      // معالم السنه النبویه — سومین کتاب مستقلِ «حدیث و مطالعه»
      GoRoute(
        path: RouteNames.maalim,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const MaalimScreen()),
      ),
      // فتاوای شرعی (فارسی)
      GoRoute(
        path: RouteNames.fatwa,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const FatwaScreen()),
      ),
      // یقین — تثبیت اعتقادی و پاسخ به شبهات
      GoRoute(
        path: RouteNames.yaqeen,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const YaqeenHomeScreen()),
      ),
      // کتابخانه صوتی — درس‌های صوتی (استریم/آفلاین، Supabase public bucket)
      GoRoute(
        path: RouteNames.audioLibrary,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(AudioLibraryScreen(
          initialCategoryId: state.uri.queryParameters['cat'],
          initialSpeakerId: state.uri.queryParameters['speaker'],
        )),
      ),
      // موسوعه احادیث
      GoRoute(
        path: RouteNames.hadeethEnc,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const HadeethEncScreen()),
      ),
      GoRoute(
        path: RouteNames.hadeethEncDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          // A deep-search hit carries the matched literal as `?q=` so the
          // destination can shade the word the user searched for.
          final highlight = state.uri.queryParameters['q'] ?? '';
          final hadith = hadithFromRouteExtra(extra);
          if (hadith != null) {
            return _ambient(HadeethEncDetailScreen(
                hadith: hadith,
                sequence: sequenceFromRouteExtra(extra),
                highlightQuery: highlight));
          }
          // A bare `/hadeeth-enc/<id>` carries no object — the id alone has to
          // load the row; falling back to the list silently ignored it.
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return _ambient(const HadeethEncScreen());
          return _ambient(HadeethEncDetailByIdScreen(
              hadithId: id, highlightQuery: highlight));
        },
      ),
      // Duas
      GoRoute(
        path: RouteNames.duas,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const DuasScreen()),
      ),
      // Home timeline adhkar (args travel in `extra`, never the URL).
      GoRoute(
        path: RouteNames.azkarCategory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra;
          if (args is AdhkarCategoryArgs) {
            return _ambient(AdhkarCategoryPage(
              title: args.title,
              period: args.period,
              items: args.items,
              highlightQuery: args.highlightQuery,
              focusId: args.focusId,
            ));
          }
          return _ambient(const _NotFoundScreen());
        },
      ),
      GoRoute(
        path: RouteNames.azkarShare,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ZikrItem) {
            return _ambient(AdhkarShareScreen(item: extra));
          }
          return _ambient(const _NotFoundScreen());
        },
      ),
      // Books
      GoRoute(
        path: RouteNames.ketabkhaneh,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const AppErrorBoundary(
          child: KetabkhanehScreen(),
        )),
      ),
      // Education
      GoRoute(
        path: RouteNames.study,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const StudyScreen()),
      ),
      GoRoute(
        path: RouteNames.sciences,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const SciencesHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.scienceDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _ambient(ScienceDetailScreen(scienceId: id));
        },
      ),
      // Worship
      GoRoute(
        path: RouteNames.worshipNotes,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const WorshipNotesScreen()),
      ),
      GoRoute(
        path: RouteNames.worshipChecklist,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const WorshipChecklistScreen()),
      ),
      GoRoute(
        path: RouteNames.noteEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // New note when extra is absent; edit when a NoteTableData is passed.
          // `q` carries the word a search opened this note for, so the editor
          // can paint it and scroll to it (an editable field cannot be given a
          // span from outside).
          final note = state.extra is NoteTableData
              ? state.extra as NoteTableData
              : null;
          return _ambient(NoteEditorScreen(
            note: note,
            highlightQuery: state.uri.queryParameters['q'] ?? '',
          ));
        },
      ),
      GoRoute(
        path: RouteNames.reminderEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // New reminder when extra is absent; edit when a ReminderModel is.
          final reminder = state.extra is ReminderModel
              ? state.extra as ReminderModel
              : null;
          return _ambient(ReminderEditorScreen(reminder: reminder));
        },
      ),
      GoRoute(
        path: RouteNames.khatm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KhatmScreen()),
      ),
      GoRoute(
        path: RouteNames.hifz,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const HifzScreen()),
      ),
      GoRoute(
        path: RouteNames.reminders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const RemindersScreen()),
      ),
      // Tools
      GoRoute(
        path: RouteNames.zakat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: ZakatContent.load,
          builder: (_) => const ZakatScreen(),
        )),
      ),
      GoRoute(
        path: RouteNames.purification,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: TaharahData.load,
          builder: (_) => const PurificationScreen(),
        )),
      ),
      GoRoute(
        path: RouteNames.dateConverter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // Optional preselected Gregorian day from the calendar tab.
          final extra = state.extra;
          final initial = extra is (int, int, int) ? extra : null;
          return _ambient(DateConverterScreen(
            initialGregorianYear: initial?.$1,
            initialGregorianMonth: initial?.$2,
            initialGregorianDay: initial?.$3,
          ));
        },
      ),
      // Fasting
      GoRoute(
        path: RouteNames.fasting,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: SawmData.load,
          builder: (_) => const FastingScreen(),
        )),
      ),
      // Inheritance
      GoRoute(
        path: RouteNames.inheritance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: InheritanceContent.load,
          builder: (_) => const InheritanceScreen(),
        )),
      ),
      // Hajj & Umrah
      GoRoute(
        path: RouteNames.hajjUmrah,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(LazyContent(
          loader: HajjData.load,
          builder: (_) => const HajjUmrahScreen(),
        )),
      ),
      // Ruqyah (رقیه شرعی)
      GoRoute(
        path: RouteNames.ruqyah,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const RuqyahScreen()),
      ),
      // Tasks
      GoRoute(
        path: RouteNames.tasks,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const TasksScreen()),
      ),
// Expenses
      GoRoute(
        path: RouteNames.expenses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ExpensesScreen()),
      ),
      GoRoute(
        path: RouteNames.expenseReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ExpenseReportScreen()),
      ),
      // Dua
      GoRoute(
        path: RouteNames.dua,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const DuaFromQuranScreen()),
      ),
      // Calculator
      GoRoute(
        path: RouteNames.calculator,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const CalculatorScreen()),
      ),
      // Pomodoro
      GoRoute(
        path: RouteNames.pomodoro,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const PomodoroScreen()),
      ),
      // Dangi (bill splitting)
      GoRoute(
        path: RouteNames.dangi,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const DangiScreen()),
      ),
      // Moon & Manazil
      GoRoute(
        path: RouteNames.moon,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const MoonScreen()),
      ),
      // «اطلاعات من» — صندوق شخصی. The landing screen runs its own PIN gate;
      // every vault sub-route is wrapped in [VaultGuard] so a deep link or a
      // back-stack reopen can never show decrypted data without an unlock.
      GoRoute(
        path: RouteNames.personalInfo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const PersonalInfoScreen()),
      ),
      GoRoute(
        path: RouteNames.personalProfiles,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: ProfilesScreen())),
      ),
      GoRoute(
        path: RouteNames.personalProfileEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: ProfileEditorScreen(
            profile: state.extra is PersonalProfileTableData
                ? state.extra! as PersonalProfileTableData
                : null,
          ),
        )),
      ),
      GoRoute(
        path: RouteNames.personalDocuments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: DocumentsScreen(
            profileId: state.uri.queryParameters['profile'],
          ),
        )),
      ),
      GoRoute(
        path: RouteNames.personalCredentials,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: CredentialsScreen())),
      ),
      GoRoute(
        path: RouteNames.personalAssets,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: AssetsScreen())),
      ),
      GoRoute(
        path: RouteNames.personalInsurance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: InsuranceScreen())),
      ),
      GoRoute(
        path: RouteNames.personalEmergencyContacts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: EmergencyContactsScreen())),
      ),
      GoRoute(
        path: RouteNames.personalExpiry,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: ExpiryScreen())),
      ),
      // «خودرو» و «خانه» — the two stage-1 personal tools (no hub).
      GoRoute(
        path: RouteNames.personalCar,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: CarScreen(initialTaskId: state.uri.queryParameters['task']),
        )),
      ),
      GoRoute(
        path: RouteNames.personalCarHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: CareHistoryScreen(
            kind: CareAssetKind.car,
            assetId: state.uri.queryParameters['asset'],
          ),
        )),
      ),
      GoRoute(
        path: RouteNames.personalHomeCare,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: HomeCareScreen())),
      ),
      GoRoute(
        path: RouteNames.personalHomeHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: CareHistoryScreen(
            kind: CareAssetKind.home,
            assetId: state.uri.queryParameters['asset'],
          ),
        )),
      ),
      // «دفتر مالی» — stage 2 (one page, two tabs) and a person's ledger page.
      GoRoute(
        path: RouteNames.personalFinance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: FinanceScreen())),
      ),
      GoRoute(
        path: RouteNames.personalFinancePersonPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: DebtPersonScreen(personId: state.pathParameters['id'] ?? ''),
        )),
      ),
      // Stage-3 personal tools — four separate entries, not a hub.
      GoRoute(
        path: RouteNames.silatAlRahim,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: RelativesScreen())),
      ),
      GoRoute(
        path: RouteNames.kaffara,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: KaffaraScreen())),
      ),
      GoRoute(
        path: RouteNames.personalSavings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const VaultGuard(child: SavingsScreen())),
      ),
      GoRoute(
        path: RouteNames.personalSavingsGoalPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(VaultGuard(
          child: SavingsGoalScreen(goalId: state.pathParameters['id'] ?? ''),
        )),
      ),
      // ═══ ابزارهای شخصی — مجموعهٔ ۲ ═══
      // «دفتر عادت کودک» و «دفتر مربی قرآن». Both live in the personal-tools
      // family, so both sit behind the same vault PIN as the rest of the
      // section (a parent's child data is not less private than a passport
      // number), and the kids tool layers its own ParentLock on top of the
      // specific actions that need it.
      GoRoute(
        path: RouteNames.kidsHome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KidsHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.kidsChildSetup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(ChildSetupScreen(
          // `extra` carries the kid id; a deep link without it cannot
          // fabricate a child, so it shows the home instead of crashing.
          kidId: state.extra is String ? state.extra! as String : '',
        )),
      ),
      GoRoute(
        path: RouteNames.kidsChildMode,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(ChildModeScreen(
          kidId: state.extra is String ? state.extra! as String : '',
        )),
      ),
      GoRoute(
        path: RouteNames.kidsHabits,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KidsHabitsScreen()),
      ),
      GoRoute(
        path: RouteNames.kidsRewards,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KidsRewardsScreen()),
      ),
      GoRoute(
        path: RouteNames.kidsApprovals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KidsApprovalsScreen()),
      ),
      GoRoute(
        path: RouteNames.kidsReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const KidsReportScreen()),
      ),
      GoRoute(
        path: RouteNames.quranTeacherHome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const QuranTeacherHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.quranTeacherLesson,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // `extra` is a (classId, studentId) record; without it there is no
          // lesson to record, so fall back to the class home.
          final extra = state.extra;
          if (extra is! ({String classId, String studentId})) {
            return _ambient(const VaultGuard(child: QuranTeacherHomeScreen()));
          }
          return _ambient(LessonSheetScreen(
            classId: extra.classId,
            studentId: extra.studentId,
          ));
        },
      ),
      GoRoute(
        path: RouteNames.quranTeacherStudent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(StudentProfileScreen(
          studentId: state.extra is String ? state.extra! as String : '',
        )),
      ),
      GoRoute(
        path: RouteNames.quranTeacherReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(ParentReportScreen(
          studentId: state.extra is String ? state.extra! as String : '',
        )),
      ),
      GoRoute(
        path: RouteNames.quranTeacherClasses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ClassManagementScreen()),
      ),
      GoRoute(
        path: RouteNames.quranTeacherSessionHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(SessionHistoryScreen(
          classId: state.extra is String ? state.extra! as String : '',
        )),
      ),
      // ═══ ابزارهای شخصی — «حساب مغازه» ═══
      // Same family, same vault PIN: the shop's ledger is at least as
      // sensitive as the vault's documents.
      GoRoute(
        path: RouteNames.shopHome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ShopHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.shopPos,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(PosScreen(
          invoiceId: state.extra is String ? state.extra! as String : null,
        )),
      ),
      GoRoute(
        path: RouteNames.shopSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const ShopSettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.shopProducts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const Scaffold(body: ShopProductsTab())),
      ),
      GoRoute(
        path: RouteNames.shopReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            _ambient(const Scaffold(body: ShopReportTab())),
      ),
      // «هدف‌گذاری»
      GoRoute(
        path: RouteNames.goals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(const GoalsScreen()),
      ),
      // Registered before the `/goals/:id` pattern so the literal editor path
      // is never swallowed as a goal id.
      GoRoute(
        path: RouteNames.goalEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _ambient(GoalEditorScreen(
          goal: state.extra is GoalTableData
              ? state.extra! as GoalTableData
              : null,
          template:
              state.extra is GoalTemplate ? state.extra! as GoalTemplate : null,
        )),
      ),
      GoRoute(
        path: RouteNames.goalDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _ambient(GoalDetailScreen(goalId: id));
        },
      ),

      // In-app browser (external sites inside the app, e.g. qaf.ai)
      GoRoute(
        path: RouteNames.inAppBrowser,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra is InAppBrowserArgs
              ? state.extra! as InAppBrowserArgs
              : null;
          return _ambient(InAppBrowserScreen(
            title: args?.title ?? '',
            url: args?.url ?? 'https://qaf.ai/fa',
          ));
        },
      ),
    ],
  );
  return _cachedRouter!;
}

/// Backdrop for every pushed route: the same ambient gradient the shell
/// paints behind its tabs. Screens keep `Scaffold(backgroundColor:
/// Colors.transparent)`, so without this they paint straight over the
/// platform window. MainShell paints its own copy behind the tabs.
///
/// The route's own location decides the ambient **hue** (see
/// `route_accent.dart`): زکات arrives in its gold and رقیه in its green,
/// instead of inheriting whichever tab launched it. Reading the state is legal
/// here because this widget lives under the route's `builder` subtree; a
/// context without a router keeps the phase palette.
Widget _ambient(Widget child) => _AmbientRoute(child: child);

/// One pushed page's ambient field.
class _AmbientRoute extends StatelessWidget {
  const _AmbientRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Color? accent;
    try {
      accent = routeAccentFor(GoRouterState.of(context).matchedLocation);
    } on GoError {
      accent = null;
    }
    return AmbientBackground(accent: accent, child: child);
  }
}

/// The two cold-start destinations (Home and onboarding) arrive through a
/// cross-fade, so the splash's field dissolves into them instead of snapping.
/// The splash worked the length out — it knows whether this is a lite-mode or
/// reduce-motion launch — and passes it as `extra`; any other arrival gets
/// the same soft fade at its default length.
CustomTransitionPage<void> _handoffPage(GoRouterState state, Widget child) {
  final extra = state.extra;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: extra is Duration ? extra : SplashTiming.crossFade,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Persian 404 for unknown/dead paths, with a way back home.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'صفحه پیدا نشد',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 19),
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نشانی واردشده در برنامه وجود ندارد.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(RouteNames.shell),
                    child: const Text('بازگشت به خانه'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
