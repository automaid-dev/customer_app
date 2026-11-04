import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// A push notification that arrived while the app was open, or that the
/// customer tapped. [data] is the extra payload the backend attached
/// (e.g. order_id, type).
class PushMessage {
  const PushMessage({required this.title, required this.body, required this.data});
  final String title;
  final String body;
  final Map<String, dynamic> data;
}

/// Push notifications via Firebase Cloud Messaging (project automaid-app).
///
/// Flow: [init] once at startup -> [onSignedIn] whenever a user is signed
/// in (fresh login, restored session, finished registration) -> this
/// phone's FCM token is saved via POST /profile/device (users.fcm_token),
/// which the backend's PushService sends to -> [onSignedOut] on logout.
///
/// Replaces the OneSignal SDK used by app versions up to 1.0.0+8; the
/// backend still reaches those older versions through OneSignal.
///
/// Every call is best-effort: a push failure must never break login.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  ApiClient? _api;
  int? _userId;
  String? _lastSentToken;
  StreamSubscription<String>? _tokenSub;

  /// Notifications received while the app is in the foreground (the
  /// system does not show those itself) — the app shows a banner.
  final StreamController<PushMessage> _foreground = StreamController.broadcast();
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  /// Notifications the customer tapped (app opened from the background
  /// or from closed).
  final StreamController<PushMessage> _opened = StreamController.broadcast();
  Stream<PushMessage> get openedMessages => _opened.stream;
  PushMessage? _launchMessage;

  /// The notification that launched the app from closed, if any — read
  /// once by the UI after the first frame.
  PushMessage? takeLaunchMessage() {
    final m = _launchMessage;
    _launchMessage = null;
    return m;
  }

  Future<void> init() async {
    try {
      // Android reads android/app/google-services.json; iOS needs
      // ios/Runner/GoogleService-Info.plist (Firebase console → add iOS app).
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;

      // iOS: also show banners while the app is open.
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen((m) {
        // Android does not display notifications while the app is open,
        // so the app shows its own banner (iOS shows the system one).
        if (defaultTargetPlatform == TargetPlatform.android) {
          _foreground.add(_toPush(m));
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(_toPush(m)));
      final initial = await fm.getInitialMessage();
      if (initial != null) _launchMessage = _toPush(initial);

      _ready = true;
    } catch (e) {
      debugPrint('PushService.init failed: $e');
    }
  }

  PushMessage _toPush(RemoteMessage m) => PushMessage(
        title: m.notification?.title ?? m.data['title']?.toString() ?? '',
        body: m.notification?.body ?? m.data['body']?.toString() ?? '',
        data: Map<String, dynamic>.from(m.data),
      );

  Future<void> onSignedIn(ApiClient api, int userId) async {
    if (!_ready || userId <= 0) return;
    _api = api;
    if (_userId == userId && _lastSentToken != null) return; // already registered
    _userId = userId;
    try {
      final fm = FirebaseMessaging.instance;
      // Android 13+ / iOS ask once; does nothing if already allowed/denied.
      await fm.requestPermission(alert: true, badge: true, sound: true);
      final token = await fm.getToken();
      if (token != null) await _sendToken(token);

      // Tokens can change (reinstall, restore, periodic refresh).
      _tokenSub ??= fm.onTokenRefresh.listen((t) {
        if (_userId != null) _sendToken(t);
      });
    } catch (e) {
      debugPrint('PushService.onSignedIn failed: $e');
    }
  }

  Future<void> _sendToken(String token) async {
    final api = _api;
    if (api == null || token == _lastSentToken) return;
    try {
      await api.post(ApiEndpoints.profileSaveDevice, data: {'fcm_token': token});
      _lastSentToken = token;
    } catch (e) {
      debugPrint('PushService: saving FCM token failed: $e');
    }
  }

  /// The backend's /profile/logout already clears users.fcm_token; the
  /// token is also deleted here so the next account on this phone gets
  /// a fresh one.
  Future<void> onSignedOut() async {
    _userId = null;
    _lastSentToken = null;
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('PushService.onSignedOut failed: $e');
    }
  }
}
