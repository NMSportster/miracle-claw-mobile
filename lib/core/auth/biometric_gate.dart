import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_repository.dart';

/// Wraps `local_auth` for re-auth after cold start.
///
/// On Android, prompts for fingerprint/face/pattern. On iOS, Face ID / Touch ID.
/// Used as a gate after boot when a JWT is cached locally.
class BiometricGate {
  BiometricGate();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Prompt the user. Returns true if they authenticated.
  Future<bool> authenticate({String reason = 'Unlock Miracle Claw'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricGateProvider = Provider<BiometricGate>((ref) => BiometricGate());

/// State for the boot flow: do we need to show biometric prompt before letting
/// the user into the app?
class BiometricGateState {
  const BiometricGateState({
    required this.required,
    this.attempts = 0,
  });
  final bool required;
  final int attempts;

  BiometricGateState copyWith({bool? required, int? attempts}) =>
      BiometricGateState(required: required ?? this.required, attempts: attempts ?? this.attempts);
}

class BiometricGateNotifier extends StateNotifier<BiometricGateState> {
  BiometricGateNotifier(this._ref)
      : super(const BiometricGateState(required: false));

  final Ref _ref;

  /// Called once at app boot. Decides whether to require biometric re-auth.
  Future<void> evaluate() async {
    final auth = _ref.read(authNotifierProvider);
    if (auth.status != AuthStatus.signedIn) {
      state = const BiometricGateState(required: false);
      return;
    }

    final gate = _ref.read(biometricGateProvider);
    final hasBiometrics = await gate.canCheckBiometrics();
    state = BiometricGateState(required: hasBiometrics);
  }

  /// Called when user attempts to unlock. Returns true on success.
  Future<bool> tryUnlock() async {
    final gate = _ref.read(biometricGateProvider);
    final ok = await gate.authenticate();
    if (ok) {
      state = const BiometricGateState(required: false);
      return true;
    }
    state = state.copyWith(attempts: state.attempts + 1);
    return false;
  }

  /// Skip biometric (user chose to sign out instead).
  Future<void> skip() async {
    await _ref.read(authNotifierProvider.notifier).logout();
    state = const BiometricGateState(required: false);
  }
}

final biometricGateNotifierProvider =
    StateNotifierProvider<BiometricGateNotifier, BiometricGateState>(
        (ref) => BiometricGateNotifier(ref));
