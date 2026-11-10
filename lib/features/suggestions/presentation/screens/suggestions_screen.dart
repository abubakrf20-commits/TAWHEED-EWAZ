import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';
import 'package:tawheeed/features/suggestions/presentation/providers/suggestions_providers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/service_unavailable_banner.dart';
import 'package:tawheeed/shared/widgets/expandable_text.dart';

/// حداکثر طول متن پیشنهاد و پاسخ مدیر.
///
/// عمداً در لایهٔ نمایش تعریف شده تا با `request.resource.data.text.size()` در
/// `firestore.rules` هم‌تراز بماند؛ اگر اینجا بزرگ‌تر باشد قوانین نوشتن را رد
/// می‌کنند و کاربر خطای مبهم می‌بیند.
const int kSuggestionMaxTextLength = 2000;
const int kSuggestionMaxNameLength = 40;

/// صفحهٔ «ارسال پیشنهاد».
///
/// پنل مدیریت با **حساب مدیر (Firebase Auth)** باز می‌شود و uid در
/// `config/app.adminUids` بررسی می‌شود — همان چیزی که قوانین امنیتی
/// Firestore سمت سرور اجازه می‌دهد.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  final _textController = TextEditingController();
  final _nameController = TextEditingController();
  SuggestionCategory _category = SuggestionCategory.suggestion;
  bool _sending = false;
  bool _adminUnlocked = false;

  /// پیشنهادهایِ همین نشست برای کاربر عادی. قوانین Firestore اجازهٔ خواندنِ
  /// پیشنهادهایِ شخصی (غیرعمومی) را به کسی جز مدیر نمی‌دهد؛ پس پیشنهادِ
  /// تازه‌فرستاده را همین‌جا نگه می‌داریم تا کاربر بلافاصله پیام خودش را ببیند.
  final List<Suggestion> _localMine = [];

  @override
  void initState() {
    super.initState();
    _restoreAdminSession();
  }

  /// جلسهٔ Firebase Auth روی گوشی ماندگار است؛ اگر مدیر قبلاً وارد شده باشد
  /// دیگر لازم نیست ایمیل/رمز را دوباره تایپ کند.
  Future<void> _restoreAdminSession() async {
    try {
      final ok = await ref.read(adminGateProvider).isAdminActive();
      if (mounted && ok) setState(() => _adminUnlocked = true);
    } catch (_) {
      // Firebase/اینترنت در دسترس نیست — بی‌صدا بگذر.
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.warning(context, 'لطفاً متن پیشنهاد را بنویسید.');
      return;
    }
    setState(() => _sending = true);
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      if (!repo.isAvailable) {
        AppSnackBar.error(context,
            'ارسال پیشنهاد فعلاً در دسترس نیست — بعداً دوباره تلاش کنید.');
        return;
      }
      await repo.submit(
        text: text,
        category: _category,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _localMine.insert(
          0,
          Suggestion(
            id: 'local-${_localMine.length}',
            text: text,
            category: _category,
            deviceTag: '',
            createdAt: DateTime.now(),
            name: _nameController.text.trim(),
          ),
        );
        _textController.clear();
        _nameController.clear();
        _category = SuggestionCategory.suggestion;
      });
      AppSnackBar.success(context, 'پیشنهاد شما با موفقیت ارسال شد. سپاس!');
    } catch (_) {
      AppLogger.warning('suggestions_screen', 'operation failed');
      if (!mounted) return;
      AppSnackBar.error(context,
          'ارسال ناموفق بود؛ اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _promptAdminLogin() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var error = '';
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> submit() async {
              if (busy) return;
              setDialogState(() {
                busy = true;
                error = '';
              });
              try {
                final ok = await ref
                    .read(adminGateProvider)
                    .signIn(emailCtrl.text, passCtrl.text);
                if (!dialogCtx.mounted) return;
                if (!mounted) return;
                if (ok) {
                  setState(() => _adminUnlocked = true);
                  Navigator.of(dialogCtx).pop();
                } else {
                  setDialogState(() {
                    error = 'این حساب دسترسی مدیر ندارد.';
                    busy = false;
                  });
                  passCtrl.clear();
                }
              } catch (_) {
                AppLogger.warning('suggestions_screen', 'operation failed');
                if (!dialogCtx.mounted) return;
                setDialogState(() {
                  error = 'ورود ناموفق بود؛ ایمیل یا رمز را بررسی کنید.';
                  busy = false;
                });
                passCtrl.clear();
              }
            }

            Future<void> submitWithGoogle() async {
              if (busy) return;
              setDialogState(() {
                busy = true;
                error = '';
              });
              try {
                final ok = await ref.read(adminGateProvider).signInWithGoogle();
                if (!dialogCtx.mounted) return;
                if (!mounted) return;
                if (ok == null) {
                  // کاربر انتخاب‌گر را بست — خطایی نشان نده.
                  setDialogState(() => busy = false);
                } else if (ok) {
                  setState(() => _adminUnlocked = true);
                  Navigator.of(dialogCtx).pop();
                } else {
                  setDialogState(() {
                    error = 'این حساب دسترسی مدیر ندارد.';
                    busy = false;
                  });
                }
              } catch (e) {
                AppLogger.warning(
                    'suggestions_screen', 'google login failed: $e');
                if (!dialogCtx.mounted) return;
                setDialogState(() {
                  error = 'ورود با گوگل ناموفق بود؛ دوباره تلاش کنید.';
                  busy = false;
                });
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Theme.of(dialogCtx).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('ورود مدیر',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'فقط حساب مدیر برنامه می‌تواند پیشنهادها را ببیند و حذف کند.\n\nپس از اولین ورود، جلسه روی گوشی شما می‌ماند و دیگر نیازی به ورود مجدد نیست.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: TimeThemeKit.of(dialogCtx).palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل مدیر',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('یا',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: TimeThemeKit.of(dialogCtx)
                                    .palette
                                    .textMuted)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : submitWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 26),
                      label: const Text('ورود با حساب گوگل'),
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: Theme.of(dialogCtx).colorScheme.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                      foregroundColor: Colors.white),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ورود'),
                ),
              ],
            );
          },
        );
      },
    );
    // Deferred one frame: the dialog's TextFields dispose themselves during
    // this frame's finalizeTree — disposing the controllers any earlier
    // races with that ("A TextEditingController was used after being
    // disposed").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailCtrl.dispose();
      passCtrl.dispose();
    });
  }

  Future<void> _lockAdmin() async {
    setState(() => _adminUnlocked = false);
    await ref.read(adminGateProvider).signOut();
  }

  Future<void> _confirmDelete(Suggestion s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف پیشنهاد'),
        content: Text('«${s.text}» برای همیشه حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(suggestionsRepositoryProvider).delete(s.id);
      if (mounted) AppSnackBar.success(context, 'حذف شد.');
    } catch (_) {
      AppLogger.warning('suggestions_screen', 'operation failed');
      if (mounted) {
        AppSnackBar.error(context, 'حذف ناموفق بود؛ دوباره تلاش کنید.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final repo = ref.watch(suggestionsRepositoryProvider);
    final available = repo.isAvailable;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'ارسال پیشنهاد'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'خوشحال می‌شویم نظر شما را بشنویم؛ پیشنهادها و گزارش خطا به بهبود برنامه کمک می‌کند.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            // وقتی Firebase راه‌اندازی نیست، فرم نمایش داده می‌شود ولی ارسال
            // ناموفق است؛ بنرِ صریح، حالت را به‌جای یک خطای بعد از لمس، از
            // همان ابتدا شفاف می‌کند.
            if (!available) ...[
              const ServiceUnavailableBanner(
                detail: 'ارسال پیشنهاد و بخش‌های آنلاین این صفحه به سرویس ابری '
                    'متصل‌اند که هم‌اکنون در دسترس نیست. متن شما ارسال نخواهد '
                    'شد؛ اتصال اینترنت را بررسی کنید و دوباره وارد شوید.',
              ),
              const SizedBox(height: 16),
            ],
            _card(
              context,
              children: [
                // ── دسته‌بندی ──
                Text('موضوع پیام',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 'other' is kept in the enum only so legacy Firestore
                    // records still render; it is no longer offered here.
                    for (final c in SuggestionCategory.values
                        .where((c) => c != SuggestionCategory.other))
                      ChoiceChip(
                        label: Text(c.persian),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── نام اختیاری ──
                TextField(
                  controller: _nameController,
                  maxLength: kSuggestionMaxNameLength,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'نام شما (اختیاری)',
                    hintText: 'برای اینکه بتوانیم پاسخ را خطاب به شما بدهیم',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // ── متن ──
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  maxLength: kSuggestionMaxTextLength,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'متن پیشنهاد',
                    hintText: 'پیام خود را بنویسید…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_sending ? 'در حال ارسال…' : 'ارسال پیشنهاد'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── پیشنهادهای من (برای دیدن پاسخ مدیر) ──
            if (available) ...[
              _sectionTitle(context, Icons.inbox_outlined, 'پیشنهادهای من'),
              const SizedBox(height: 8),
              _buildMySuggestions(context),
              const SizedBox(height: 20),
              _sectionTitle(context, Icons.public_outlined, 'پیشنهادهای عمومی'),
              const SizedBox(height: 8),
              _buildPublicSuggestions(context),
              const SizedBox(height: 20),
            ],
            // ── پنل مدیریت ──
            _adminHeader(context, available),
            const SizedBox(height: 8),
            if (_adminUnlocked) ...[
              _buildAdminPanel(context, available),
            ] else if (available) ...[
              _card(
                context,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.lock_open_outlined,
                            size: 20, color: t.primary),
                      ),
                      title: Text('ورود به پنل مدیریت',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'مشاهده و حذف پیشنهادهای کاربران (فقط مدیر)',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: t.textMuted)),
                      trailing: Icon(Icons.chevron_left,
                          size: 18, color: t.textMuted),
                      onTap: _promptAdminLogin,
                    ),
                  ),
                ],
              ),
            ],
            if (!available) ...[
              const SizedBox(height: 12),
              const ServiceUnavailableBanner(
                detail: 'پنل مدیریت هم به همین سرویس وابسته است و تا برقراری '
                    'اتصال غیرفعال می‌ماند.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Icon(icon, size: 20, color: t.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildMySuggestions(BuildContext context) {
    if (!_adminUnlocked) {
      // کاربر عادی فقط پیشنهادهایِ همین نشست را می‌بیند؛ پاسخی که مدیر
      // برایش بنویسد، اگر عمومی منتشر شود در بخش «پیشنهادهای عمومی» ظاهر می‌شود.
      if (_localMine.isEmpty) {
        return _emptyState(
            context, Icons.inbox_outlined, 'هنوز پیشنهادی نفرستاده‌اید.');
      }
      return _card(
        context,
        children: [
          for (final s in _localMine) ...[
            _mySuggestionRow(context, s),
            const Divider(height: 1),
          ],
        ],
      );
    }
    final stream = ref.watch(mySuggestionsStreamProvider);
    return stream.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator())),
      // A failed read used to be drawn as an *empty* state, which told a
      // reader with sent suggestions that they had never sent any.
      error: (e, _) => _errorState(
        context,
        'دریافت پیشنهادهای شما ممکن نشد',
        id: 'suggestions_mine',
        onRetry: () => ref.invalidate(mySuggestionsStreamProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
              context, Icons.inbox_outlined, 'هنوز پیشنهادی نفرستاده‌اید.');
        }
        return _card(
          context,
          children: [
            for (final s in items) ...[
              _mySuggestionRow(context, s),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Widget _mySuggestionRow(BuildContext context, Suggestion s) {
    final t = TimeThemeKit.of(context).palette;
    final j = Jalali.fromDateTime(s.createdAt);
    final name = s.name.trim().isEmpty ? 'شما' : s.name.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _senderBadge(context, name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    const SizedBox(height: 2),
                    Text(jalaliYmdShort(j),
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: t.textMuted)),
                  ],
                ),
              ),
              _categoryBadge(context, s.category),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            s.text,
            maxLines: 2,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.7,
                color: t.textPrimary),
          ),
          if (s.hasReply) ...[
            const SizedBox(height: 8),
            _replyBubble(context, s.reply),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 12, color: t.textMuted),
                const SizedBox(width: 4),
                Text('در انتظار پاسخ برنامه…',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPublicSuggestions(BuildContext context) {
    final stream = ref.watch(publicSuggestionsStreamProvider);
    return stream.when(
      // An invisible area while a network read runs reads as «nothing here».
      // A small ring says the feed is still on its way.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      ),
      error: (e, _) => _errorState(
        context,
        'دریافت پیشنهادهای عمومی ممکن نشد',
        id: 'suggestions_public',
        onRetry: () => ref.invalidate(publicSuggestionsStreamProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(context, Icons.public_off_outlined,
              'هنوز پیشنهاد عمومی منتشر نشده است.');
        }
        return _card(
          context,
          children: [
            for (final s in items) ...[
              _publicSuggestionRow(context, s),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Widget _publicSuggestionRow(BuildContext context, Suggestion s) {
    final t = TimeThemeKit.of(context).palette;
    final j = Jalali.fromDateTime(s.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _senderBadge(context, s.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.senderLabel,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    const SizedBox(height: 2),
                    Text(jalaliYmdShort(j),
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: t.textMuted)),
                  ],
                ),
              ),
              _categoryBadge(context, s.category),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            s.text,
            maxLines: 2,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.7,
                color: t.textPrimary),
          ),
          if (s.hasReply) ...[
            const SizedBox(height: 8),
            _replyBubble(context, s.reply),
          ],
        ],
      ),
    );
  }

  Future<void> _promptReply(Suggestion s) async {
    // کنترلر متن را خودِ دیالوگ می‌سازد و می‌بندد؛ اگر اینجا
    // بلافاصله پس از بازگشتِ showDialog آن را dispose کنیم، هنوز هنگام
    // انیمیشن خروج دیالوگ استفاده می‌شود و خطا می‌دهد.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _ReplyDialog(suggestionText: s.text, initialReply: s.reply),
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await ref.read(suggestionsRepositoryProvider).reply(s.id, result);
      if (mounted) AppSnackBar.success(context, 'پاسخ ثبت شد.');
    } catch (e) {
      AppLogger.error('SuggestionsScreen', 'reply failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'ثبت پاسخ ناموفق بود؛ دوباره تلاش کنید.');
      }
    }
  }

  Future<void> _togglePublic(Suggestion s, bool value) async {
    try {
      await ref.read(suggestionsRepositoryProvider).setPublic(s.id, value);
      if (mounted) {
        AppSnackBar.success(context,
            value ? 'به‌صورت عمومی منتشر شد.' : 'انتشار عمومی لغو شد.');
      }
    } catch (e) {
      AppLogger.error('SuggestionsScreen', 'toggle public failed: $e');
      if (mounted) {
        AppSnackBar.error(context, 'تغییر ناموفق بود؛ دوباره تلاش کنید.');
      }
    }
  }

  Widget _adminHeader(BuildContext context, bool available) {
    final t = TimeThemeKit.of(context).palette;
    final canLockBack = _adminUnlocked;
    return Row(
      children: [
        Icon(Icons.admin_panel_settings_outlined, size: 20, color: t.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('پنل مدیریت',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
        ),
        if (canLockBack)
          TextButton(
            onPressed: _lockAdmin,
            child: const Text('قفل'),
          ),
      ],
    );
  }

  Widget _buildAdminPanel(BuildContext context, bool available) {
    final t = TimeThemeKit.of(context).palette;
    final stream = ref.watch(suggestionsStreamProvider);
    return stream.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      // The admin list used to print the exception itself («خطا در دریافت
      // پیشنهادها: $e») and offer nothing to do about it.
      error: (e, _) => _errorState(
        context,
        'دریافت پیشنهادها ممکن نشد',
        id: 'suggestions_admin',
        onRetry: () => ref.invalidate(suggestionsStreamProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _card(
            context,
            children: [
              Text(
                'هنوز پیشنهادی ارسال نشده است.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textMuted),
              ),
            ],
          );
        }
        return _card(
          context,
          children: [
            for (final s in items) ...[
              _suggestionRow(context, s),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Widget _suggestionRow(BuildContext context, Suggestion s) {
    final t = TimeThemeKit.of(context).palette;
    final j = Jalali.fromDateTime(s.createdAt);
    final date = jalaliYmdShort(j);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _senderBadge(context, s.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('از ${s.senderLabel}',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _categoryBadge(context, s.category),
                        Text(date,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 10),
                                color: t.textMuted)),
                        if (s.isPublic) _publicBadge(context),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.hasReply ? 'ویرایش پاسخ' : 'پاسخ',
                icon: Icon(s.hasReply ? Icons.edit_outlined : Icons.reply,
                    color: t.primary),
                onPressed: () => _promptReply(s),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                onPressed: () => _confirmDelete(s),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            s.text,
            maxLines: 3,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.7,
                color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      s.hasReply
                          ? Icons.reply_all_outlined
                          : Icons.schedule_outlined,
                      size: 14,
                      color: s.hasReply ? t.primary : t.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.hasReply ? 'پاسخ: ${s.reply}' : 'بدون پاسخ',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            height: 1.5,
                            color: s.hasReply ? t.primary : t.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('انتشار عمومی',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted)),
              Switch(
                value: s.isPublic,
                onChanged: (v) => _togglePublic(s, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, IconData icon, String message) {
    final t = TimeThemeKit.of(context).palette;
    return _card(
      context,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, size: 28, color: t.textMuted.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  /// A failed read, said as a failure and not as «nothing was published» —
  /// with the one action that can fix it.
  Widget _errorState(
    BuildContext context,
    String title, {
    required VoidCallback onRetry,
    String id = 'suggestions_load',
  }) {
    return FailureView(
      id: id,
      title: title,
      detail: 'پیشنهادهای فرستاده‌شده پاک نشده‌اند؛ فقط این فهرست باز نشد.',
      onRetry: onRetry,
      layout: FailureLayout.page,
      icon: Icons.cloud_off_outlined,
    );
  }

  Widget _senderBadge(BuildContext context, String name) {
    final t = TimeThemeKit.of(context).palette;
    final initial = _initial(name);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.person_outline, size: 20, color: t.primary)
            : Text(initial,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w700,
                    color: t.primaryStrong)),
      ),
    );
  }

  String _initial(String name) {
    final n = name.trim();
    if (n.isEmpty) return '';
    return String.fromCharCodes(n.runes.take(1));
  }

  /// هر دسته رنگ اختصاصی دارد تا «گزارش مشکل» از «پیشنهاد» خوانا جدا شود.
  Color _categoryColor(BuildContext context, SuggestionCategory c) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;
    return switch (c) {
      SuggestionCategory.suggestion => t.primary,
      SuggestionCategory.complaint => warning,
      SuggestionCategory.bug => error,
      SuggestionCategory.other => t.textMuted,
    };
  }

  Widget _categoryBadge(BuildContext context, SuggestionCategory c) {
    final color = _categoryColor(context, c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(c.persian,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w700,
              color: dsContentColor(context, color))),
    );
  }

  Widget _publicBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.doneColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('عمومی',
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w700,
              color: AppTheme.doneColor)),
    );
  }

  /// حباب «پاسخ برنامه» با متن قابل بازشدن برای پاسخ‌های بلند.
  Widget _replyBubble(BuildContext context, String reply) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply, size: 14, color: t.primary),
              const SizedBox(width: 6),
              Text('پاسخ برنامه',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: t.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ExpandableText(
            reply,
            maxLines: 3,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.7,
                color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkOutline
                : AppTheme.lightOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// دیالوگ ثبت پاسخ مدیر؛ کنترلر متن را خودش نگه می‌دارد تا در چرخهٔ عمر
/// درست آزاد شود.
class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog(
      {required this.suggestionText, required this.initialReply});

  final String suggestionText;
  final String initialReply;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialReply);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AlertDialog(
      title: const Text('پاسخ به پیشنهاد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('«${widget.suggestionText}»',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 4,
            maxLength: kSuggestionMaxTextLength,
            decoration: const InputDecoration(
              labelText: 'متن پاسخ',
              hintText:
                  'این پاسخ در بخش «پیشنهادهای من» به فرستنده نشان داده می‌شود.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('ثبت پاسخ'),
        ),
      ],
    );
  }
}
