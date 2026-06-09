import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/coverage/coverage_screen.dart';
import '../screens/booking/transfer_details_screen.dart';
import '../screens/booking/payment_screen.dart';
import '../screens/booking/confirmation_screen.dart';
import '../screens/history/history_screen.dart';
import '../widgets/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>();

// Fires GoRouter's redirect whenever Firebase auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthRefreshNotifier();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;
    final isSplash = loc == '/';
    final isAuthRoute = loc == '/login' || loc == '/signup';

    if (isSplash) return null;
    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';
    return null;
  },
  routes: [
    // ── Splash ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const SplashScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),

    // ── Auth (no nav bar) ────────────────────────────────────────────────────
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const LoginScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),

    // ── Booking flow (no nav bar — pushed on top of shell) ───────────────────
    GoRoute(
      path: '/transfer-details',
      builder: (context, state) => const TransferDetailsScreen(),
    ),
    GoRoute(
      path: '/payment',
      builder: (context, state) => const PaymentScreen(),
    ),
    GoRoute(
      path: '/booking/confirmation/:reference',
      builder: (context, state) => ConfirmationScreen(
        reference: state.pathParameters['reference']!,
      ),
    ),

    // ── Main shell (persistent bottom nav) ──────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Tab 0 — Ride
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) {
                final q = state.uri.queryParameters;
                return HomeScreen(
                  rebookFrom: q['from'],
                  rebookTo: q['to'],
                  rebookFromLat: double.tryParse(q['fromLat'] ?? ''),
                  rebookFromLng: double.tryParse(q['fromLng'] ?? ''),
                  rebookToLat: double.tryParse(q['toLat'] ?? ''),
                  rebookToLng: double.tryParse(q['toLng'] ?? ''),
                );
              },
            ),
          ],
        ),

        // Tab 1 — History
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),

        // Tab 2 — Coverage
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/coverage',
              builder: (context, state) => const CoverageScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
