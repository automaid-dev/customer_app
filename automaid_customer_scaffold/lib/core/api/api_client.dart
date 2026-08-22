import 'package:dio/dio.dart';
import 'token_storage.dart';

/// Thrown for any non-2xx response so UI code can catch one type
/// and read [message] / [statusCode] regardless of which endpoint failed.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors; // Laravel validation error bag, if any

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Called when a 401 comes back — lets the app force logout / redirect to login
/// without ApiClient needing to know about routing or app state.
typedef UnauthorizedCallback = void Function();

class ApiClient {
  ApiClient._internal(this._dio);

  static ApiClient? _instance;

  factory ApiClient({required String baseUrl, UnauthorizedCallback? onUnauthorized}) {
    if (_instance != null) return _instance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );

    _instance = ApiClient._internal(dio);
    return _instance!;
  }

  final Dio _dio;

  /// The backend uses POST for almost every endpoint (see routes/api.php),
  /// including reads — so `post` is the primary method used throughout the app.
  /// [data] accepts a Map (most calls) or a Dio FormData (multipart file
  /// uploads — registration document photos, delivery proof, etc.).
  Future<Map<String, dynamic>> post(String path, {dynamic data, Duration? timeout}) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: timeout != null ? Options(sendTimeout: timeout, receiveTimeout: timeout) : null,
      );
      return _unwrap(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _unwrap(response);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Map<String, dynamic> _unwrap(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    String message = e.message ?? 'Network error';
    Map<String, dynamic>? errors;

    if (data is Map<String, dynamic>) {
      // Most endpoints in this backend return {'message': '...'}, but
      // AuthController::login() specifically returns {'error':
      // 'Unauthorized'} for bad credentials (a genuine 401, unlike
      // everything else which uses a 200 with status:false) — without
      // this fallback, a wrong email/password showed Dio's raw internal
      // error text instead of a real message.
      message = data['message']?.toString() ?? data['error']?.toString() ?? message;
      if (data['errors'] is Map<String, dynamic>) {
        errors = data['errors'] as Map<String, dynamic>;
      }
    }

    return ApiException(message, statusCode: e.response?.statusCode, errors: errors);
  }
}
