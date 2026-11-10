import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tawheeed/admin_web/admin_theme.dart';
import 'package:tawheeed/features/suggestions/domain/entities/suggestion.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// داشبورد وب مدیر برنامه.
///
/// - ورود با حساب گوگل؛ uid باید در `config/app.adminUids` باشد.
/// - تب پیشنهادها: مشاهده/حذف پیام‌های کاربران.
/// - تب اعلان: نگارش اعلان پوش و ثبت در `admin/outbox` تا Cloud Function
///   آن را به کل کاربران (موضوع `all`) بفرستد.
class AdminWebApp extends StatefulWidget {
  const AdminWebApp({super.key});

  @override
  State<AdminWebApp> createState() => _AdminWebAppState();
}

class _AdminWebAppState extends State<AdminWebApp> {
  User? _user;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      final isAdmin = await _isAdminUid(current.uid);
      if (mounted) {
        setState(() {
          if (isAdmin) _user = current;
          _checkingSession = false;
        });
      }
    } else if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _signIn() async {
    try {
      final result = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider(),
      );
      final user = result.user;
      if (user == null) return;
      final isAdmin = await _isAdminUid(user.uid);
      if (!isAdmin) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _showNotice('این حساب گوگل دسترسی مدیر ندارد.');
        return;
      }
      if (mounted) setState(() => _user = user);
    } on FirebaseAuthException catch (e) {
      // Web admin build: AppLogger (dart:io) is unavailable — surfaced in UI.
      if (e.code != 'popup-closed-by-user') {
        if (mounted) _showNotice('خطا در ورود: ${e.message}');
      }
    } catch (e) {
      // Web admin build: AppLogger (dart:io) is unavailable — surfaced in UI.
      if (mounted) _showNotice('ورود ناموفق بود: $e');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => _user = null);
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _user == null ? _buildLogin() : _buildDashboard(),
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 56, color: AdminTheme.primary),
                const SizedBox(height: 12),
                Text('پنل مدیر — توحید',
                    style:
                        TextStyle(fontSize: AppTheme.scaledFontSize(context, 19), fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('برای ادامه با حساب گوگل مدیر وارد شوید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('ورود با گوگل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final user = _user!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminTheme.surface,
        title: const Text('پنل مدیریت'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                user.email ?? user.uid.substring(0, 8),
                style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13), color: Colors.black87),
              ),
            ),
          ),
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: AdminHome(
        onNotice: _showNotice,
      ),
    );
  }
}

/// برخورد صرفاً حالت‌دار برای رنگ پس‌زمینهٔ AppBar وب.
Future<bool> _isAdminUid(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.doc('config/app').get();
    final raw = doc.data()?['adminUids'];
    if (raw is List) return raw.map((e) => e.toString()).contains(uid);
  } catch (_) {
    // Web admin build: AppLogger (dart:io) is unavailable — deny is safe.
    return false;
  }
  return false;
}

/// دو تب: پیشنهادها و اعلان.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.onNotice});

  final void Function(String) onNotice;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.forum_outlined),
                  label: Text('پیشنهادها')),
              ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.notifications_active_outlined),
                  label: Text('اعلان پوش')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _SuggestionsTab(onNotice: widget.onNotice)
              : _PushTab(onNotice: widget.onNotice),
        ),
      ],
    );
  }
}

class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab({required this.onNotice});

  final void Function(String) onNotice;

  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('suggestions')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('خطا: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!.docs
            .map((d) => Suggestion.fromMap(d.id, d.data()))
            .toList();
        if (items.isEmpty) {
          return const Center(
              child: Text('هنوز پیشنهادی ارسال نشده است.',
                  style: TextStyle(color: Colors.black54)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = items[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.text,
                              style:
                                  TextStyle(fontSize: AppTheme.scaledFontSize(context, 14), height: 1.6)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(s.category.persian,
                                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11))),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(s.deviceTag,
                                  style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(context, 11), color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () async {
                        final sure = await showDialog<bool>(
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
                                  child: const Text('حذف')),
                            ],
                          ),
                        );
                        if (sure == true) {
                          await FirebaseFirestore.instance
                              .collection('suggestions')
                              .doc(s.id)
                              .delete();
                          widget.onNotice('حذف شد.');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PushTab extends StatefulWidget {
  const _PushTab({required this.onNotice});

  final void Function(String) onNotice;

  @override
  State<_PushTab> createState() => _PushTabState();
}

class _PushTabState extends State<_PushTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _outboxStream;

  @override
  void initState() {
    super.initState();
    _outboxStream = FirebaseFirestore.instance
        .collection('admin/outbox')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ارسال اعلان به همهٔ کاربران',
                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 15), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'مرورگر نمی‌تواند مستقیم اعلان ارسال کند؛ در سیستم خودتان یک پنجرهٔ ارسال رایگان باز کنید:\n\n'
                  '1) از پوشهٔ برنامه، «start-push.bat» را دبل‌کلیک کنید (یا:  node tools/fcm_server.mjs)\n'
                  '2) مرورگر به‌صورت خودکار باز می‌شود (http://localhost:8787)؛ عنوان و متن را بنویسید و «ارسال به همه» را بزنید.\n'
                  'اعلان با صدای «یادآورها»، آیکن اپ و رنگ طلایی برای همهٔ کاربران ارسال می‌شود؛ '
                  'پیشنهادهای کاربران هم در همان پنجره دیده می‌شود. اینجا فقط تاریخچهٔ ارسال‌های ثبت‌شده در صندوق «admin/outbox» است.',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13), height: 1.7, color: const Color(0xFF5A6472)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('تاریخچهٔ اعلان‌ها',
            style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _outboxStream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('خطا در دریافت تاریخچه: ${snap.error}',
                  style:
                      TextStyle(fontSize: AppTheme.scaledFontSize(context, 12), color: Colors.redAccent));
            }
            if (!snap.hasData) {
              return const SizedBox.shrink();
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Text('هنوز اعلانی ثبت نشده است.',
                  style: TextStyle(color: Colors.black54));
            }
            return Column(
              children: [
                for (final d in docs) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        d.data()['status'] == 'sent'
                            ? Icons.check_circle_outline
                            : Icons.schedule,
                        color: d.data()['status'] == 'sent'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text((d.data()['title'] as String?) ?? ''),
                      subtitle: Text((d.data()['body'] as String?) ?? ''),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
