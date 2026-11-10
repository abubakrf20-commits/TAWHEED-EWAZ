import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// «افراد و خانواده» — لیست پروفایل‌های افراد.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    const accent = TopicHues.personalProfile;
    final profiles = ref.watch(personalProfilesProvider).value;
    final visible = (profiles ?? const [])
        .where((p) =>
            _query.isEmpty ||
            p.name.contains(_query) ||
            p.relation.contains(_query))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'افراد و خانواده'),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن عضو',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: () => context.push(RouteNames.personalProfileEditor),
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: profiles == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 8, DsSpacing.page, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'جستجوی نام یا نسبت…',
                        hintStyle: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: t.textMuted,
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'پاک کردن',
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: t.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: profiles.isEmpty
                        ? const _EmptyState()
                        : visible.isEmpty
                            ? const Center(
                                child: Text('موردی با این جستجو پیدا نشد'))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    DsSpacing.page, 8, DsSpacing.page, 90),
                                itemCount: visible.length,
                                itemBuilder: (context, i) {
                                  final p = visible[i];
                                  return _ProfileCard(
                                      profile: p, accent: accent);
                                },
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final PersonalProfileTableData profile;
  final Color accent;
  const _ProfileCard({required this.profile, required this.accent});

  /// Enters the documents screen bound to this member.
  void _openMemberDocuments(BuildContext context, PersonalProfileTableData p) {
    context.push('${RouteNames.personalDocuments}?profile=${p.id}');
  }

  Future<void> _deleteProfile(
      BuildContext context, WidgetRef ref, PersonalProfileTableData p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این عضو؟'),
        content: Text(
          'با حذف «${p.name}»، پروفایل و همهٔ مدارک و تصاویر او برای همیشه پاک '
          'می‌شود. ادامه می‌دهید؟',
          style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(personalInfoRepositoryProvider);
    final docs = await repo.getDocumentsForProfile(p.id);
    try {
      await repo.deleteProfileWithDocuments(p.id);
    } catch (e) {
      AppLogger.warning('profiles_screen', 'profile delete failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حذف ممکن نشد. دوباره تلاش کنید.')),
        );
      }
      return;
    }
    for (final d in docs) {
      if (d.imagesJson.isNotEmpty) {
        await AttachmentStorage.deleteStoredList(_jsonList(d.imagesJson));
      }
    }
    if (p.avatarPath.isNotEmpty) {
      await AttachmentStorage.deleteStoredFile(p.avatarPath);
    }
    ref.invalidate(personalProfilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${p.name}» حذف شد.')),
      );
    }
  }

  static List<String> _jsonList(String json) {
    if (json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List<dynamic>).whereType<String>().toList();
    } catch (e) {
      AppLogger.warning('profiles_screen', 'operation failed: $e');
      return const [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    // The vault resolves async: during the first frame it is still loading,
    // so a null-aware read keeps the card rendering (id hidden until ready).
    final vault = ref.watch(secretVaultProvider).value;
    final idNum = vault == null ? '' : decryptSafely(vault, profile.nationalId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _openMemberDocuments(context, profile),
        borderColor: accent.withValues(alpha: 0.3),
        child: Row(
          children: [
            _avatar(context, profile, accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  if (profile.relation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.relation,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  if (idNum.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'کد ملی: $idNum',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Edit this member (entering is done by tapping the card).
            IconButton(
              tooltip: 'ویرایش عضو ${profile.name}',
              icon: const Icon(Icons.edit_outlined),
              color: t.textMuted,
              onPressed: () => context.push(
                RouteNames.personalProfileEditor,
                extra: profile,
              ),
            ),
            IconButton(
              tooltip: 'حذف عضو ${profile.name}',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: danger,
              onPressed: () => _deleteProfile(context, ref, profile),
            ),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _avatar(
      BuildContext context, PersonalProfileTableData p, Color accent) {
    if (p.avatarPath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(p.avatarPath),
          width: 46,
          height: 46,
          cacheWidth: (46 * MediaQuery.devicePixelRatioOf(context)).round(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(context, p, accent),
        ),
      );
    }
    return _defaultAvatar(context, p, accent);
  }

  Widget _defaultAvatar(
      BuildContext context, PersonalProfileTableData p, Color accent) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.15)),
      child: Text(
        p.name.isEmpty ? '؟' : p.name.characters.first,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          color: dsContentColor(context, accent),
          fontSize: AppTheme.scaledFontSize(context, 19),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 56),
          const SizedBox(height: 12),
          Text(
            'هنوز عضوی ثبت نشده',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'خودتان یا اعضای خانواده را اضافه کنید\nتا اطلاعات هویتی آن‌ها در صندوق امن بماند.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
