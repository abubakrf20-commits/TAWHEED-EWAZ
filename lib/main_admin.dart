import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tawheeed/admin_web/admin_theme.dart';
import 'package:tawheeed/admin_web/admin_web_app.dart';
import 'package:tawheeed/firebase_options.dart';

/// نقطهٔ ورود جداگانه برای **داشبورد وب مدیر**:
///
///     flutter run -d chrome -t lib/main_admin.dart
///     flutter build web -t lib/main_admin.dart
///
/// این فایل عمداً از lib/main.dart جدا است تا کد پلتفرم (dart:io و …) وارد
/// build وب نشود و تنها dashboard سبک وزنی برای مرورگر ساخته شود.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'پنل مدیر',
      theme: AdminTheme.theme(),
      home: const AdminWebApp(),
    ),
  );
}
