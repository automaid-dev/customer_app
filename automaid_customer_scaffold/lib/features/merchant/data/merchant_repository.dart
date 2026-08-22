import 'package:dio/dio.dart' show FormData, MultipartFile;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_data_helper.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/assign_job_model.dart';

class MerchantRepository {
  MerchantRepository(this._api);
  final ApiClient _api;

  /// Returns (isDuty, todayJobs, incomingJobs). See
  /// Api/Merchant/HomeController::home — jobs are pre-filtered to
  /// "pending action" ones only, split into today vs incoming by the
  /// booking's pickup_date, matching the rider dashboard's shape exactly.
  Future<({bool isDuty, List<AssignJob> today, List<AssignJob> incoming, List<AssignJob> active})> home() async {
    final json = await _api.post(ApiEndpoints.merchantHome);
    final data = unwrapData(json, fallback: 'Could not load dashboard.');
    final jobs = data['assign_jobs'] as Map<String, dynamic>? ?? {};
    List<AssignJob> parse(String key) => (jobs[key] as List<dynamic>? ?? [])
        .map((j) => AssignJob.fromJson(j as Map<String, dynamic>))
        .toList();
    return (
      isDuty: data['is_duty'] == true || data['is_duty'] == 1,
      today: parse('today'),
      incoming: parse('incoming'),
      active: parse('active'),
    );
  }

  Future<void> updateDuty(bool isDuty) async {
    await _api.post(ApiEndpoints.merchantHomeDuty, data: {'is_duty': isDuty});
  }

  // NOTE: POST /merchant/home/city is routed to
  // HomeController::selectCity, but that method doesn't actually exist
  // in the controller as shipped — calling it will 500. Not wired up
  // here until the backend implements it; flagged in the README.

  Future<Map<String, dynamic>> profile() async {
    final json = await _api.post(ApiEndpoints.merchantProfile);
    return unwrapData(json, fallback: 'Could not load profile.')['user'] as Map<String, dynamic>;
  }

  // NOTE: profileUpdate needs multipart (avatar upload) plus the full
  // onboarding-style field set (icno, address, equipment, company, bank
  // info) — see Api/Merchant/ProfileController::profileUpdate. Wire up
  // with dio's FormData + MultipartFile.fromFile when building the full
  // profile-edit screen, same pattern as rider's profileUpdate gap.

  /// Updates the merchant's own profile — matches
  /// Api/Merchant/ProfileController::profileUpdate exactly. [avatarPath]
  /// is optional (null means "don't change the current avatar").
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String mobileNo,
    required String icno,
    required String addressLine1,
    required String countryName,
    required String stateName,
    required String postcode,
    required String city,
    required int washerQuantity,
    required int dryerQuantity,
    required String companyName,
    required String ssmNo,
    required String bankName,
    required String bankNo,
    String? addressLine2,
    String? unitNo,
    String? block,
    double? latitude,
    double? longitude,
    String? avatarPath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'mobile_no': mobileNo,
      'icno': icno,
      'address_line_1': addressLine1,
      if (addressLine2 != null) 'address_line_2': addressLine2,
      if (unitNo != null) 'unit_no': unitNo,
      if (block != null) 'block': block,
      'country_name': countryName,
      'state_name': stateName,
      'postcode': postcode,
      'city': city,
      'washer_quantity': washerQuantity,
      'dryer_quantity': dryerQuantity,
      'company_name': companyName,
      'ssm_no': ssmNo,
      'bank_name': bankName,
      'bank_no': bankNo,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (avatarPath != null) 'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final json = await _api.post(ApiEndpoints.merchantProfileUpdate, data: formData);
    return unwrapData(json, fallback: 'Could not update profile.')['user'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listQrcodesForUser(int userId) async {
    final json = await _api.post(ApiEndpoints.merchantOrderQrcodes, data: {'user_id': userId});
    return (unwrapData(json)['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  /// Step: accept a pending job (code 21).
  Future<AssignJob> acceptOrder(int assignId) async {
    final json = await _api.post(ApiEndpoints.merchantOrderAccept, data: {'assign_id': assignId});
    return AssignJob.fromJson(unwrapData(json, fallback: 'Could not accept order.')['assign'] as Map<String, dynamic>);
  }

  /// Step: receive the bag the rider dropped off, start washing (code 22
  /// -> 23). The backend requires the rider to have already completed
  /// their own delivery-to-outlet step first — returns a clean "Rider
  /// not pickup yet." message if not, surfaced via ApiException.
  Future<Map<String, dynamic>> bagReceive(int assignId, {String? photoPath, String? remark}) async {
    final json = await _api.post(
      ApiEndpoints.merchantBagReceive,
      data: photoPath == null
          ? {'assign_id': assignId, if (remark != null) 'remark': remark}
          : FormData.fromMap({
              'assign_id': assignId,
              if (remark != null) 'remark': remark,
              'image': await MultipartFile.fromFile(photoPath),
            }),
    );
    return unwrapData(json, fallback: 'Could not receive bag.')['order'] as Map<String, dynamic>;
  }

  /// Step: mark the wash complete, ready for rider pickup (code 23 -> 24).
  Future<Map<String, dynamic>> washComplete(int assignId, {String? photoPath, String? remark}) async {
    final json = await _api.post(
      ApiEndpoints.merchantWashComplete,
      data: photoPath == null
          ? {'assign_id': assignId, if (remark != null) 'remark': remark}
          : FormData.fromMap({
              'assign_id': assignId,
              if (remark != null) 'remark': remark,
              'image': await MultipartFile.fromFile(photoPath),
            }),
    );
    return unwrapData(json, fallback: 'Could not mark wash complete.')['order'] as Map<String, dynamic>;
  }

  /// Scans a customer's bag QR to see their bookings for today — same
  /// shape as the rider scan flow.
  Future<List<Map<String, dynamic>>> scanQrcode({required String qrcode, required String type}) async {
    final json = await _api.post(ApiEndpoints.merchantScanQrcode, data: {
      'qrcode': qrcode,
      'type': type,
    });
    return (unwrapData(json)['booking'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> orderDetail({required int id, required bool isComplete}) async {
    final json = await _api.post(ApiEndpoints.merchantOrderDetail, data: {
      'id': id,
      'is_complete': isComplete,
    });
    // Response key differs: 'order' when is_complete, 'assign_job' otherwise.
    final data = unwrapData(json, fallback: 'Could not load order.');
    return (data['order'] ?? data['assign_job']) as Map<String, dynamic>;
  }

  /// Every activity this merchant has been involved in, newest first —
  /// same reasoning as the matching rider method.
  /// Every order this merchant has ever accepted, at any stage — see
  /// the matching comment on RiderRepository.activityHistory() for why
  /// this changed from an Activity-log query to a direct order query.
  Future<List<Map<String, dynamic>>> activityHistory() async {
    final json = await _api.post(ApiEndpoints.merchantActivityHistory);
    return (unwrapData(json, fallback: 'Could not load order history.')['orders']
            as List<dynamic>? ??
        [])
        .cast<Map<String, dynamic>>();
  }

  // NOTE: reApplyUpdate is a multipart form (IC front/back, SSM cert,
  // company/equipment/bank info) for merchants whose application was
  // rejected — see Api/Merchant/ReapplyController::reApplyUpdate for the
  // exact field list, same pattern as the rider re-apply gap.

  /// This merchant's Laravel database notifications, newest first — see
  /// Api/NotificationController::index. Unlike the other endpoints, the
  /// top-level `data` here is a raw JSON array (a serialized
  /// DatabaseNotificationCollection), not an object, so this can't go
  /// through unwrapData (which only handles `data` as a Map).
  Future<List<Map<String, dynamic>>> notifications() async {
    final json = await _api.post(ApiEndpoints.notificationIndex);
    if (json['status'] == false) {
      throw ApiException(json['message']?.toString() ?? 'Could not load notifications.');
    }
    return (json['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  /// Marks every notification as read — see
  /// Api/NotificationController::read_all.
  Future<void> markNotificationsRead() async {
    await _api.post(ApiEndpoints.notificationReadAll);
  }
}
