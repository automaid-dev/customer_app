import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../models/app_user.dart';
import '../../features/auth/login_screen.dart';
import '../../features/customer/home/customer_home_screen.dart';

/// Customer-app router. This app only ever serves the customer role —
/// if a rider/merchant account somehow logs in here, they're logged back
/// out (see redirect below) rather than shown a broken screen.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';

      if (authState.status == AuthStatus.unknown) {
        return null;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }

      // authenticated — this app only supports the customer role
      final role = authState.user?.primaryRole;
      if (role != UserRole.customer) {
        // Wrong app for this account — force logout rather than show
        // a screen with no data for their role.
        Future.microtask(() => ref.read(authControllerProvider.notifier).logout());
        return '/login';
      }

      return loggingIn ? '/customer/home' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/customer/home',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
