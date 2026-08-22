import 'package:dio/dio.dart' show FormData, MultipartFile;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_data_helper.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/assign_job_model.dart';

class RiderRepository {
  RiderRepository(this._api);
  final ApiClient _api;

  /// Returns (isDuty, todayJobs, incomingJobs). See HomeController::home —
  /// jobs are pre-filtered by the backend to "pending action" ones only
  /// (its `$shouldShowPending` logic), split into today vs incoming by
  /// the booking's pickup_date.
  Future<({bool isDuty, List<AssignJob> today, List<AssignJob> incoming, List<AssignJob> active})> home() async {
    final json = await _api.post(ApiEndpoints.riderHome);
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
    await _api.post(ApiEndpoints.riderHomeDuty, data: {'is_duty': isDuty});
  }

  Future<Map<String, dynamic>> profile() async {
    final json = await _api.post(ApiEndpoints.riderProfile);
    return unwrapData(json, fallback: 'Could not load profile.')['user'] as Map<String, dynamic>;
  }

  // NOTE: profileUpdate needs multipart (avatar upload) plus a large set of
  // onboarding-style fields (icno, address, emergency contact, bank info) —
  // see RiderProfileController::profileUpdate. Wire up with dio's FormData +
  // MultipartFile.fromFile when building the full profile-edit screen.

  /// Updates the rider's own profile — matches
  /// RiderProfileController::profileUpdate exactly. [avatarPath] is
  /// optional (null means "don't change the current avatar").
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String mobileNo,
    required String icno,
    required String addressLine1,
    required String countryName,
    required String stateName,
    required String postcode,
    required String city,
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelation,
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
      'emergency_name': emergencyName,
      'country_code_emergency': '60',
      'emergency_phone': emergencyPhone,
      'emergency_relation': emergencyRelation,
      'bank_name': bankName,
      'bank_no': bankNo,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (avatarPath != null) 'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final json = await _api.post(ApiEndpoints.riderProfileUpdate, data: formData);
    return unwrapData(json, fallback: 'Could not update profile.')['user'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listQrcodesForUser(int userId) async {
    final json = await _api.post(ApiEndpoints.riderOrderQrcodes, data: {'user_id': userId});
    return (unwrapData(json)['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  /// Step: accept a pending job (code 11).
  Future<AssignJob> acceptOrder(int assignId) async {
    final json = await _api.post(ApiEndpoints.riderOrderAccept, data: {'assign_id': assignId});
    return AssignJob.fromJson(unwrapData(json, fallback: 'Could not accept order.')['assign'] as Map<String, dynamic>);
  }

  /// Step: confirm pickup from customer, en route to wash outlet (code 12).
  /// [photoPath]/[remark] are both optional — the backend accepts either
  /// a plain JSON call (old behavior) or multipart with a photo.
  Future<Map<String, dynamic>> pickupOrder(int assignId, {String? photoPath, String? remark}) async {
    final json = await _api.post(
      ApiEndpoints.riderOrderPickup,
      data: photoPath == null
          ? {'assign_id': assignId, if (remark != null) 'remark': remark}
          : FormData.fromMap({
              'assign_id': assignId,
              if (remark != null) 'remark': remark,
              'image': await MultipartFile.fromFile(photoPath),
            }),
    );
    return unwrapData(json, fallback: 'Could not confirm pickup.')['order'] as Map<String, dynamic>;
  }

  /// Step: confirm pickup of washed bag from the outlet (code 14).
  Future<Map<String, dynamic>> pickupWashOutletConfirm(int assignId, {String? photoPath, String? remark}) async {
    final json = await _api.post(
      ApiEndpoints.riderOrderPickupOutlet,
      data: photoPath == null
          ? {'assign_id': assignId, if (remark != null) 'remark': remark}
          : FormData.fromMap({
              'assign_id': assignId,
              if (remark != null) 'remark': remark,
              'image': await MultipartFile.fromFile(photoPath),
            }),
    );
    return unwrapData(json, fallback: 'Could not confirm pickup from outlet.')['order'] as Map<String, dynamic>;
  }

  /// Step: confirm delivery to customer (code 15) — also calculates and
  /// credits rider/merchant commission on the backend.
  /// Final delivery to customer — requires a photo, same as every other
  /// handoff step (backend validates `image` as required now).
  Future<Map<String, dynamic>> deliveryConfirm(int assignId, {required String photoPath, String? remark}) async {
    final json = await _api.post(
      ApiEndpoints.riderOrderDelivery,
      data: FormData.fromMap({
        'assign_id': assignId,
        if (remark != null) 'remark': remark,
        'image': await MultipartFile.fromFile(photoPath),
      }),
    );
    return unwrapData(json, fallback: 'Could not confirm delivery.')['assign'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> scanQrcode({required String qrcode, required String type}) async {
    final json = await _api.post(ApiEndpoints.riderScanQrcode, data: {
      'qrcode': qrcode,
      'type': type,
    });
    return (unwrapData(json)['booking'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> orderDetail({required int id, required bool isComplete}) async {
    final json = await _api.post(ApiEndpoints.riderOrderDetail, data: {
      'id': id,
      'is_complete': isComplete,
    });
    // Response key differs: 'order' when is_complete, 'assign_job' otherwise.
    final data = unwrapData(json, fallback: 'Could not load order.');
    return (data['order'] ?? data['assign_job']) as Map<String, dynamic>;
  }

  /// Every activity this rider has been involved in, newest first —
  /// including jobs that were cancelled by an admin, which previously
  /// just vanished from the dashboard with no explanation at all.
  /// Every order this rider has ever accepted, at any stage — active,
  /// completed, or cancelled. Previously relied on a sparse Activity
  /// log that only got a row at final delivery or admin cancellation,
  /// so an order still in progress never showed up here at all.
  Future<List<Map<String, dynamic>>> activityHistory() async {
    final json = await _api.post(ApiEndpoints.riderActivityHistory);
    return (unwrapData(json, fallback: 'Could not load order history.')['orders']
            as List<dynamic>? ??
        [])
        .cast<Map<String, dynamic>>();
  }

  // NOTE: reApplyUpdate is a large multipart form (IC front/back, license
  // front/back, JPJ grant, vehicle + bank + emergency contact info) for
  // riders whose application was rejected. Build as its own screen with
  // FormData when you get to the rejected-rider flow — see
  // RiderReapplyController::reApplyUpdate for the exact field list.

  /// This rider's Laravel database notifications, newest first — see
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
