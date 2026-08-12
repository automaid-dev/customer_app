import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';

class AuthResult {
  final AppUser user;
  final String? token; // null when registration incomplete / rejected without token in some paths
  final String? message;
  final bool status;

  AuthResult({required this.user, required this.status, this.token, this.message});
}

/// Wraps the auth-related endpoints from routes/api.php:
/// POST /auth/login, POST /profile/logout, POST /profile/me
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResult> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final json = await _api.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
    });

    final userJson = (json['user'] ?? json['data']?['user']) as Map<String, dynamic>;
    final user = AppUser.fromJson(userJson);
    final token = json['token'] as String?;

    if (token != null) {
      await TokenStorage.instance.saveToken(token);
      if (user.roles.isNotEmpty) {
        await TokenStorage.instance.saveActiveRole(user.primaryRole.name);
      }
    }

    return AuthResult(
      user: user,
      status: json['status'] == true,
      token: token,
      message: json['message']?.toString(),
    );
  }

  Future<AppUser> me() async {
    final json = await _api.post(ApiEndpoints.profileMe);
    // profile/me returns the user object directly (see ProfileController::me)
    return AppUser.fromJson(json);
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.profileLogout);
    } finally {
      await TokenStorage.instance.clear();
    }
  }
}
