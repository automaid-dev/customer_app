import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/push/push_service.dart';
import 'features/customer/notifications/notifications_screen.dart';
import 'features/customer/providers/customer_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase Cloud Messaging push. Best-effort: never blocks app start.
  await PushService.instance.init();
  runApp(const ProviderScope(child: AutomaidCustomerApp()));
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class AutomaidCustomerApp extends ConsumerStatefulWidget {
  const AutomaidCustomerApp({super.key});

  @override
  ConsumerState<AutomaidCustomerApp> createState() => _AutomaidCustomerAppState();
}

class _AutomaidCustomerAppState extends ConsumerState<AutomaidCustomerApp> {
  StreamSubscription<PushMessage>? _fgSub;
  StreamSubscription<PushMessage>? _openSub;

  bool get _signedIn => ref.read(authControllerProvider).status == AuthStatus.authenticated;

  @override
  void initState() {
    super.initState();
    _fgSub = PushService.instance.foregroundMessages.listen(_onForeground);
    _openSub = PushService.instance.openedMessages.listen((_) => _openInbox());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PushService.instance.takeLaunchMessage() != null) {
        // Wait for the session to be restored before opening the inbox.
        _openInboxWhenSignedIn();
      }
    });
  }

  @override
  void dispose() {
    _fgSub?.cancel();
    _openSub?.cancel();
    super.dispose();
  }

  void _refreshLists() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(homeBookingsProvider);
  }

  /// Notification while the app is open: refresh lists and show a banner.
  void _onForeground(PushMessage m) {
    if (!_signedIn) return;
    _refreshLists();
    final text = [m.title, m.body].where((s) => s.trim().isNotEmpty).join('\n');
    if (text.isEmpty) return;
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'View', onPressed: _openInbox),
      ));
  }

  /// Tapped notification: open the in-app notifications inbox.
  void _openInbox() {
    if (!_signedIn) return;
    _refreshLists();
    final nav = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
    nav?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _openInboxWhenSignedIn() {
    if (_signedIn) {
      _openInbox();
      return;
    }
    late final ProviderSubscription<AuthState> sub;
    sub = ref.listenManual<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        sub.close();
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInbox());
      } else if (next.status == AuthStatus.unauthenticated) {
        sub.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LB AutoMaid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
    );
  }
}
