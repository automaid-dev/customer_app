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

  /// Step 1 of sign-up — see AuthRepository.register() for the exact
  /// backend contract. Does not change auth state (account isn't active
  /// yet); the caller moves on to the OTP screen and calls
  /// verifyRegister() next.
  Future<({bool status, String message, int? userId})> register({
    required String name,
    required String email,
    required String mobileNo,
    required String password,
    required String passwordConfirmation,
    DateTime? dob,
  }) {
    return _repo.register(
      name: name,
      email: email,
      mobileNo: mobileNo,
      password: password,
      passwordConfirmation: passwordConfirmation,
      dob: dob,
    );
  }

  Future<({bool status, String message, int? userId})> resendOtp(String email) {
    return _repo.resendOtp(email);
  }

  /// Step 2 of sign-up: verifies the OTP. Deliberately does NOT flip auth
  /// state here — the token is already saved to secure storage by the repo
  /// at this point (so authenticated API calls work), but activating state
  /// is left to [activateSession] so the caller (the OTP screen) can do
  /// something with the fresh token — e.g. save an address — before the
  /// router's redirect fires and navigates away from that screen. Flipping
  /// state immediately here caused exactly that race: the address save
  /// would sometimes lose to navigation and silently not happen.
  Future<AuthResult> verifyRegister({required int userId, required String otp}) {
    return _repo.verifyRegister(userId: userId, otp: otp);
  }

  /// Call once any post-verification work (like saving an address) is
  /// done, to actually sign the user in and let the router navigate to
  /// the dashboard.
  void activateSession(AppUser user) {
    state = AuthState.authenticated(user);
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

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});
