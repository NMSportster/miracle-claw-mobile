import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Callback type for reading the current JWT. Used by the ApiClient's auth
/// interceptor without creating a circular dependency with AuthRepository.
typedef JwtReader = Future<String?> Function();

/// Storage keys — shared between AuthRepository and JwtReader.
const String kAccessTokenKey = 'mcm.access_token';
const String kAccessTokenWrittenAtKey = 'mcm.access_token.written_at_ms';

/// Monotonic counter used to correlate DBG-JWT reads with onRequest /
/// onResponse / silentRelogin entries in `adb logcat`. Bumped on every
/// write/delete of the access token so we can spot races.
int _writeCounter = 0;
int _nextWriteSerial() => ++_writeCounter;

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
///
/// 2026-09-30 diag: every read now logs (a) the storage instance hash,
/// (b) the read result, AND (c) the token's last-write timestamp from a
/// parallel storage key. If two reads of the same key return different
/// results, the parallel-key check tells us whether the underlying
/// SharedPreferences lost BOTH keys (real platform race) or just one
/// (caller side bug).
final jwtReaderProvider = Provider<JwtReader>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final instanceHash = identityHashCode(storage);
  return () async {
    final sw = Stopwatch()..start();
    final t = await storage.read(key: kAccessTokenKey);
    sw.stop();
    final writtenAt = await storage.read(key: kAccessTokenWrittenAtKey);
    final ageMs = writtenAt == null
        ? 'never'
        : (DateTime.now().millisecondsSinceEpoch -
                int.tryParse(writtenAt)!)
            .toString();
    debugPrint(
        '[DBG-JWT] read instance=$instanceHash readMs=${sw.elapsedMilliseconds} '
        'result=${t == null ? "NULL" : "len=${t.length}"} '
        'writtenAtMs=$writtenAt ageMs=$ageMs');
    return t;
  };
});

/// Helper used by AuthRepository to atomically (best-effort) write the
/// access token and a parallel "written-at" timestamp. The parallel
/// timestamp is what makes [jwtReaderProvider]'s ageMs diagnostic
/// meaningful — if the timestamp is missing but the token reads OK,
/// the platform cache is partially stale.
Future<void> writeAccessToken(
  FlutterSecureStorage storage,
  String token,
) async {
  final serial = _nextWriteSerial();
  final now = DateTime.now().millisecondsSinceEpoch.toString();
  debugPrint(
      '[DBG-JWT] write #$serial starting tokenLen=${token.length} ts=$now');
  final sw = Stopwatch()..start();
  await storage.write(key: kAccessTokenKey, value: token);
  await storage.write(key: kAccessTokenWrittenAtKey, value: now);
  sw.stop();
  // Readback sanity — if this fails, the platform cache is already
  // diverging and the next jwtReaderProvider read will also fail.
  final readback = await storage.read(key: kAccessTokenKey);
  debugPrint(
      '[DBG-JWT] write #$serial done in ${sw.elapsedMilliseconds}ms '
      'readback=${readback == null ? "NULL" : (readback.isEmpty ? "EMPTY" : "len=${readback.length} matches=${readback == token}")}');
}

/// Delete both the token and its write timestamp. Used by logout() and
/// by any path that wants to invalidate the cached credential.
Future<void> clearAccessToken(FlutterSecureStorage storage) async {
  final serial = _nextWriteSerial();
  debugPrint('[DBG-JWT] clear #$serial starting');
  await storage.delete(key: kAccessTokenKey);
  await storage.delete(key: kAccessTokenWrittenAtKey);
  final readback = await storage.read(key: kAccessTokenKey);
  debugPrint(
      '[DBG-JWT] clear #$serial done readback=${readback == null ? "NULL" : "STILL_THERE(len=${readback.length})"}');
}

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

