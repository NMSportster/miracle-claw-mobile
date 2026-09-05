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
