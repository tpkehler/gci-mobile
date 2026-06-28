import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/create/create_jam_screen.dart';
import 'features/demo/demo_web_screen.dart';
import 'features/home/shell_screen.dart';
import 'features/jam/idea_jam_screen.dart';
import 'features/jam/jam_detail_screen.dart';
import 'features/jam/participate_screen.dart';
import 'features/jam/results_screen.dart';
import 'features/onboarding/about_screen.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/welcome_screen.dart';
import 'widgets/jam_brand.dart';

/// Routes mirror the web app URLs so invite links
/// (https://…/jam/:id/participate, legacy /collaborate/:id) deep-link
/// directly into the matching screen.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);
  ref
    ..onDispose(authListenable.dispose)
    ..listen(authControllerProvider, (_, __) => authListenable.value++)
    ..listen(onboardingControllerProvider, (_, __) => authListenable.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final onboarding = ref.read(onboardingControllerProvider);
      if (!auth.initialized || !onboarding.initialized) {
        return null; // splash handles startup
      }

      final path = state.uri.path;
      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password';
      final isJamRoute =
          path.startsWith('/jam/') || path.startsWith('/collaborate/');
      final isDemoRoute = path.startsWith('/demo/mhg');

      // First-run intro: show it once, but never block invite deep links,
      // demo story, or the welcome screen itself.
      if (!onboarding.seenIntro &&
          !isJamRoute &&
          !isDemoRoute &&
          path != '/welcome') {
        return '/welcome';
      }

      if (!auth.isSignedIn) {
        // Demo + jam deep links reachable signed-out.
        if (isDemoRoute) return null;
        if (isJamRoute) {
          return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
        }
        // Welcome + About are reachable signed-out (learn before signing in).
        if (path == '/welcome' || path == '/about' || isAuthRoute) return null;
        return '/login';
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
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
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
      // Joining a jam lands in the warm-up discussion (IdeaJam).
      GoRoute(
          path: '/jam/:id',
          builder: (_, state) =>
              IdeaJamScreen(jamId: state.pathParameters['id']!)),
      // The overview/funnel/prompts now live behind the discussion's info action.
      GoRoute(
          path: '/jam/:id/about',
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
      ...demoStoryRoutes(),
    ],
  );
});

class GciApp extends ConsumerWidget {
  const GciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final onboarding = ref.watch(onboardingControllerProvider);
    if (!auth.initialized || !onboarding.initialized) {
      return MaterialApp(
        title: 'Jam',
      theme: GciTheme.light(),
      darkTheme: GciTheme.dark(),
      home: const _SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }
    return MaterialApp.router(
      title: 'Jam',
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
      backgroundColor: GciTheme.brandInk,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 320,
                height: 168,
                child: LiveBeliefField(),
              ),
              const SizedBox(height: 8),
              const JamWordmark(onDark: true, fontSize: 44),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "the destination isn't scripted — it emerges from the "
                  'interaction',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GciTheme.brandTealLight.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
