import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_repository.dart';
import 'core/pairing/discovery_state.dart';
import 'core/pairing/pairing_service.dart';
import 'features/auth/biometric_unlock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';

/// Top-level app widget. Sets up Material 3 dark theme + router that reacts to
/// auth state changes. Also wires the pairing discovery loop to start/stop
/// based on auth state — Phase 3.1.
class MiracleClawApp extends ConsumerWidget {
  const MiracleClawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 3.1: react to auth state changes to start/stop the pairing
    // discovery loop. Started on signedIn, stopped on signedOut (and on
    // boot's "unknown" → initial state, where we don't want to spam MAIC
    // before the user has a JWT).
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      final svc = ref.read(pairingServiceProvider);
      if (next.status == AuthStatus.signedIn) {
        svc.startDiscovery((s) {
          ref.read(connectionStateProvider.notifier).state = s;
        });
      } else if (prev?.status == AuthStatus.signedIn) {
        // Was signed in, now not — stop the loop.
        svc.stopDiscovery();
        // Drop any cached Paired state so we don't display stale info on
        // the next sign-in.
        ref.read(connectionStateProvider.notifier).state =
            const CloudOnly(reason: 'first_run');
      }
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Miracle Claw',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00C853), // Milagro green
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Routing — driven by AuthStatus. Splash during boot, login when signed-out,
/// unlock when signed-in + has biometrics, home when signed-in + unlocked.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      switch (auth.status) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return loc == '/login' ? null : '/login';
        case AuthStatus.signedIn:
          if (loc == '/splash' || loc == '/login') return '/unlock';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/unlock', builder: (_, _) => const BiometricUnlockScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeShell()),
    ],
  );
});
