import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/biometric_gate.dart';

/// Boot screen — shown while we're restoring auth state or asking for biometrics.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bootstrap: once auth state is known, route to the right place.
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next.status == AuthStatus.signedIn) {
        context.go('/unlock');
      } else if (next.status == AuthStatus.signedOut) {
        context.go('/login');
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class BiometricUnlockScreen extends ConsumerStatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  ConsumerState<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends ConsumerState<BiometricUnlockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(biometricGateNotifierProvider.notifier).evaluate();
    });
  }

  Future<void> _unlock() async {
    final ok = await ref.read(biometricGateNotifierProvider.notifier).tryUnlock();
    if (ok && mounted) {
      context.go('/');
    }
  }

  Future<void> _signOut() async {
    await ref.read(biometricGateNotifierProvider.notifier).skip();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final gate = ref.watch(biometricGateNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  auth.user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (gate.required)
                  FilledButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign in as a different user'),
                ),
                if (gate.attempts > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Authentication failed (attempt ${gate.attempts})',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
