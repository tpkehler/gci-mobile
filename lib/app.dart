import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/create/create_jam_screen.dart';
import 'features/home/shell_screen.dart';
import 'features/jam/jam_detail_screen.dart';
import 'features/jam/participate_screen.dart';
import 'features/jam/results_screen.dart';

/// Routes mirror the web app URLs so invite links
/// (https://…/jam/:id/participate, legacy /collaborate/:id) deep-link
/// directly into the matching screen.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);
  ref
    ..onDispose(authListenable.dispose)
    ..listen(authControllerProvider, (_, __) => authListenable.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (!auth.initialized) return null; // splash handles startup

      final path = state.uri.path;
      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password';
      final isJamRoute =
          path.startsWith('/jam/') || path.startsWith('/collaborate/');

      if (!auth.isSignedIn) {
        // Jam deep links are reachable signed-out: send to login carrying the
        // destination, where "Continue as guest" is offered.
        if (isJamRoute) {
          return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
        }
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute) return '/';
      // Legacy invite URL -> canonical participate URL.
      final legacy = RegExp(r'^/(?:collaborate|facilitate)/([0-9a-f-]+)$',
              caseSensitive: false)
          .firstMatch(path);
      if (legacy != null) return '/jam/${legacy.group(1)}/participate';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ShellScreen()),
      GoRoute(
          path: '/login',
          builder: (_, state) =>
              LoginScreen(redirectTo: state.uri.queryParameters['from'])),
      GoRoute(
          path: '/register',
          builder: (_, state) =>
              RegisterScreen(redirectTo: state.uri.queryParameters['from'])),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/create', builder: (_, __) => const CreateJamScreen()),
      GoRoute(
          path: '/jam/:id',
          builder: (_, state) =>
              JamDetailScreen(jamId: state.pathParameters['id']!)),
      GoRoute(
          path: '/jam/:id/participate',
          builder: (_, state) =>
              ParticipateScreen(jamId: state.pathParameters['id']!)),
      GoRoute(
          path: '/jam/:id/results',
          builder: (_, state) =>
              ResultsScreen(jamId: state.pathParameters['id']!)),
      // Legacy invite links land here, then redirect (above).
      GoRoute(
          path: '/collaborate/:id',
          builder: (_, state) =>
              ParticipateScreen(jamId: state.pathParameters['id']!)),
      GoRoute(
          path: '/facilitate/:id',
          builder: (_, state) =>
              ParticipateScreen(jamId: state.pathParameters['id']!)),
    ],
  );
});

class GciApp extends ConsumerWidget {
  const GciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.initialized) {
      return MaterialApp(
        title: 'GCI',
        theme: GciTheme.light(),
        darkTheme: GciTheme.dark(),
        home: const _SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }
    return MaterialApp.router(
      title: 'GCI',
      theme: GciTheme.light(),
      darkTheme: GciTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GciTheme.brandGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 72, color: Colors.white),
              SizedBox(height: 16),
              Text('GCI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
