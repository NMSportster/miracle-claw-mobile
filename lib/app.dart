import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_repository.dart';
import 'features/auth/biometric_unlock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/workspace/workspace_create_screen.dart';
import 'features/workspace/workspace_detail_screen.dart';
import 'features/capture/voice_capture_screen.dart';
import 'features/capture/photo_capture_screen.dart';
import 'features/capture/quick_capture_screen.dart';

/// Top-level app widget. Sets up Material 3 dark theme + router that reacts to
/// auth state changes. Workspace discovery is started/stopped by the auth
/// listener — the workspace service handles its own SSE subscription, so we
/// don't need the pairing discovery loop anymore (2026-09-16).
class MiracleClawApp extends ConsumerWidget {
  const MiracleClawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2026-09-16 pivot: the workspace REST + SSE feed is started lazily
    // by the providers themselves (the first time any screen reads
    // workspaceServiceProvider). No more pairing discovery loop.
    //
    // The old code below was wired to the pairing service to start/stop
    // desktop discovery on auth state. It's removed because pairing is
    // deprecated — see memory/projects/workspace_architecture.md.

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
      GoRoute(
        path: '/workspace/new',
        builder: (_, _) => const WorkspaceCreateScreen(),
      ),
      GoRoute(
        path: '/workspace/:noteId',
        builder: (_, state) => WorkspaceDetailScreen(
          noteId: state.pathParameters['noteId']!,
        ),
      ),
      // Phase 4C capture screens.
      GoRoute(path: '/capture/voice', builder: (_, _) => const VoiceCaptureScreen()),
      GoRoute(path: '/capture/photo', builder: (_, _) => const PhotoCaptureScreen()),
      GoRoute(path: '/capture/quick', builder: (_, _) => const QuickCaptureScreen()),
    ],
  );
});
