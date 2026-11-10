import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gs;
import 'package:tawheeed/features/settings/services/google_auth_service.dart';

/// Controls who may open the in-app admin panels (suggestion moderation and
/// publishing announcements).
///
/// The real implementation signs in with Firebase Auth and checks the uid
/// against the `adminUids` list in the `config/app` Firestore document. This
/// keeps moderation aligned with the server-side Firestore rules instead of a
/// hard-coded client password.
abstract class AdminGate {
  /// Returns true when the credentials belong to an admin account.
  Future<bool> signIn(String email, String password);

  /// Opens Google's account picker and signs the chosen account into Firebase.
  /// Returns true for an admin, false when the account is missing from
  /// `adminUids`, and null when the user closed the picker (callers stay
  /// silent then).
  Future<bool?> signInWithGoogle();

  /// Returns true when an admin session is already active (e.g. restored
  /// after a restart via the persisted Firebase Auth session).
  Future<bool> isAdminActive();

  Future<void> signOut();
}

class FirebaseAdminGate implements AdminGate {
  static const String configDocPath = 'config/app';

  @override
  Future<bool> signIn(String email, String password) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _acceptIfAdmin(credential.user!.uid);
  }

  /// Reuses [GoogleAuthService] deliberately: it owns the single initialized
  /// `GoogleSignIn` client and the explicit `serverClientId`, so the idToken
  /// here has the same audience as the one the account hub obtains. A second
  /// `initialize()` call site is exactly how that audience drifts.
  @override
  Future<bool?> signInWithGoogle() async {
    try {
      final account = await GoogleAuthService.instance.signIn();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('دریافت توکن هویت از گوگل ناموفق بود.');
      }
      final credential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _acceptIfAdmin(credential.user!.uid);
    } on gs.GoogleSignInException catch (e) {
      // Closing the picker is not a failure — the dialog must stay silent.
      if (e.code == gs.GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<bool> _acceptIfAdmin(String uid) async {
    final uids = await _adminUids();
    if (uids.contains(uid)) return true;
    // Authenticated but not an admin — don't leave a session behind.
    await FirebaseAuth.instance.signOut();
    return false;
  }

  @override
  Future<bool> isAdminActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final uids = await _adminUids();
    return uids.contains(user.uid);
  }

  Future<Set<String>> _adminUids() async {
    final doc = await FirebaseFirestore.instance.doc(configDocPath).get();
    final raw = doc.data()?['adminUids'];
    return raw is List ? raw.map((e) => e.toString()).toSet() : <String>{};
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
