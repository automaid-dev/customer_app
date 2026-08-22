import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// Change this to your deployed backend URL (the one currently reachable
/// at http://56.69.76.60 in this project). Move to --dart-define for
/// prod/staging builds once you have multiple environments.
const String kApiBaseUrl = 'https://app.automaid.asia/api';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(AppUser user)
      : this(status: AuthStatus.authenticated, user: user);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState.unknown()) {
    _restoreSession();
  }

  final AuthRepository _repo;

  Future<void> _restoreSession() async {
    final token = await TokenStorage.instance.readToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final user = await _repo.me();
      state = AuthState.authenticated(user);
    } catch (_) {
      // token invalid/expired
      await TokenStorage.instance.clear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<AuthResult> login(String email, String password) async {
    final result = await _repo.login(email: email, password: password);
    if (result.token != null && result.status) {
      state = AuthState.authenticated(result.user);
    }
    return result;
  }

  Future<({bool status, String message, int? userId})> resendOtp(String email) {
    return _repo.resendOtp(email);
  }

  /// Verifies OTP for a rider/merchant registration and, on success,
  /// signs the account in — same effect as login(). Their role-specific
  /// status (Rider/Merchant) may still be PENDING admin approval even
  /// though they're authenticated; the home screen checks for that
  /// separately and shows a pending-approval state instead of the full
  /// dashboard when needed.
  Future<AuthResult> verifyRegisterRider({required int userId, required String otp}) async {
    final result = await _repo.verifyRegisterRider(userId: userId, otp: otp);
    if (result.token != null && result.status) {
      state = AuthState.authenticated(result.user);
    }
    return result;
  }

  Future<AuthResult> verifyRegisterMerchant({required int userId, required String otp}) async {
    final result = await _repo.verifyRegisterMerchant(userId: userId, otp: otp);
    if (result.token != null && result.status) {
      state = AuthState.authenticated(result.user);
    }
    return result;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }

  /// Called by ApiClient's onUnauthorized callback when any request gets a 401.
  void forceLogout() {
    TokenStorage.instance.clear();
    state = const AuthState.unauthenticated();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: kApiBaseUrl,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

/// Live list of Malaysian states from the backend's own seeded data —
/// use this for the state dropdown in registration instead of free text
/// (a free-text mismatch caused real bugs in the customer app — e.g. the
/// Kuala Lumpur federal territory is seeded as "Wp Kuala Lumpur", not
/// "Kuala Lumpur"). Doesn't require login.
final statesProvider = FutureProvider.autoDispose((ref) {
  return ref.read(authRepositoryProvider).states();
});

/// Bank list for the registration bank-details step.
final banksProvider = FutureProvider.autoDispose((ref) {
  return ref.read(authRepositoryProvider).banks();
});

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});
