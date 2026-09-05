/// Application-wide configuration constants and environment bindings.
///
/// Mirrors the desktop's MAIC_API_URL env-var pattern: a single env-driven
/// endpoint, normalized so callers always get a bare-origin URL.
///
/// Build-time override:
///   flutter build apk --dart-define=MAIC_API_URL=https://staging.maicserver.com
///
/// Runtime override (Phase 5): Settings → Endpoint. Not implemented yet.
class AppConfig {
  AppConfig._();

  /// Default MAIC endpoint (Hetzner canonical).
  /// Override with `--dart-define=MAIC_API_URL=https://other.host` at build time.
  static const String defaultMaicApiUrl = String.fromEnvironment(
    'MAIC_API_URL',
    defaultValue: 'https://api.maicserver.com',
  );

  /// Current MAIC endpoint. Will become mutable once Settings → Endpoint ships.
  static String get maicApiUrl => defaultMaicApiUrl;

  /// User-Agent string sent on every request — matches the desktop pattern
  /// (rc55+ sends "miracle-claw/1.1.0-rc55.18" so MAIC can bucket metrics).
  static const String userAgent = 'miracle-claw-mobile/1.0.0';

  /// Request timeout for chat completions (longer because of streaming).
  static const Duration chatRequestTimeout = Duration(seconds: 90);

  /// Standard request timeout for non-streaming calls.
  static const Duration defaultRequestTimeout = Duration(seconds: 30);
}
