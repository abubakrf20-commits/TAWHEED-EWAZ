import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/services/drive_backup_service.dart';
import 'package:tawheeed/features/settings/services/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DriveBackupService naming', () {
    test('fileNameFor carries prefix + millis + device label', () {
      final when = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final name = DriveBackupService.fileNameFor(when, '1.6.1+4008');
      expect(name.startsWith(DriveBackupService.filePrefix), isTrue);
      expect(name, contains('1700000000000'));
      expect(name, contains('1.6.1+4008'));
      expect(name, endsWith('.zip'));
    });
  });

  group('GoogleAuthService (offline-safe)', () {
    test('restoreSession returns null when never signed in', () async {
      expect(await GoogleAuthService.instance.restoreSession(), isNull);
      expect(GoogleAuthService.instance.isSignedIn, isFalse);
    });

    test('lastEmail is null on fresh prefs', () async {
      expect(await GoogleAuthService.instance.lastEmail(), isNull);
    });
  });
}
