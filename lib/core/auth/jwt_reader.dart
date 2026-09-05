import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Callback type for reading the current JWT. Used by the ApiClient's auth
/// interceptor without creating a circular dependency with AuthRepository.
typedef JwtReader = Future<String?> Function();

/// Storage keys — shared between AuthRepository and JwtReader.
const String kAccessTokenKey = 'mcm.access_token';

/// Provider for the secure storage instance (singleton).
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
