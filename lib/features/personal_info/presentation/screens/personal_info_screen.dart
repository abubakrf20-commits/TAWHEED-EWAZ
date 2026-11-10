import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/vault_session.dart';
import 'package:tawheeed/features/personal_info/presentation/widgets/sensitive_data_notice.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart'
    show careCarColor, careHomeColor;
import 'package:tawheeed/features/personal/finance/presentation/finance_style.dart'
    show financeInstallmentColor;
import 'package:tawheeed/features/personal/family_faith/presentation/family_faith_style.dart'
    show
        familyRelativeColor,
        familySavingsColor;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «اطلاعات من» — personal vault: profiles, IDs, credentials, assets,
/// insurance, emergency contacts, expiry countdowns and security settings.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final Color _accent = TopicHues.personalInfo;
  bool? _locked; // null = still loading
  final _pinCtrl = TextEditingController();
  String _pinError = '';
  late final VaultSessionNotifier _vault;

  @override
  void initState() {
    super.initState();
    // Device-proven 2026-10-13: ref.read() in dispose() throws once the
    // element unmounts — and the throw skipped lock(), silently leaving the
    // vault open. Capture the notifier while mounted instead.
    _vault = ref.read(vaultSessionProvider.notifier);
    _initLockState();
  }

  /// True when the device's secure storage refused to answer. The vault stays
  /// shut — an unreadable lock state is not a reason to open it — and the
  /// screen says so instead of spinning or pretending the PIN is wrong.
  bool _lockUnavailable = false;

  Future<void> _initLockState() async {
    try {
      final pinSet = await PinLockService.isPinSet();
      if (mounted) setState(() => _locked = pinSet);
    } catch (e, st) {
      // Fail CLOSED. Leaving `_locked` null spun forever with no explanation;
      // setting it false would have opened the vault to anyone holding the
      // phone because the keystore was unavailable.
      AppLogger.error('PersonalInfo', 'PIN lock state unreadable: $e', st);
      if (mounted) {
        setState(() {
          _locked = true;
          _lockUnavailable = true;
        });
      }
    }
  }

  Future<void> _submitPin() async {
    // The button disables itself, but `onSubmitted` (Enter/hardware keypad)
    // calls this directly — without this guard the lockout was bypassable.
    if (_failedAttempts >= _maxAttempts) return;
    // Keypads and password managers can produce Persian digits; the verifier
    // hashes raw bytes, so «۱۲۳۴» failed even when the PIN was correct.
    final pin = _normalizePin(_pinCtrl.text);
    if (pin.isEmpty) return;
    final bool ok;
    try {
      ok = await PinLockService.verifyPin(pin);
    } catch (e, st) {
      // The verifier throwing used to surface only as an unhandled async
      // error: the tap did nothing and the gate sat there saying nothing.
      AppLogger.error('PersonalInfo', 'PIN verification could not run: $e', st);
      if (!mounted) return;
      setState(() {
        _lockUnavailable = true;
        _pinError = 'بررسی رمز ممکن نشد؛ قفل امن دستگاه در دسترس نیست.';
      });
      return;
    }
    if (!mounted) return;
    if (ok) {
      ref.read(vaultSessionProvider.notifier).unlock();
      setState(() {
        _locked = false;
        _pinError = '';
        _pinCtrl.clear();
      });
    } else {
      _failedAttempts++;
      setState(() {
        _pinError = 'رمز اشتباه است؛ دوباره تلاش کنید.';
        _pinCtrl.clear();
      });
    }
  }

  int _failedAttempts = 0;
  static const _maxAttempts = 5;

  /// Persian (۰-۹) and Arabic-Indic (٠-٩) digits → ASCII so hashing matches.
  static String _normalizePin(String raw) =>
      NumberFormat.normalizeDigits(raw.trim());

  @override
  void dispose() {
    // Leaving the vault re-arms the gate for the sub-routes; re-entry always
    // asks for the PIN again (the screen's own `_locked` starts from isPinSet).
    // Uses the notifier captured in initState: ref.read() here throws once
    // the element unmounts (device-proven 2026-10-13) and would skip lock().
    _vault.lock();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'اطلاعات من',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (locked) {
          null => const Center(child: CircularProgressIndicator()),
          _ when _lockUnavailable => _buildLockUnavailable(),
          true => _buildPinGate(),
          false => _buildDashboard(),
        },
      ),
    );
  }

  /// The device's secure storage is unreachable: say so plainly and offer a
  /// retry, rather than an endless spinner or a PIN pad that cannot verify.
  Widget _buildLockUnavailable() {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gpp_maybe_outlined, size: 48, color: danger),
            const SizedBox(height: 16),
            Text(
              'قفل اطلاعات من باز نشد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.w700,
                color: t.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'دسترسی به قفل امن دستگاه ممکن نشد. اطلاعات شما پاک نشده است؛ '
              'تا باز شدن قفل، محتوای این بخش نمایش داده نمی‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.7,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _lockUnavailable = false;
                  _locked = null;
                  _pinError = '';
                });
                _initLockState();
              },
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PIN gate ───────────────────────────────────────────────
  Widget _buildPinGate() {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 42, color: _accent),
            ),
            const SizedBox(height: 20),
            Text(
              'صندوق «اطلاعات من» قفل است',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'برای مشاهده اطلاعات حساس، رمز عبور را وارد کنید.\n'
              'حساب‌ها، کارت‌ها و مدارک تا تأیید رمز مخفی می‌مانند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              enabled: _failedAttempts < _maxAttempts,
              onSubmitted: (_) => _submitPin(),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  letterSpacing: 12,
                  fontSize: AppTheme.scaledFontSize(context, 19)),
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                border: const OutlineInputBorder(),
                errorText: _pinError.isEmpty ? null : _pinError,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _failedAttempts >= _maxAttempts ? null : _submitPin,
              style: FilledButton.styleFrom(backgroundColor: _accent),
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('ورود'),
            ),
            if (_failedAttempts >= _maxAttempts) ...[
              const SizedBox(height: 8),
              Text(
                'تلاش‌های ناموفق زیاد — صندوق موقتاً قفل شد. اپ را ببندید و '
                'دوباره باز کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: danger,
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: _showResetDialog,
                child: Text(
                  'رمز را فراموش کرده‌اید؟',
                  style: TextStyle(color: t.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showResetDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازنشانی صندوق؟'),
        content: const Text(
            'با بازنشانی، رمز و کلید رمزنگاری پاک می‌شود. هر داده‌ای که با '
            'کلید قبلی رمز شده است دیگر قابل خواندن نیست. ادامه می‌دهید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('بازنشانی'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PinLockService.resetVault();
      if (mounted) {
        ref.invalidate(secretVaultProvider);
        ref.invalidate(vaultPinSetProvider);
        ref.read(vaultSessionProvider.notifier).unlock();
        setState(() => _locked = false);
      }
    }
  }

  // ─── Dashboard ──────────────────────────────────────────────
  Widget _buildDashboard() {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildStats(),
        const SizedBox(height: 16),
        _SecurityBanner(
          accent: _accent,
          onChangedPin: () {
            // Setting, changing or deleting the PIN changes whether sub-routes
            // must be guarded; the dashboard itself stays open this session.
            ref.invalidate(vaultPinSetProvider);
            ref.read(vaultSessionProvider.notifier).unlock();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        const SensitiveDataNotice(),
        const SizedBox(height: 16),

        // Expiry countdowns
        _sectionHeader(context, Icons.event_outlined, 'تاریخ‌های مهم'),
        _buildExpiryCard(),
        const SizedBox(height: 16),

        _sectionHeader(context, Icons.people_outline, 'افراد و خانواده'),
        _tile(
          Icons.badge_outlined,
          'پروفایل‌ها',
          'اطلاعات اعضای خانواده',
          TopicHues.personalProfile,
          () => _openSection(RouteNames.personalProfiles),
        ),
        _tile(
          Icons.folder_special_outlined,
          'مدارک و اسناد',
          'مدارک هویتی هر یک از اعضا',
          TopicHues.personalDocs,
          () => _openSection(RouteNames.personalDocuments),
        ),
        const SizedBox(height: 14),

        _sectionHeader(context, Icons.lock_outline, 'رمزها و حساب‌ها'),
        _tile(
          Icons.password_outlined,
          'رمزها، کارت‌ها و حساب‌ها',
          'گذرواژه‌ها، کارت بانکی، شبا، شبکه‌های اجتماعی',
          TopicHues.personalCredentials,
          () => _openSection(RouteNames.personalCredentials),
        ),
        const SizedBox(height: 14),

        _sectionHeader(context, Icons.home_outlined, 'اموال و بیمه'),
        _tile(
          Icons.directions_car_outlined,
          'خودرو و املاک',
          'پلاک، سند و دارایی‌ها',
          TopicHues.personalAssets,
          () => _openSection(RouteNames.personalAssets),
        ),
        _tile(
          Icons.health_and_safety_outlined,
          'بیمه',
          'بیمه‌های درمان، تکمیلی و عمر',
          TopicHues.personalInsurance,
          () => _openSection(RouteNames.personalInsurance),
        ),
        const SizedBox(height: 14),

        // «ابزارهای شخصی» — the stage-1/2/3 tools. They sit INSIDE this
        // section (same tile recipe, same PIN gate via VaultGuard); there is
        // deliberately no separate hub or dashboard.
        _sectionHeader(context, Icons.handyman_outlined, 'ابزارهای شخصی'),
        _tile(
          Icons.directions_car_outlined,
          'خودرو',
          'سرویس‌ها، کیلومتر، سوخت و هزینه‌ها',
          careCarColor,
          () => _openSection(RouteNames.personalCar),
        ),
        _tile(
          Icons.home_work_outlined,
          'خانه',
          'سرویس‌ها، قبض‌ها، گارانتی و اشتراک‌ها',
          careHomeColor,
          () => _openSection(RouteNames.personalHomeCare),
        ),
        // «دفتر مالی» — stage 2: cheques/installments (tab 1) and the debt
        // ledger (tab 2) in ONE page. No hub, no dashboard.
        _tile(
          Icons.account_balance_wallet_outlined,
          'دفتر مالی',
          'چک و قسط، دَین و طلب، سررسیدها و یادآوری‌ها',
          financeInstallmentColor,
          () => _openSection(RouteNames.personalFinance),
        ),
        // Stage 3: صله رحم و قلک — separate pages, never a hub.
        // (کفاره و فدیه moved into «عبادات و مناسک».)
        _tile(
          Icons.favorite_outline,
          'صله رحم',
          'یادآوری تماس با اقوام، تولدها و ایدهٔ هدیه',
          familyRelativeColor,
          () => _openSection(RouteNames.silatAlRahim),
        ),
        _tile(
          Icons.savings_outlined,
          'قلک',
          'هدف‌های پس‌انداز و واریزها',
          familySavingsColor,
          () => _openSection(RouteNames.personalSavings),
        ),
        const SizedBox(height: 14),

        _sectionHeader(context, Icons.support_outlined, 'امدادی'),
        _tile(
          Icons.emergency_outlined,
          'تماس‌های اضطراری',
          'افراد در دسترس در لحظه نیاز',
          TopicHues.personalEmergency,
          () => _openSection(RouteNames.personalEmergencyContacts),
        ),
        const SizedBox(height: 14),
        // The personal-tools set 2 (kids habits, Quran teacher, shop) moved to
        // the «ابزارها و پیشرفت» grid on the More page — the user's call. The
        // vault keeps ONLY its own data sections.
      ],
    );
  }

  Future<void> _openSection(String route) async {
    await context.push(route);
    if (mounted) ref.invalidate(personalInfoStatsProvider);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(_accent, Colors.white, 0.25) ?? _accent,
            dsContentColor(context, _accent),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صندوق اطلاعات من',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اطلاعات شما رمزنگاری‌شده روی همین دستگاه نگهداری می‌شود.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final statsAsync = ref.watch(personalInfoStatsProvider);
    // A silent SizedBox.shrink for both loading and error made a failed query
    // indistinguishable from a momentary loading flicker. Loading gets a
    // compact spinner; an error gets a small retry row.
    if (statsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (statsAsync.hasError) {
      // One row instead of a bare sentence and a naked «تلاش» button: the
      // panel states what failed and what did not, and carries the retry.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FailureView(
          id: 'personal_info_stats',
          title: 'آمار خوانده نشد',
          detail: 'عضوها و رمزها سر جای خودشان هستند؛ فقط شمارششان انجام نشد.',
          onRetry: () => ref.invalidate(personalInfoStatsProvider),
          layout: FailureLayout.inline,
          error: statsAsync.error,
        ),
      );
    }
    final stats = statsAsync.value;
    if (stats == null) return const SizedBox.shrink();
    final entries = <(IconData, int, String, Color)>[
      (Icons.people_outline, stats.profiles, 'عضو', TopicHues.personalProfile),
      (
        Icons.password_outlined,
        stats.credentials,
        'رمز',
        TopicHues.personalCredentials
      ),
      (
        Icons.directions_car_outlined,
        stats.assets,
        'دارایی',
        TopicHues.personalAssets
      ),
      (
        Icons.health_and_safety_outlined,
        stats.insurances,
        'بیمه',
        TopicHues.personalInsurance
      ),
      (
        Icons.emergency_outlined,
        stats.emergencyContacts,
        'اضطراری',
        TopicHues.personalEmergency
      ),
      (Icons.event_outlined, stats.expiring, 'تاریخ', TopicHues.personalExpiry),
    ];
    final itemWidth =
        ((MediaQuery.of(context).size.width - 32 - 16) / 3).clamp(90.0, 160.0);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, count, label, color) in entries)
          _statCard(icon, count, label, color, itemWidth),
      ],
    );
  }

  Widget _statCard(
      IconData icon, int count, String label, Color color, double width) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 16),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryCard() {
    final t = TimeThemeKit.of(context).palette;
    final items = ref.watch(expiringItemsProvider).value;
    final today = DateTime.now();
    // parse yyyy-mm-dd
    DateTime? parseDate(String iso) {
      try {
        final parts = iso.split('-');
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } catch (e) {
        AppLogger.warning('personal_info_screen', 'operation failed: $e');
        return null;
      }
    }

    // nearest future due (and just-overdue items shown too)
    final soonest = (items ?? const [])
        .where((e) => !e.isArchived)
        .map((e) => (item: e, due: parseDate(e.dueDate)))
        .where((x) => x.due != null)
        .toList()
      ..sort((a, b) => a.due!.compareTo(b.due!));

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openSection(RouteNames.personalExpiry),
      borderColor: _accent.withValues(alpha: 0.35),
      child: Column(
        children: [
          if (soonest.isEmpty)
            Row(
              children: [
                Icon(Icons.event_available, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هیچ تاریخ مهمی ثبت نشده. می‌توانید قسط، کارت، ویزا و '
                    'گواهی‌نامه را با یادآوری پیگیری کنید.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                for (final entry in soonest.take(4))
                  _expiryRow(context, entry.item, entry.due!, today, _accent),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                soonest.isEmpty
                    ? 'افزودن اولین تاریخ مهم'
                    : 'مشاهدهٔ همهٔ تاریخ‌ها',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: dsContentColor(context, _accent),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_left,
                size: 16,
                color: dsContentColor(context, _accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: dsContentColor(context, _accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        borderColor: color.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Reusable expiry row widget.
Widget _expiryRow(BuildContext context, ExpiryItemTableData item, DateTime due,
    DateTime today, Color accent) {
  final daysLeft =
      due.difference(DateTime(today.year, today.month, today.day)).inDays;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final t = TimeThemeKit.of(context).palette;
  final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
  final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
  final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
  final color = daysLeft < 0
      ? danger
      : daysLeft <= 7
          ? warn
          : success;
  final label = daysLeft < 0
      ? '${-daysLeft} روز گذشته'
      : daysLeft == 0
          ? 'امروز'
          : '$daysLeft روز مانده';

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(Icons.av_timer_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: t.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: dsContentColor(context, color),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Общает статус امنیتی و دکمه تغییر PIN / پاک کردن صندوق.
class _SecurityBanner extends ConsumerStatefulWidget {
  final Color accent;
  final VoidCallback onChangedPin;
  const _SecurityBanner({required this.accent, required this.onChangedPin});

  @override
  ConsumerState<_SecurityBanner> createState() => _SecurityBannerState();
}

class _SecurityBannerState extends ConsumerState<_SecurityBanner> {
  bool _pinSet = false;
  bool _showChangePanel = false;
  bool _showDeletePanel = false;
  bool _loaded = false;

  /// Persian (۰-۹) and Arabic-Indic (٠-٩) digits → ASCII.
  static String _normalizeDigits(String raw) =>
      NumberFormat.normalizeDigits(raw.trim());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final set = await PinLockService.isPinSet();
    if (mounted) {
      setState(() {
        _pinSet = set;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    // Guarded refresh: previously _load() was invoked from build(), so every
    // rebuild fired a new async check whose setState triggered another
    // rebuild — an endless setState-during-build loop.
    if (!_loaded) {
      _loaded = true;
      _load();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_pinSet ? success : widget.accent).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (_pinSet ? success : widget.accent).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _pinSet ? Icons.shield_outlined : Icons.shield_outlined,
                color: _pinSet ? success : widget.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pinSet
                      ? 'امنیت فعال است — رمز ورود تعیین شده'
                      : 'برای صندوق «اطلاعات من» رمز ورود تعیین کنید',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_pinSet)
                FilledButton.icon(
                  onPressed: _showSetPinDialog,
                  style: FilledButton.styleFrom(backgroundColor: widget.accent),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('تعیین رمز'),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showChangePanel = !_showChangePanel),
                  icon: const Icon(Icons.refresh_outlined, size: 18),
                  label: const Text('تغییر رمز'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showDeletePanel = !_showDeletePanel),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('پاک کردن صندوق'),
                  style: TextButton.styleFrom(foregroundColor: danger),
                ),
              ],
            ],
          ),
          if (_showChangePanel) ...[
            const SizedBox(height: 10),
            _PinChangeForm(
              onDone: () {
                setState(() {
                  _showChangePanel = false;
                  _pinSet = true;
                });
                widget.onChangedPin();
              },
            ),
          ],
          if (_showDeletePanel) ...[
            const SizedBox(height: 10),
            _PinDeleteForm(
              accent: widget.accent,
              onDone: () {
                setState(() {
                  _showDeletePanel = false;
                  _pinSet = false;
                });
                widget.onChangedPin();
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSetPinDialog() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => const _PinInputDialog(title: 'تعیین رمز ورود'),
    );
    if (pin == null) return;
    if (!mounted) return;
    // Normalize before hashing so a Persian-digit PIN never diverges from the
    // ASCII form the gate later expects.
    final ok = await PinLockService.setPin(_normalizeDigits(pin));
    if (ok && mounted) {
      setState(() => _pinSet = true);
      ref.invalidate(secretVaultProvider);
      widget.onChangedPin();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ذخیرهٔ رمز ورود ممکن نشد. لطفاً دوباره تلاش کنید.'),
      ));
    }
  }
}

class _PinInputDialog extends StatefulWidget {
  final String title;
  const _PinInputDialog({required this.title});

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _ctrl = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                letterSpacing: 12,
                fontSize: AppTheme.scaledFontSize(context, 19)),
            decoration: InputDecoration(
              hintText: 'رمز (2 تا 6 رقم)',
              counterText: '',
              border: const OutlineInputBorder(),
              errorText: _error.isEmpty ? null : _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        FilledButton(
          onPressed: () {
            final val = _ctrl.text.trim();
            if (val.length < 2) {
              setState(() => _error = 'رمز باید حداقل 2 رقم باشد.');
              return;
            }
            Navigator.pop(context, val);
          },
          child: const Text('تأیید'),
        ),
      ],
    );
  }
}

class _PinChangeForm extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _PinChangeForm({required this.onDone});

  @override
  ConsumerState<_PinChangeForm> createState() => _PinChangeFormState();
}

class _PinChangeFormState extends ConsumerState<_PinChangeForm> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  String _error = '';
  bool _busy = false;

  /// Persian/Arabic-Indic digits → ASCII (same rule as the PIN gate).
  static String _normalizePin(String raw) =>
      NumberFormat.normalizeDigits(raw.trim());

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final valid = await PinLockService.verifyPin(_normalizePin(_oldCtrl.text));
    if (!valid) {
      if (mounted) {
        setState(() {
          _error = 'رمز فعلی اشتباه است.';
          _busy = false;
        });
      }
      return;
    }
    final newPin = _normalizePin(_newCtrl.text);
    if (newPin.length < 2) {
      if (mounted) {
        setState(() {
          _error = 'رمز جدید باید حداقل 2 رقم باشد.';
          _busy = false;
        });
      }
      return;
    }
    final ok = await PinLockService.setPin(newPin);
    if (mounted) {
      setState(() => _busy = false);
      if (ok) {
        ref.invalidate(secretVaultProvider);
        widget.onDone();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('رمز تغییر کرد.')));
      } else {
        setState(() {
          _error = 'ذخیرهٔ رمز جدید ممکن نشد. لطفاً دوباره تلاش کنید.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _oldCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'رمز فعلی',
            border: const OutlineInputBorder(),
            errorText: _error.isEmpty ? null : _error,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رمز جدید',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('ثبت رمز جدید'),
          ),
        ),
      ],
    );
  }
}

/// «پاک کردن صندوق» — reset vault (pin + AES key).
class _PinDeleteForm extends ConsumerStatefulWidget {
  final Color accent;
  final VoidCallback onDone;
  const _PinDeleteForm({required this.accent, required this.onDone});

  @override
  ConsumerState<_PinDeleteForm> createState() => _PinDeleteFormState();
}

class _PinDeleteFormState extends ConsumerState<_PinDeleteForm> {
  bool _busy = false;

  Future<void> _confirm() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن صندوق؟'),
        content: const Text(
            'رمز ورود و کلید رمزنگاری حذف می‌شود. داده‌های موجودِ قبلاً '
            'رمزنگاری‌شده دیگر قابل خواندن نخواهند بود. آیا مطمئن هستید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await PinLockService.resetVault();
    if (mounted) {
      ref.invalidate(secretVaultProvider);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('صندوق پاک شد. داده‌های قبلی رمزگشایی نمی‌شوند.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = isDark ? AppTheme.darkError : AppTheme.lightError;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'پاک کردن صندوق، رمز و کلید رمزنگاری را حذف کرده و دسترسی به '
            'داده‌های رمزشده قبلی را ممکن نمی‌کند.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('پاک کردن صندوق'),
          ),
        ],
      ),
    );
  }
}
