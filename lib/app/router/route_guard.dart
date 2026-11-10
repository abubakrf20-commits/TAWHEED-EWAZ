/// Locations that are **not** app routes.
///
/// A home-screen widget's click (Jetpack Glance) reaches Android as a
/// trampoline intent whose data is `glance-action:/CALLBACK?appWidgetId=…`.
/// Depending on the launcher and the OS version, Flutter can receive that as
/// its *initial* route — sometimes with the scheme, sometimes only as a bare
/// `CALLBACK` path. Either way it is not a page of this app, and GoRouter used
/// to answer it with the Persian «صفحه پیدا نشد» screen **before** the splash
/// gate had a chance to run: the app appeared to open on a 404.
///
/// The app owns exactly one scheme (`tawheed`) and every real route starts with
/// `/`. Anything else is foreign and must be sent through the splash gate.
bool isForeignLocation(Uri uri) {
  if (uri.scheme.isNotEmpty && uri.scheme != 'tawheed') return true;
  final path = uri.path;
  if (path.isEmpty) return false;
  // The Glance trampoline: `/CALLBACK?appWidgetId=…` or `CALLBACK?…`.
  if (path == 'CALLBACK' || path.startsWith('/CALLBACK')) return true;
  // A relative path can never match a GoRoute.
  return !path.startsWith('/');
}
