import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// Change this to your deployed backend URL (the one currently reachable
/// at http://56.69.76.60 in this project). Move to --dart-define for
/// prod/staging builds once you have multiple environments.
const String kApiBaseUrl = 'http://56.69.76.60/api';

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

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});
