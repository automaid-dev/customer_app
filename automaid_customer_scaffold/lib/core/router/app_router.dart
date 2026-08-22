import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../models/app_user.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_role_screen.dart';
import '../../features/auth/pending_approval_screen.dart';
import '../../features/rider/home/rider_home_screen.dart';
import '../../features/merchant/home/merchant_home_screen.dart';

/// Combined rider + merchant app router. A single login screen serves
/// both roles — after auth, the redirect below sends a rider account to
/// /rider/home and a merchant (wash outlet) account to /merchant/home,
/// based on the Spatie role on the logged-in user. An account whose
/// entity is still awaiting admin approval (User.status == 'onboarding')
/// is sent to /pending instead of either dashboard.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final registering = state.matchedLocation == '/register';
      final preAuth = loggingIn || registering;

      if (authState.status == AuthStatus.unknown) {
        return null;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return preAuth ? null : '/login';
      }

      // authenticated — route by role
      final role = authState.user?.primaryRole;
      if (role != UserRole.rider && role != UserRole.merchant) {
        // Customer account trying to use the rider/merchant app.
        Future.microtask(() => ref.read(authControllerProvider.notifier).logout());
        return '/login';
      }

      if (authState.user?.isPendingApproval == true) {
        return state.matchedLocation == '/pending' ? null : '/pending';
      }

      if (preAuth || state.matchedLocation == '/pending') {
        return role == UserRole.rider ? '/rider/home' : '/merchant/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterRoleScreen()),
      GoRoute(path: '/pending', builder: (context, state) => const PendingApprovalScreen()),
      GoRoute(
        path: '/rider/home',
        builder: (context, state) => const RiderHomeScreen(),
      ),
      GoRoute(
        path: '/merchant/home',
        builder: (context, state) => const MerchantHomeScreen(),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
