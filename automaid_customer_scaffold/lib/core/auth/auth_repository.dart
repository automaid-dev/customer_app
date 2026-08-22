import 'package:dio/dio.dart' show FormData, MultipartFile, ListFormat;
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/token_storage.dart';
import '../models/app_user.dart';
import '../models/bank_model.dart';
import '../models/state_model.dart';

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

  // ---- Reference data (used during registration) ----

  Future<List<StateModel>> states() async {
    final json = await _api.post(ApiEndpoints.states);
    final list = (json['data']?['states'] as List<dynamic>? ?? []);
    return list.map((s) => StateModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<List<BankModel>> banks() async {
    final json = await _api.post(ApiEndpoints.banks);
    final list = (json['data']?['banks'] as List<dynamic>? ?? json['banks'] as List<dynamic>? ?? []);
    return list.map((b) => BankModel.fromJson(b as Map<String, dynamic>)).toList();
  }

  // ---- Rider registration ----
  // Matches RiderController::register exactly (see the field list in its
  // Validator::make call) — country_name/state_name/city are free-text
  // names the backend resolves to ids itself (get_country_id/get_state_id),
  // same convention as the customer app's address fields.

  Future<({bool status, String message, int? userId})> registerRider({
    required String name,
    required String email,
    required String mobileNo,
    required String password,
    required String passwordConfirmation,
    required String icno,
    String? idType, // 'NRIC' | 'Passport' — mapped to the backend's integer code
    required String addressLine1,
    required String addressLine2,
    required String countryName,
    required String stateName,
    required String postcode,
    required String city,
    required String typeRider, // 'gig' | 'staff' — see Rider::TYPE_* constants
    required String typeVehicle,
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelation,
    required String plateNo,
    required String vehicleMake,
    required String vehicleModel,
    required double latitude,
    required double longitude,
    String? vehicleColor,
    String? bankName,
    String? bankNo,
    // Verification documents — the backend accepts these in the same
    // multipart request as everything else (RiderController::register),
    // not a separate upload call. All 5 required by the flow spec (JPJ
    // grant included — previously missing from the old app).
    required String icFrontPath,
    required String icBackPath,
    required String licenseFrontPath,
    required String licenseBackPath,
    required String jpjGrantPath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'email': email,
      'country_code_mobile': '60',
      'mobile_no': mobileNo,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'icno': icno,
      if (idType != null) 'id_type': idType,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'country_name': countryName,
      'state_name': stateName,
      'postcode': postcode,
      'city': city,
      'type_rider': typeRider,
      'type_vehicle': typeVehicle,
      'emergency_name': emergencyName,
      'country_code_emergency': '60',
      'emergency_phone': emergencyPhone,
      'emergency_relation': emergencyRelation,
      'plate_no': plateNo,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      if (vehicleColor != null) 'vehicle_color': vehicleColor,
      if (bankName != null) 'bank_name': bankName,
      if (bankNo != null) 'bank_no': bankNo,
      'latitude': latitude,
      'longitude': longitude,
      'ic_front': await MultipartFile.fromFile(icFrontPath),
      'ic_back': await MultipartFile.fromFile(icBackPath),
      'license_front': await MultipartFile.fromFile(licenseFrontPath),
      'license_back': await MultipartFile.fromFile(licenseBackPath),
      'jpj_grant': await MultipartFile.fromFile(jpjGrantPath),
    });
    // Longer timeout than the default 15s — this uploads up to 5 photos
    // (IC front/back, license front/back, JPJ grant) plus all the text
    // fields in one request. A client-side timeout here doesn't mean
    // the server request failed — it may complete anyway, which is
    // exactly what caused a real "email already taken, but I never got
    // my OTP" dead end for at least one merchant registration before
    // this was raised (same issue applies to rider — same fix here).
    final json = await _api.post(ApiEndpoints.riderRegister, data: formData, timeout: const Duration(seconds: 60));
    return _describeRegisterResult(json);
  }

  // ---- Merchant registration ----
  // Matches MerchantController::register exactly.

  Future<({bool status, String message, int? userId})> registerMerchant({
    required String name,
    required String email,
    required String mobileNo,
    required String password,
    required String passwordConfirmation,
    required String icno,
    required String idType,
    required String addressLine1,
    required String addressLine2,
    required String countryName,
    required String stateName,
    required String postcode,
    required String city,
    required String typeMerchant, // 'outlet_partner' | 'automaid_outlet'
    required int washerQuantity,
    required int dryerQuantity,
    required List<String> serviceCategories,
    required String companyName,
    required String ssmNo,
    required String businessOption,
    required double latitude,
    required double longitude,
    String? bankName,
    String? bankNo,
    // Verification documents — same single-request convention as rider
    // registration. SSM certificate is optional per the backend
    // validation rule (image|mimes, no "required"), IC front/back always
    // collected per the flow spec's step 3.
    required String icFrontPath,
    required String icBackPath,
    String? ssmCertPath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'email': email,
      'country_code_mobile': '60',
      'mobile_no': mobileNo,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'icno': icno,
      'id_type': idType,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'country_name': countryName,
      'state_name': stateName,
      'postcode': postcode,
      'city': city,
      'type_merchant': typeMerchant,
      'washer_quantity': washerQuantity,
      'dryer_quantity': dryerQuantity,
      'service_categories': serviceCategories,
      'company_name': companyName,
      'ssm_no': ssmNo,
      'business_option': businessOption,
      if (bankName != null) 'bank_name': bankName,
      if (bankNo != null) 'bank_no': bankNo,
      'latitude': latitude,
      'longitude': longitude,
      'ic_front': await MultipartFile.fromFile(icFrontPath),
      'ic_back': await MultipartFile.fromFile(icBackPath),
      if (ssmCertPath != null) 'ssm_cert': await MultipartFile.fromFile(ssmCertPath),
    }, ListFormat.multiCompatible); // service_categories needs key[]=value PHP array syntax, not Dio's default
    // Longer timeout than the default 15s — see the matching comment on
    // registerRider() above. This is exactly what caused the "email
    // already taken, stuck, can't reach OTP" issue reported.
    final json = await _api.post(ApiEndpoints.merchantRegister, data: formData, timeout: const Duration(seconds: 60));
    return _describeRegisterResult(json);
  }

  ({bool status, String message, int? userId}) _describeRegisterResult(Map<String, dynamic> json) {
    return (
      status: json['status'] == true,
      message: _describeMessage(json),
      userId: json['user_id'] as int?,
    );
  }

  /// Flattens Laravel's {"field": ["reason"]} error bag into a readable
  /// multi-line message — the generic top-level `message` (e.g.
  /// "validation error") on its own isn't useful for a 15+ field form.
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

  /// Resends the OTP for a not-yet-verified account — shared endpoint
  /// across customer/rider/merchant (see AuthController::resendOtp).
  Future<({bool status, String message, int? userId})> resendOtp(String email) async {
    final json = await _api.post(ApiEndpoints.resendOtp, data: {'email': email});
    return (
      status: json['status'] == true,
      message: json['message']?.toString() ?? '',
      userId: json['user_id'] as int?,
    );
  }

  /// Verifies OTP for a rider registration — see
  /// RiderController::verifyRegisterRider. Same token-in-user-object
  /// quirk as the customer app: no top-level `token`, it's nested in
  /// `user.api_token`.
  Future<AuthResult> verifyRegisterRider({required int userId, required String otp}) {
    return _verifyRegister(ApiEndpoints.riderRegisterVerify, userId: userId, otp: otp);
  }

  Future<AuthResult> verifyRegisterMerchant({required int userId, required String otp}) {
    return _verifyRegister(ApiEndpoints.merchantRegisterVerify, userId: userId, otp: otp);
  }

  Future<AuthResult> _verifyRegister(String endpoint, {required int userId, required String otp}) async {
    final json = await _api.post(endpoint, data: {'user_id': userId, 'token': otp});

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
