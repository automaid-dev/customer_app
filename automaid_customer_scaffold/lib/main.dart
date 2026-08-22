import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: AutomaidPartnerApp()));
}

/// "Partner" app: serves both rider and merchant (wash outlet) roles from
/// one codebase/one install — role decides which home screen shows after
/// login (see core/router/app_router.dart).
class AutomaidPartnerApp extends ConsumerWidget {
  const AutomaidPartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LB AutoMaid Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
