import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/account/data/repositories/account_repository.dart';
import 'package:tawheeed/features/account/data/repositories/firebase_account_repository.dart';

/// Overridable in tests; defaults to the Firebase implementation.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return FirebaseAccountRepository();
});

/// The signed-in user's email, null when signed out.
final accountEmailProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.authStateChanges();
});
