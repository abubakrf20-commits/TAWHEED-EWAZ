import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ویرایشگر پروفایل فرد — افزودن یا ویرایش (از طریق [extra]).
class ProfileEditorScreen extends ConsumerStatefulWidget {
  final PersonalProfileTableData? profile;
  const ProfileEditorScreen({super.key, this.profile});

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final Color _accent = TopicHues.personalProfile;

  late final _nameCtrl =
      TextEditingController(text: widget.profile?.name ?? '');
  late final _relationCtrl =
      TextEditingController(text: widget.profile?.relation ?? '');
  late final _birthCtrl =
      TextEditingController(text: widget.profile?.birthDate ?? '');
  late final _nationalIdCtrl =
      TextEditingController(text: widget.profile?.nationalId ?? '');
  late final _birthCertCtrl =
      TextEditingController(text: widget.profile?.birthCertNo ?? '');
  late final _passportCtrl =
      TextEditingController(text: widget.profile?.passportNo ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.profile?.phone ?? '');
  late final _addressCtrl =
      TextEditingController(text: widget.profile?.address ?? '');
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.profile?.avatarPath ?? '';
    final vault = ref.read(secretVaultProvider).asData?.value;
    if (vault != null) {
      var v = widget.profile?.nationalId ?? '';
      if (v.isNotEmpty) _nationalIdCtrl.text = vault.decrypt(v);
      v = widget.profile?.birthCertNo ?? '';
      if (v.isNotEmpty) _birthCertCtrl.text = vault.decrypt(v);
      v = widget.profile?.passportNo ?? '';
      if (v.isNotEmpty) _passportCtrl.text = vault.decrypt(v);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationCtrl.dispose();
    _birthCtrl.dispose();
    _nationalIdCtrl.dispose();
    _birthCertCtrl.dispose();
    _passportCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final src = await _pathFor(result.first);
    if (src.isEmpty) return;
    final saved = await AttachmentStorage.storeFile(src, 'avatar');
    if (saved.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('فایل انتخابی پذیرفته نشد (حداکثر 10 مگابایت).')));
      }
      return;
    }
    if (mounted) {
      if (_avatarPath.isNotEmpty) {
        await AttachmentStorage.deleteStoredFile(_avatarPath);
      }
      setState(() => _avatarPath = saved);
    }
  }

  /// Resolves a picker file to a real disk path; some Android providers only
  /// expose a content stream, so those are copied to a temp file first.
  static Future<String> _pathFor(PlatformFile f) async {
    final direct = f.path;
    if (direct != null) return direct;
    try {
      final tmp = File('${Directory.systemTemp.path}/${f.name}');
      await tmp.openWrite().addStream(f.readAsByteStream());
      return tmp.path;
    } catch (e) {
      AppLogger.warning('profile_editor_screen', 'stream copy failed: $e');
      return '';
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('نام را وارد کنید.')));
      return;
    }
    final vault = await ref.read(secretVaultProvider.future);
    final now = DateTime.now();
    String enc(String v) => vault.encrypt(v);

    final entry = PersonalProfileTableCompanion(
      id: Value(widget.profile?.id ??
          DateTime.now().millisecondsSinceEpoch.toString()),
      name: Value(name),
      relation: Value(_relationCtrl.text.trim()),
      birthDate: Value(_birthCtrl.text.trim()),
      nationalId: Value(enc(_nationalIdCtrl.text.trim())),
      birthCertNo: Value(enc(_birthCertCtrl.text.trim())),
      passportNo: Value(enc(_passportCtrl.text.trim())),
      phone: Value(_phoneCtrl.text.trim()),
      address: Value(_addressCtrl.text.trim()),
      avatarPath: Value(_avatarPath),
      updatedAt: Value(now),
      createdAt: Value(widget.profile?.createdAt ?? now),
    );
    final repo = ref.read(personalInfoRepositoryProvider);
    await repo.upsertProfile(entry);
    ref.invalidate(personalProfilesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.profile == null ? 'افزودن عضو' : 'ویرایش عضو',
        actions: [
          if (widget.profile != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              tooltip: 'حذف عضو',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'ذخیرهٔ عضو',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 40),
          children: [
            // Avatar picker
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _buildAvatar(),
                  Semantics(
                    button: true,
                    label: 'انتخاب تصویر پروفایل',
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.surface, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _field(_nameCtrl, 'نام و نام خانوادگی *', Icons.person_outline),
            _field(_relationCtrl, 'نسبت / نقش (خودم، همسر، پدر…)',
                Icons.family_restroom_outlined),
            _field(_birthCtrl, 'تاریخ تولد', Icons.cake_outlined),
            _field(_nationalIdCtrl, 'کد ملی', Icons.badge_outlined,
                encrypted: true),
            _field(_birthCertCtrl, 'شماره شناسنامه', Icons.menu_book_outlined,
                encrypted: true),
            _field(_passportCtrl, 'شماره پاسپورت', Icons.fingerprint_outlined,
                encrypted: true),
            _field(_phoneCtrl, 'شماره تماس', Icons.phone_outlined),
            _field(_addressCtrl, 'نشانی', Icons.home_outlined),
            if (_hasSensitive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: _accent),
                  const SizedBox(width: 6),
                  Text(
                    'کد ملی، شناسنامه و پاسپورت رمزنگاری می‌شوند.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasSensitive =>
      _nationalIdCtrl.text.isNotEmpty ||
      _birthCertCtrl.text.isNotEmpty ||
      _passportCtrl.text.isNotEmpty;

  Widget _buildAvatar() {
    const size = 96.0;
    if (_avatarPath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(_avatarPath),
          width: size,
          height: size,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(size),
        ),
      );
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_outline,
          size: 40, color: dsContentColor(context, _accent)),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool encrypted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: _accent),
          border: const OutlineInputBorder(),
          suffixIcon:
              encrypted ? const Icon(Icons.lock_outline, size: 16) : null,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این عضو؟'),
        content: const Text(
            'پروفایل و مدارک متصل به آن حذف می‌شود. این عمل قابل بازگشت نیست.'),
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
    if (ok != true || widget.profile == null) return;
    final repo = ref.read(personalInfoRepositoryProvider);
    final avatar = widget.profile!.avatarPath;
    // Remove the DB rows first: a failure must not leave the profile
    // pointing at photos that no longer exist.
    await repo.deleteProfileWithDocuments(widget.profile!.id);
    if (avatar.isNotEmpty) {
      await AttachmentStorage.deleteStoredFile(avatar);
    }
    if (mounted) Navigator.pop(context);
  }
}
