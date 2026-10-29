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

  /// True when the device hardware can perform biometric authentication.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// True when the user has actually enrolled at least one biometric.
  ///
  /// This is deliberately distinct from [canCheckBiometrics]: a device
  /// can have a working fingerprint sensor (or support device
  /// credentials) while having *nothing enrolled*. Prompting in that
  /// state is a trap — the user can never satisfy the prompt, and the
  /// only way past the unlock screen is "Sign in as a different user",
  /// which forces a full re-login.
  ///
  /// That exact situation bit the SM-N960U test phone, which reports
  /// a fingerprint sensor with zero enrolled templates. Every cold
  /// start landed on the unlock screen and every test iteration needed
  /// a manual re-login. Gating on *enrolled* biometrics instead of
  /// *capable* biometrics removes the trap entirely: with nothing
  /// enrolled, the app goes straight in.
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      // If we can't enumerate, don't gate — a false "required" is
      // worse than a false "not required" (one logs the user out,
      // the other just skips a lock screen).
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
  ///
  /// Requires biometrics only when the user has actually *enrolled*
  /// one. A device that merely supports biometrics (hardware present,
  /// nothing enrolled) must NOT gate — see
  /// [BiometricGate.hasEnrolledBiometrics].
  Future<void> evaluate() async {
    final auth = _ref.read(authNotifierProvider);
    if (auth.status != AuthStatus.signedIn) {
      state = const BiometricGateState(required: false);
      return;
    }

    final gate = _ref.read(biometricGateProvider);
    final hasEnrolled = await gate.hasEnrolledBiometrics();
    state = BiometricGateState(required: hasEnrolled);
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
