/// Endpoints of the audio-library content.
///
/// Out of the box the tracks live in the public ArvanCloud bucket `t.audio`
/// (region `ir-thr-at1`), which needs no credentials and keeps the audio on a
/// domestic host. The Supabase project this used to point at no longer
/// resolves in DNS, and a name that does not resolve is indistinguishable on
/// the device from "you have no internet".
/// The whole host — manifest AND files — can be moved to another bucket or
/// CDN with a single `--dart-define=AUDIO_LIBRARY_BASE_URL=https://…/tawheed`
/// (see docs/AUDIO_LIBRARY_HOSTING.md); nothing else in the app code changes.
class AudioLibraryConfig {
  AudioLibraryConfig._();

  /// Root that every object key is resolved against. Must support HTTP Range
  /// requests for streaming playback.
  ///
  /// Addressed **path-style** on purpose: ArvanCloud's certificate is
  /// `*.s3.<region>.arvanstorage.ir`, which matches exactly one DNS label, so
  /// the virtual-hosted form of a dotted bucket
  /// (`t.audio.s3.<region>.arvanstorage.ir`) puts two labels ahead of `s3` and
  /// the TLS handshake fails. Path style keeps the hostname single-label, and
  /// it is already what [objectUrl] produces from this base.
  static const String _baseEnvKey = 'AUDIO_LIBRARY_BASE_URL';
  static const String storagePublicBaseUrl = String.fromEnvironment(
    _baseEnvKey,
    defaultValue: 'https://s3.ir-thr-at1.arvanstorage.ir/'
        't.audio',
  );

  /// Host of the configured base. Failure messages name it: a dead or
  /// misconfigured host is not the listener's connection, and saying so sends
  /// them into their Wi-Fi settings for nothing.
  static String get host => Uri.parse(storagePublicBaseUrl).host;

  static const String _manifestEnvKey = 'AUDIO_LIBRARY_MANIFEST_URL';

  /// URL of the manifest (bucket-root `index.json`) describing the audio
  /// categories and their tracks.
  ///
  /// [AUDIO_LIBRARY_MANIFEST_URL] still overrides it alone, but when it is not
  /// set the manifest is taken from the same base as the files — otherwise
  /// repointing the base would list tracks from one host and stream them from
  /// another.
  static const String manifestUrl = String.fromEnvironment(
    _manifestEnvKey,
    defaultValue: '$storagePublicBaseUrl/index.json',
  );

  /// Builds the public streamable URL of an object key.
  ///
  /// If [key] is already an absolute URL (`http://`/`https://`) it is returned
  /// as-is, so a category can live on a different host than
  /// [storagePublicBaseUrl] without changing the shared base. Relative keys
  /// (e.g. `yaqeen/01-marefat-shenasi.opus`) are resolved against
  /// [storagePublicBaseUrl] as before — existing content is untouched.
  static String objectUrl(String key) {
    if (key.startsWith('http://') || key.startsWith('https://')) return key;
    final trimmed = key.startsWith('/') ? key.substring(1) : key;
    final encoded = trimmed.split('/').map(Uri.encodeComponent).join('/');
    return '$storagePublicBaseUrl/$encoded';
  }
}
