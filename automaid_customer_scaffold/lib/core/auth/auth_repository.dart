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

  /// Step 1 of sign-up: creates the user (status PENDING, not yet active)
  /// and triggers an OTP SMS to their phone — see AuthController::register.
  /// No token yet; the account isn't usable until [verifyRegister] succeeds.
  /// [mobileNo] must already be in `60XXXXXXXXX` form (country code + number,
  /// no leading 0, no '+') — the backend validates it against
  /// `^60\d{9,10}$` exactly.
  /// Returns the user_id needed for [verifyRegister] / [resendOtp].
  Future<({bool status, String message, int? userId})> register({
    required String name,
    required String email,
    required String mobileNo,
    required String password,
    required String passwordConfirmation,
    DateTime? dob,
  }) async {
    final json = await _api.post(ApiEndpoints.register, data: {
      'name': name,
      'email': email,
      'mobile_no': mobileNo,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (dob != null) 'dob': dob.toIso8601String().split('T').first,
    });
    return (
      status: json['status'] == true,
      // The backend returns validation failures as a normal 200 response
      // with status:false and a generic top-level `message` (e.g.
      // "Validation error"), plus the real per-field detail in `errors`
      // (Laravel's standard {"field": ["reason"]} shape) — flatten that
      // into something readable rather than showing the generic text.
      message: _describeMessage(json),
      userId: json['user_id'] as int?,
    );
  }

  String _describeMessage(Map<String, dynamic> json) {
    final generic = json['message']?.toString() ?? '';
    final errors = json['errors'];
    if (errors is Map) {
      final lines = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          lines.addAll(value.map((e) => e.toString()));
        } else if (value != null) {
          lines.add(value.toString());
        }
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }
    return generic;
  }

  /// Resends the OTP for a not-yet-verified account (e.g. user closed the
  /// app before entering it, or the code expired). Looks the account up by
  /// email — see AuthController::resendOtp.
  Future<({bool status, String message, int? userId})> resendOtp(String email) async {
    final json = await _api.post(ApiEndpoints.resendOtp, data: {'email': email});
    return (
      status: json['status'] == true,
      message: json['message']?.toString() ?? '',
      userId: json['user_id'] as int?,
    );
  }

  /// Step 2 of sign-up: verifies the OTP and activates the account.
  ///
  /// Quirk worth knowing: unlike [login], this endpoint does NOT return a
  /// top-level `token` field — the Sanctum plaintext token is instead set
  /// on the user row's `api_token` column and comes back embedded in the
  /// returned `user` object (see AuthController::verifyRegister). This
  /// method reads it from there so the caller doesn't need to know that.
  Future<AuthResult> verifyRegister({required int userId, required String otp}) async {
    final json = await _api.post(ApiEndpoints.registerVerify, data: {
      'user_id': userId,
      'token': otp,
    });

    final status = json['status'] == true;
    final userJson = json['user'] as Map<String, dynamic>?;
    final user = userJson != null ? AppUser.fromJson(userJson) : null;
    final token = userJson?['api_token'] as String?;

    if (status && token != null && user != null) {
      await TokenStorage.instance.saveToken(token);
      if (user.roles.isNotEmpty) {
        await TokenStorage.instance.saveActiveRole(user.primaryRole.name);
      }
    }

    return AuthResult(
      user: user ?? AppUser(id: 0, name: '', email: '', status: '', isActive: false),
      status: status,
      token: token,
      message: json['message']?.toString(),
    );
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.profileLogout);
    } finally {
      await TokenStorage.instance.clear();
    }
  }
}
