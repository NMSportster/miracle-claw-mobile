import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Callback type for reading the current JWT. Used by the ApiClient's auth
/// interceptor without creating a circular dependency with AuthRepository.
typedef JwtReader = Future<String?> Function();

/// Storage keys — shared between AuthRepository and JwtReader.
const String kAccessTokenKey = 'mcm.access_token';

/// Provider for the secure storage instance (singleton).
/// Note: `encryptedSharedPreferences: false` because EncryptedSharedPreferences
/// on Android 10 (Samsung) hangs in an infinite retry loop during init.
/// Tradeoff: SharedPreferences values are not encrypted at rest, but they
/// ARE isolated per-app and protected by Android's per-app sandbox. For
/// the JWT-only use case this is acceptable; revisit if storing PII.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
});

/// Provider exposing a JwtReader that reads from secure storage. ApiClient
/// uses this; AuthRepository uses the same storage directly for write paths.
final jwtReaderProvider = Provider<JwtReader>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return () => storage.read(key: kAccessTokenKey);
});

/// Module-level holder for the silent-relogin callback. Set by the
/// authRepositoryProvider's initializer (once AuthRepository is
/// constructed), read by ApiClient's auth interceptor at 401-time.
///
/// This avoids the Riverpod static cycle (apiClientProvider ↔
/// authRepositoryProvider ↔ reloginProvider) that breaks type
/// inference. The interceptor never goes through Riverpod to find
/// the relogin callback — it reads this module-level variable.
///
/// Lifecycle: set in `authRepositoryProvider`'s closure after
/// `AuthRepository` is constructed. Cleared (or left dangling, which
/// is fine) on test tearDown via `clearReloginCallbackForTest`.
Future<bool> Function()? _reloginCallback;

void setReloginCallback(Future<bool> Function() cb) {
  _reloginCallback = cb;
}

/// Used by tests + by the auth interceptor when no callback is wired
/// (returns false → interceptor surfaces the 401 normally).
@visibleForTesting
bool clearReloginCallbackForTest() {
  final had = _reloginCallback != null;
  _reloginCallback = null;
  return had;
}

/// Read by the auth interceptor on a 401. Returns false (no-op) if
/// AuthRepository hasn't wired its callback yet.
Future<bool> Function() getReloginCallback() => _reloginCallback ?? (() async => false);

