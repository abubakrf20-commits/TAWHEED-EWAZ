import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_prefs_provider.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPrefs(Ref ref) =>
    SharedPreferences.getInstance();
