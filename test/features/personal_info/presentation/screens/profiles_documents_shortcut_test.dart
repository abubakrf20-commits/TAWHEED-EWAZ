import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/data/repositories/personal_info_repository_impl.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/secret_vault.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/documents_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/photo_gallery_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/profile_editor_screen.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/profiles_screen.dart';
import 'package:tawheeed/features/personal_info/services/secure_cipher.dart';

/// Minimal fake — every method throws except the ones the screens use, so any
/// accidental real-database access fails loudly in tests.
class _FakeRepo implements PersonalInfoRepository {
  final List<PersonalProfileTableData> profiles;
  final Map<String, List<IdentityDocumentTableData>> docsByProfile;

  _FakeRepo({required this.profiles, this.docsByProfile = const {}});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<PersonalProfileTableData>> getAllProfiles() async => profiles;

  @override
  Future<PersonalProfileTableData?> getProfile(String profileId) async {
    for (final p in profiles) {
      if (p.id == profileId) return p;
    }
    return null;
  }

  @override
  Future<List<IdentityDocumentTableData>> getDocumentsForProfile(
          String profileId) async =>
      docsByProfile[profileId] ?? const [];
}

PersonalProfileTableData _profile(String id, String name) {
  final now = DateTime.now();
  return PersonalProfileTableData(
    id: id,
    name: name,
    relation: 'فرزند',
    birthDate: '',
    nationalId: '',
    birthCertNo: '',
    passportNo: '',
    phone: '',
    address: '',
    notes: '',
    colorHex: '',
    avatarPath: '',
    createdAt: now,
    updatedAt: now,
  );
}

IdentityDocumentTableData _doc(String id, String profileId, String title,
    {String imagesJson = ''}) {
  final now = DateTime.now();
  return IdentityDocumentTableData(
    id: id,
    profileId: profileId,
    docType: 'passport',
    title: title,
    documentNo: '',
    issuedPlace: '',
    issuedDate: '',
    expiryDate: '',
    notes: '',
    imagesJson: imagesJson,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpProfiles(WidgetTester tester, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalInfoRepositoryProvider.overrideWithValue(repo),
        // A deterministic in-memory cipher: the profile card decrypts the
        // (empty) national id through it.
        secretVaultProvider.overrideWith(
            (ref) async => SecureCipher.fromBytes(List<int>.filled(32, 7))),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.personalProfiles,
          routes: [
            GoRoute(
              path: RouteNames.personalProfiles,
              builder: (context, state) => const ProfilesScreen(),
            ),
            GoRoute(
              path: RouteNames.personalProfileEditor,
              builder: (context, state) => ProfileEditorScreen(
                profile: state.extra is PersonalProfileTableData
                    ? state.extra! as PersonalProfileTableData
                    : null,
              ),
            ),
            GoRoute(
              path: RouteNames.personalDocuments,
              builder: (context, state) => DocumentsScreen(
                profileId: state.uri.queryParameters['profile'],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each member card exposes an edit-member button', (tester) async {
    final repo = _FakeRepo(
      profiles: [_profile('p1', 'زهرا'), _profile('p2', 'احمد')],
    );
    await _pumpProfiles(tester, repo);

    // One edit button per member with a member-specific tooltip, sitting on
    // the left (trailing) side of the card.
    expect(find.byTooltip('ویرایش عضو زهرا'), findsOneWidget);
    expect(find.byTooltip('ویرایش عضو احمد'), findsOneWidget);
  });

  testWidgets('tapping the member card enters their documents', (tester) async {
    final repo = _FakeRepo(
      profiles: [_profile('p1', 'زهرا')],
      docsByProfile: {
        'p1': [_doc('d1', 'p1', 'پاسپورت زهرا')],
      },
    );
    await _pumpProfiles(tester, repo);

    await tester.tap(find.text('زهرا'));
    await tester.pumpAndSettle();

    // The documents screen opened bound to the member — not the editor.
    expect(find.text('مدارک زهرا'), findsOneWidget);
    expect(find.text('پاسپورت زهرا'), findsOneWidget);
  });

  testWidgets('tapping the edit-member button opens the editor',
      (tester) async {
    final repo = _FakeRepo(profiles: [_profile('p1', 'زهرا')]);
    await _pumpProfiles(tester, repo);

    await tester.tap(find.byTooltip('ویرایش عضو زهرا'));
    await tester.pumpAndSettle();

    expect(find.text('ویرایش عضو'), findsOneWidget);
  });

  testWidgets('document photos show a thumbnail strip that opens the gallery',
      (tester) async {
    final repo = _FakeRepo(
      profiles: [_profile('p1', 'زهرا')],
      docsByProfile: {
        'p1': [
          _doc(
            'd1',
            'p1',
            'پاسپورت زهرا',
            imagesJson: jsonEncode(['c:/x/a.jpg', 'c:/x/b.jpg']),
          ),
        ],
      },
    );
    await _pumpProfiles(tester, repo);

    await tester.tap(find.text('زهرا'));
    await tester.pumpAndSettle();

    expect(find.text('پاسپورت زهرا'), findsOneWidget);
    expect(find.byTooltip('مشاهده عکس 1'), findsOneWidget);
    expect(find.byTooltip('مشاهده عکس 2'), findsOneWidget);

    await tester.tap(find.byTooltip('مشاهده عکس 2'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoGalleryScreen), findsOneWidget);
    expect(find.textContaining('عکس 2 از 2'), findsOneWidget);
    expect(find.byTooltip('ارسال عکس'), findsOneWidget);
  });
}
