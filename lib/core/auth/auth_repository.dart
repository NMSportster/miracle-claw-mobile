import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import 'jwt_reader.dart';

export 'jwt_reader.dart';

/// Auth state — drives whether the app shows login or main UI.
enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.user, this.error});
  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  AuthState copyWith({AuthStatus? status, UserProfile? user, String? error}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user, error: error);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.tier,
    required this.emailVerified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        email: json['email'] as String,
        name: json['name'] as String? ?? '',
        tier: json['tier'] as String? ?? 'free',
        emailVerified: json['email_verified'] as bool? ?? false,
      );

  final int id;
  final String email;
  final String name;
  final String tier;
  final bool emailVerified;
}

/// Single source of truth for auth state + JWT storage.
///
/// Mirrors the desktop's `auto_relogin.rs` flow: JWT in OS-backed secure
/// storage, optional email+password cache for silent relogin on 401.
class AuthRepository {
  AuthRepository(this._storage, this._apiClient);

  final FlutterSecureStorage _storage;
  final ApiClient _apiClient;

  static const _kRememberEmail = 'mcm.remember_email';
  static const _kRememberPassword = 'mcm.remember_password';

  /// Persisted email only — used to pre-fill the login form.
  Future<String?> readRememberedEmail() => _storage.read(key: _kRememberEmail);

  /// POST /v1/users/login → store JWT (and optionally credentials for relogin).
  Future<UserProfile> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/users/login',
      data: {'email': email.trim(), 'password': password},
    );

    if (response.statusCode != 200 || response.data == null) {
      final detail = response.data is Map ? response.data!['detail'] : null;
      throw ApiException(
        response.statusCode,
        detail?.toString() ?? 'Login failed',
        body: response.data,
      );
    }

    final body = response.data!;
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException(response.statusCode, 'No token in login response');
    }

    await writeAccessToken(_storage, token);
    if (rememberMe) {
      await _storage.write(key: _kRememberEmail, value: email.trim());
      await _storage.write(key: _kRememberPassword, value: password);
    } else {
      await _storage.delete(key: _kRememberEmail);
      await _storage.delete(key: _kRememberPassword);
    }

    return UserProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  /// Try to relogin using cached credentials. Returns true if successful.
  /// Mirrors desktop's `silent_relogin` Tauri command.
  Future<bool> silentRelogin() async {
    final sw = Stopwatch()..start();
    try {
      final email = await _storage.read(key: _kRememberEmail);
      final password = await _storage.read(key: _kRememberPassword);
      final haveCreds = email != null && password != null;
      debugPrint(
          '[DBG-AUTH] silentRelogin start haveCreds=$haveCreds emailLen=${email?.length ?? 0}');
      if (!haveCreds) return false;

      // Use a fresh, bare Dio for the login call so the auth interceptor
      // doesn't try to attach the stale Bearer token we're trying to
      // replace. Setting `Options(headers: {'Authorization': null})` on
      // the shared `_apiClient.dio` is a known Dio 5 footgun — null
      // headers don't actually remove; they get merged as null and
      // some adapters re-add the default. A bare Dio has no
      // interceptors, no base auth header, nothing.
      final loginDio = Dio(BaseOptions(
        baseUrl: _apiClient.dio.options.baseUrl,
        connectTimeout: _apiClient.dio.options.connectTimeout,
        receiveTimeout: _apiClient.dio.options.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': _apiClient.dio.options.headers['User-Agent'],
        },
        validateStatus: (s) => s != null && s < 500,
      ));

      final response = await loginDio.post<Map<String, dynamic>>(
        '/v1/users/login',
        data: {'email': email, 'password': password},
      );
      sw.stop();
      debugPrint(
          '[DBG-AUTH] silentRelogin login response status=${response.statusCode} '
          'elapsed=${sw.elapsedMilliseconds}ms');

      if (response.statusCode != 200 || response.data == null) {
        debugPrint(
            '[DBG-AUTH] silentRelogin FAILED status=${response.statusCode} '
            'body=${response.data}');
        return false;
      }
      final token = response.data!['token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint(
            '[DBG-AUTH] silentRelogin FAILED no-token body=${response.data}');
        return false;
      }

      await writeAccessToken(_storage, token);
      // Readback sanity: confirm the new token is actually readable
      // before returning true. Without this, a future jwtReader
      // read could race with the write and the interceptor would
      // try to retry with null.
      final verify = await _storage.read(key: kAccessTokenKey);
      if (verify != token) {
        debugPrint(
            '[DBG-AUTH] silentRelogin STORAGE-RACE verify=${verify == null ? "NULL" : "len=${verify.length}"} '
            'expected=len=${token.length} — returning false');
        return false;
      }
      debugPrint('[DBG-AUTH] silentRelogin OK newTokenLen=${token.length}');
      return true;
    } catch (e, st) {
      sw.stop();
      debugPrint(
          '[DBG-AUTH] silentRelogin threw after ${sw.elapsedMilliseconds}ms: $e\n$st');
      return false;
    }
  }

  /// Fetch the current user. Returns null on any failure.
  Future<UserProfile?> fetchMe() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/v1/users/me');
      if (response.statusCode != 200 || response.data == null) return null;
      return UserProfile.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }

  /// Clear local credentials. Server-side logout is best-effort.
  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/v1/users/logout');
    } catch (_) {
      // Best-effort. Local clear happens regardless.
    }
    await clearAccessToken(_storage);
    await _storage.delete(key: _kRememberEmail);
    await _storage.delete(key: _kRememberPassword);
  }

  /// Boot-time restore. Three paths:
  ///   1. Stored JWT + works → return user (silent).
  ///   2. Stored JWT + 401 → drop JWT, try silentRelogin with cached creds.
  ///   3. No stored JWT but cached creds (from a previous
  ///      "Stay signed in") → silentRelogin directly. UI should pre-fill
  ///      the email field with `readRememberedEmail()`.
  /// Returns null only when nothing useful is on disk.
  Future<UserProfile?> tryRestore() async {
    final token = await _storage.read(key: kAccessTokenKey);

    if (token != null && token.isNotEmpty) {
      final me = await fetchMe();
      if (me != null) return me;
    }

    // Either there was no stored JWT, or the stored one was 401'd.
    // Either way: try the cached credentials.
    if (await silentRelogin()) {
      return fetchMe();
    }
    return null;
  }
}

/// Provider for the AuthRepository singleton.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final api = ref.watch(apiClientProvider);
  final repo = AuthRepository(storage, api);

  // Wire the silent-relogin callback that ApiClient's auth interceptor
  // calls on a 401. This sidesteps the Riverpod cycle (apiClientProvider
  // ↔ authRepositoryProvider): ApiClient reads the callback through a
  // module-level holder (see `setReloginCallback` in jwt_reader.dart),
  // not via `ref.read(authRepositoryProvider)`. The callback is only
  // invoked at 401-time, by which point both providers are constructed.
  setReloginCallback(() async {
    try {
      return await repo.silentRelogin();
    } catch (_) {
      return false;
    }
  });

  return repo;
});

/// StateNotifier exposing AuthState to the UI.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState(status: AuthStatus.unknown)) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    final repo = _ref.read(authRepositoryProvider);
    final user = await repo.tryRestore();
    if (user != null) {
      state = AuthState(status: AuthStatus.signedIn, user: user);
    } else {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(status: AuthStatus.unknown, error: null);
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = await repo.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = AuthState(status: AuthStatus.signedIn, user: user);
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.signedOut, error: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.signedOut,
        error: 'Network error. Check your connection.',
      );
    }
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Called from biometric gate after successful re-auth.
  void markSignedIn(UserProfile user) {
    state = AuthState(status: AuthStatus.signedIn, user: user);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
