/// Public HTTPS addresses of the store-listing legal pages — the same text
/// that ships in `privacy_policy.md` / `terms_of_service.md`, served from the
/// content repository's `docs/` folder through GitHub Pages.
///
/// The in-app privacy dialog is a summary; the Play listing and anyone reading
/// the policy before installing need a URL that opens in a browser without the
/// app. Keep these three in step with the pages in TAWHEED-EWAZ `docs/`.
abstract final class LegalLinks {
  static const String base =
      'https://abubakrf20-commits.github.io/TAWHEED-EWAZ';

  static const String privacy = '$base/privacy.html';
  static const String terms = '$base/terms.html';
  static const String accountDeletion = '$base/delete-account.html';
}
