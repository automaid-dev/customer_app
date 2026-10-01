import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// OneSignal App ID for the Customer app (public value — safe in source,
/// same as kApiBaseUrl). Must match the backend's ONESIGNAL_APP_ID.
const String kOneSignalAppId = 'eeccf597-52b6-42b9-997a-50e82e7ef57f';

/// Push notifications via OneSignal (delivered on Android through the
/// automaid-app Firebase project's FCM).
///
/// Flow: [init] once at startup -> [onSignedIn] whenever a user is signed
/// in (fresh login, restored session, or finished registration) ->
/// the device's OneSignal subscription ID is saved to the backend via
/// POST /profile/device (users.device_id), which is what every
/// Notification class pushes to -> [onSignedOut] on logout.
///
/// Every call is best-effort: a push failure must never break login.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  ApiClient? _api;
  int? _userId;
  String? _lastSentId;

  Future<void> init() async {
    try {
      // Uses android/app/google-services.json via the Google Services
      // Gradle plugin — no firebase_options.dart needed on Android.
      await Firebase.initializeApp();
      OneSignal.initialize(kOneSignalAppId);

      // The subscription ID can arrive (or change) after login — e.g.
      // first launch before FCM finishes registering, or after the user
      // allows notifications. Re-send it whenever it changes.
      OneSignal.User.pushSubscription.addObserver((state) {
        final id = state.current.id;
        if (id != null && _userId != null) _sendDeviceId(id);
      });
      _ready = true;
    } catch (e) {
      debugPrint('PushService.init failed: $e');
    }
  }

  Future<void> onSignedIn(ApiClient api, int userId) async {
    if (!_ready || userId <= 0) return;
    _api = api;
    if (_userId == userId && _lastSentId != null) return; // already registered
    _userId = userId;
    try {
      // External ID = our users.id, so admins can find this user's
      // devices in the OneSignal dashboard.
      await OneSignal.login(userId.toString());
      // Android 13+ asks once; does nothing if already allowed/denied.
      if (!OneSignal.Notifications.permission) {
        await OneSignal.Notifications.requestPermission(false);
      }
      final id = OneSignal.User.pushSubscription.id;
      if (id != null) await _sendDeviceId(id);
    } catch (e) {
      debugPrint('PushService.onSignedIn failed: $e');
    }
  }

  Future<void> _sendDeviceId(String id) async {
    final api = _api;
    if (api == null || id == _lastSentId) return;
    try {
      await api.post(ApiEndpoints.profileSaveDevice, data: {'device_id': id});
      _lastSentId = id;
    } catch (e) {
      debugPrint('PushService: saving device id failed: $e');
    }
  }

  /// The backend's /profile/logout already clears users.device_id.
  Future<void> onSignedOut() async {
    _userId = null;
    _lastSentId = null;
    if (!_ready) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('PushService.onSignedOut failed: $e');
    }
  }
}
