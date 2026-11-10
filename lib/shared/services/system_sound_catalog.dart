import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One tone the phone itself offers.
@immutable
class SystemSound {
  const SystemSound({
    required this.kind,
    required this.title,
    required this.uri,
  });

  /// `notification`, `alarm` or `ringtone` — see [SoundChoice].
  final String kind;
  final String title;
  final String uri;

  String get wire => SoundChoice.system(kind, uri);
}

/// Reads the device's own notification / alarm / ringtone lists once per
/// process and remembers the titles so a saved `system:` choice can show the
/// same name the picker showed.
///
/// The query is read-only system data and needs no permission; the titles are
/// already localized by Android.
class SystemSoundCatalog extends ChangeNotifier {
  SystemSoundCatalog._();

  static final SystemSoundCatalog instance = SystemSoundCatalog._();

  static const MethodChannel _channel = MethodChannel('com.tawheeed/azan');

  Map<String, List<SystemSound>> _byKind =
      const <String, List<SystemSound>>{};
  bool _loaded = false;
  bool _loading = false;
  Object? _error;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  Object? get error => _error;

  List<SystemSound> ofKind(String kind) =>
      _byKind[kind] ?? const <SystemSound>[];

  List<SystemSound> get notifications => ofKind(SoundChoice.kindNotification);
  List<SystemSound> get alarms => ofKind(SoundChoice.kindAlarm);
  List<SystemSound> get ringtones => ofKind(SoundChoice.kindRingtone);

  /// The display title for a saved URI, or null when it is not in the list
  /// (a tone removed since the reminder was saved).
  String? titleOf(String? uri) {
    if (uri == null || uri.isEmpty) return null;
    for (final list in _byKind.values) {
      for (final s in list) {
        if (s.uri == uri) return s.title;
      }
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
          'listSystemSounds');
      final next = <String, List<SystemSound>>{};
      for (final kind in const [
        SoundChoice.kindNotification,
        SoundChoice.kindAlarm,
        SoundChoice.kindRingtone,
      ]) {
        final rows = raw?[kind];
        if (rows is! List) continue;
        final sounds = <SystemSound>[];
        for (final row in rows) {
          if (row is! Map) continue;
          final uri = row['uri']?.toString() ?? '';
          if (uri.isEmpty) continue;
          final title = row['title']?.toString() ?? '';
          sounds.add(SystemSound(
            kind: kind,
            title: title.isEmpty ? uri.substring(uri.lastIndexOf('/') + 1) : title,
            uri: uri,
          ));
        }
        next[kind] = sounds;
      }
      _byKind = next;
      _loaded = true;
    } catch (e) {
      _error = e;
      _loaded = true;
      AppLogger.warning('SystemSoundCatalog', 'list system sounds failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
