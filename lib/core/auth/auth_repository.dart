import 'package:dio/dio.dart';
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

    await _storage.write(key: kAccessTokenKey, value: token);
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
    try {
      final email = await _storage.read(key: _kRememberEmail);
      final password = await _storage.read(key: _kRememberPassword);
      if (email == null || password == null) return false;

      // Temporarily remove auth header so the relogin request doesn't carry
      // an expired token.
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/v1/users/login',
        data: {'email': email, 'password': password},
        options: Options(headers: {'Authorization': null}),
      );

      if (response.statusCode != 200 || response.data == null) return false;
      final token = response.data!['token'] as String?;
      if (token == null || token.isEmpty) return false;

      await _storage.write(key: kAccessTokenKey, value: token);
      return true;
    } catch (_) {
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
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: _kRememberEmail);
    await _storage.delete(key: _kRememberPassword);
  }

  /// Boot-time restore. Tries cached JWT first; on success, validates it
  /// by fetching /v1/users/me. If invalid, attempts silent relogin.
  Future<UserProfile?> tryRestore() async {
    final token = await _storage.read(key: kAccessTokenKey);
    if (token == null || token.isEmpty) return null;

    final me = await fetchMe();
    if (me != null) return me;

    // Cached token rejected — try silent relogin with cached creds.
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
  return AuthRepository(storage, api);
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
