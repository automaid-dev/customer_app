import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/addon_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/setting_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/models/voucher_model.dart';

/// Every method here maps 1:1 to a route under the `customer` prefix in
/// routes/api.php. Kept as one repository (rather than splitting per
/// screen) because that's how the backend groups them too — makes it easy
/// to check "does this exist on the backend?" by searching this file.
class CustomerRepository {
  CustomerRepository(this._api);
  final ApiClient _api;

  // ---- Home / announcements ----

  /// Returns active (non-delivered, non-cancelled) bookings for the dashboard.
  Future<List<BookingSummary>> home() async {
    final json = await _api.post(ApiEndpoints.customerHome);
    final bookings = (json['data']?['bookings'] as List<dynamic>? ?? []);
    return bookings
        .map((b) => BookingSummary.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> announcements() async {
    final json = await _api.post(ApiEndpoints.customerAnnouncements);
    return (json['data']?['announcements'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ---- Settings (public, but used throughout the customer flow) ----

  Future<AppSetting> setting() async {
    final json = await _api.post(ApiEndpoints.setting);
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return AppSetting.fromJson(data);
  }

  // ---- Addresses ----

  Future<Address> saveAddress(Address address) async {
    final json = await _api.post(ApiEndpoints.customerAddressStore,
        data: address.toRequestBody());
    return Address.fromJson(json['data']['address'] as Map<String, dynamic>);
  }

  Future<Address> updateAddress(Address address) async {
    final json = await _api.post(ApiEndpoints.customerAddressUpdate,
        data: address.toRequestBody(addressId: address.id));
    return Address.fromJson(json['data']['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int addressId) async {
    await _api.post(ApiEndpoints.customerAddressDelete, data: {'address_id': addressId});
  }

  // ---- Bag / QR ----

  /// Retrieves a random pending QR code to print/assign to a newly purchased bag.
  Future<Map<String, dynamic>> bagQrcode() async {
    final json = await _api.post(ApiEndpoints.customerBagQrcode);
    return json['data']['qrcode'] as Map<String, dynamic>;
  }

  /// Scans (or manually enters) a bag's QR code to claim it.
  /// [type] must be 'scan' or 'manual' (anything else is treated as manual by the backend).
  Future<Map<String, dynamic>> bagScan({required String qrcode, required String type}) async {
    final json = await _api.post(ApiEndpoints.customerBagScan, data: {
      'qrcode': qrcode,
      'type': type,
    });
    return json['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> bagPurchased() async {
    final json = await _api.post(ApiEndpoints.customerBagPurchased);
    return (json['data']?['bag_purchases'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> bagAssigned() async {
    final json = await _api.post(ApiEndpoints.customerBagAssigned);
    return (json['data']?['bag_assigns'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  /// Purchases a bag (or claims the free first bag — backend auto-detects
  /// quantity==1 && grand_total==0 as a free claim, no payment gateway call).
  /// Returns either {'order': ...} (free claim, immediate) or {'url': ...}
  /// (paid — caller must open this payment URL, e.g. in a WebView).
  Future<Map<String, dynamic>> purchaseBag({
    required String billingName,
    required String billingEmail,
    required String billingPhone,
    required Address address,
    required int quantity,
    required double subTotal,
    required double grandTotal,
  }) async {
    final json = await _api.post(ApiEndpoints.customerOrderBagPlaceOrder, data: {
      'billing_name': billingName,
      'billing_email': billingEmail,
      'billing_phone': billingPhone,
      'billing_address_line_1': address.addressLine1,
      'billing_country': address.countryName,
      'billing_state': address.stateName,
      'billing_postcode': address.postcode,
      'billing_city': address.city,
      'delivery_address_line_1': address.addressLine1,
      'delivery_country': address.countryName,
      'delivery_state': address.stateName,
      'delivery_postcode': address.postcode,
      'delivery_city': address.city,
      'sub_total': subTotal,
      'quantity': quantity,
      'grand_total': grandTotal,
    });
    return json['data'] as Map<String, dynamic>;
  }

  /// Assigns available QR codes to any purchased-but-unassigned bags.
  Future<List<Map<String, dynamic>>> assignQrcode() async {
    final json = await _api.post(ApiEndpoints.customerQrcodeAssign);
    return (json['data']?['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---- Booking (new pickup) ----

  /// Step 1: get washing_charge + delivery_change (sic — backend key, not a typo
  /// on our side) for a given bag quantity.
  Future<({double washingCharge, double deliveryCharge})> calculateRate(int bagQuantity) async {
    final json = await _api.post(ApiEndpoints.customerBookingCalculateRate, data: {
      'pickup_bag_quantity': bagQuantity,
    });
    final data = json['data'] as Map<String, dynamic>;
    return (
      washingCharge: double.tryParse(data['washing_charge']?.toString() ?? '') ?? 0,
      deliveryCharge: double.tryParse(data['delivery_change']?.toString() ?? '') ?? 0,
    );
  }

  Future<List<AddOn>> addOnList() async {
    final json = await _api.post(ApiEndpoints.customerBookingAddonList);
    return (json['data']?['addons'] as List<dynamic>? ?? [])
        .map((a) => AddOn.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<Voucher?> checkVoucher(String code) async {
    final json = await _api.post(ApiEndpoints.customerBookingVoucher, data: {'code': code});
    if (json['status'] != true) return null; // not found / inactive / already used / limit reached
    return Voucher.fromJson(json['data']['voucher'] as Map<String, dynamic>);
  }

  Future<List<Voucher>> voucherList() async {
    final json = await _api.post(ApiEndpoints.customerBookingVoucherList);
    return (json['data']?['vouchers'] as List<dynamic>? ?? [])
        .map((v) => Voucher.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Scanned QR codes available to attach to a new booking.
  Future<List<Map<String, dynamic>>> bookingQrcodes() async {
    final json = await _api.post(ApiEndpoints.customerBookingQrcodes);
    return (json['data']?['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<double> checkAddonDiscount(double totalAddonCharge) async {
    final json = await _api.post(ApiEndpoints.customerBookingAddonCheckDiscount, data: {
      'total_addon_charge': totalAddonCharge,
    });
    return double.tryParse(json['data']?['total_addon_discount']?.toString() ?? '') ?? 0;
  }

  Future<double> checkInsurance() async {
    final json = await _api.post(ApiEndpoints.customerBookingInsuranceCheck);
    return double.tryParse(json['data']?['insurance_fee']?.toString() ?? '') ?? 0;
  }

  /// Returns null if no birthday reward is available; otherwise the reward amount.
  /// [isAlreadyClaimed] mirrors the backend's `is_claim` flag.
  Future<({double? amount, bool isAlreadyClaimed})> checkBirthday() async {
    final json = await _api.post(ApiEndpoints.customerBookingBirthdayCheck);
    final claimed = json['is_claim'] == 1;
    final amount = json['status'] == true
        ? double.tryParse(json['data']?['birthday_reward_amount']?.toString() ?? '')
        : null;
    return (amount: amount, isAlreadyClaimed: claimed);
  }

  /// Final step: places the booking. `qrcodes` is a list of series_no strings
  /// (backend expects a JSON-encoded string of the array — see BookingController::schedule).
  /// Returns either {'booking': ...} (paid via subscription or zero total — instant)
  /// or {'url': ...} (needs payment gateway).
  Future<Map<String, dynamic>> schedule({
    required int pickupLocationId,
    required DateTime pickupDate,
    required int pickupBagQuantity,
    required String pickupStartTime,
    required String pickupEndTime,
    required double deliveryCharge,
    required double washingCharge,
    required List<String> qrcodeSeriesNumbers,
    String? voucherCode,
    List<int>? addonIds,
    double? tax,
    double? addonCharge,
    double? discount,
    double? addonDiscount,
    double? insuranceFee,
    double? birthdayReward,
    bool isFolding = true,
  }) async {
    final json = await _api.post(ApiEndpoints.customerBookingSchedule, data: {
      'pickup_location_id': pickupLocationId,
      'pickup_date': pickupDate.toIso8601String().split('T').first,
      'pickup_bag_quantity': pickupBagQuantity,
      'pickup_start_time': pickupStartTime,
      'pickup_end_time': pickupEndTime,
      'delivery_charge': deliveryCharge,
      'washing_charge': washingCharge,
      'qrcodes': qrcodeSeriesNumbers, // dio encodes this; backend json_decodes it
      if (voucherCode != null) 'voucher_code': voucherCode,
      if (addonIds != null) 'addons': addonIds,
      if (tax != null) 'tax': tax,
      if (addonCharge != null) 'addon_charge': addonCharge,
      if (discount != null) 'discount': discount,
      if (addonDiscount != null) 'addon_discount': addonDiscount,
      if (insuranceFee != null) 'insurance_fee': insuranceFee,
      if (birthdayReward != null) 'birthday_reward': birthdayReward,
      'is_folding': isFolding ? 1 : 0,
    });
    return json['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveInstructions({
    required int bookingId,
    String? landmark,
  }) async {
    final json = await _api.post(ApiEndpoints.customerBookingInstructions, data: {
      'booking_id': bookingId,
      if (landmark != null) 'landmark': landmark,
      // landmark_picture upload needs multipart — wire up with dio's FormData
      // + MultipartFile.fromFile when building the actual instructions screen.
    });
    return json['data']['booking'] as Map<String, dynamic>;
  }

  // ---- Orders ----

  Future<Map<String, dynamic>> orderDetail(int orderId) async {
    final json = await _api.post(ApiEndpoints.customerOrderDetail, data: {'order_id': orderId});
    return json['data']['order'] as Map<String, dynamic>;
  }

  /// NOTE: as of this backend version, OrderController::orderActive and
  /// orderUpcoming don't actually return any list data (the controller
  /// methods query but never assign to `$data` or return a payload) —
  /// this is a backend gap, not a mistake in this client. Use `home()`
  /// (which correctly returns active bookings) until the backend is fixed;
  /// these two are wired up so they start working the moment the backend does.
  Future<Map<String, dynamic>> orderActive() => _api.post(ApiEndpoints.customerOrderActive);
  Future<Map<String, dynamic>> orderUpcoming() => _api.post(ApiEndpoints.customerOrderUpcoming);

  Future<Map<String, dynamic>> rateOrder({
    required int orderId,
    int? riderStars,
    String? riderComment,
    int? merchantStars,
    String? merchantComment,
  }) async {
    final json = await _api.post(ApiEndpoints.customerOrderRating, data: {
      'order_id': orderId,
      if (riderStars != null) 'rate_rider_star': riderStars,
      if (riderComment != null) 'rate_rider_comment': riderComment,
      if (merchantStars != null) 'rate_merchant_star': merchantStars,
      if (merchantComment != null) 'rate_merchant_comment': merchantComment,
    });
    return json['data']['booking'] as Map<String, dynamic>;
  }

  // ---- Subscription ----

  /// Live prices/quotas for all three tiers — always call this rather than
  /// hardcoding prices client-side, since the admin can change them anytime
  /// in Settings > Subscription Fees/Discounts.
  Future<List<SubscriptionPlan>> subscriptionPlans() async {
    final json = await _api.post(ApiEndpoints.subscriptionPlans);
    final plans = (json['data']?['plans'] as List<dynamic>? ?? []);
    return plans.map((p) => SubscriptionPlan.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// [planCode] must be 'bronze', 'silver', or 'platinum' (see
  /// SubscriptionPlan.code from subscriptionPlans() above). The backend
  /// derives the actual price from the plan server-side — sub_total here
  /// is only for the request-validation rule and display consistency, it
  /// is never trusted for billing (see SubscriptionController::placeOrder).
  Future<Map<String, dynamic>> subscribe({
    required String planCode,
    required String billingName,
    required String billingEmail,
    required String billingPhone,
    required Address address,
    required double subTotal,
  }) async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionPlaceOrder, data: {
      'plan_code': planCode,
      'billing_name': billingName,
      'billing_email': billingEmail,
      'billing_phone': billingPhone,
      'billing_address_line_1': address.addressLine1,
      'billing_country': address.countryName,
      'billing_state': address.stateName,
      'billing_postcode': address.postcode,
      'billing_city': address.city,
      'delivery_address_line_1': address.addressLine1,
      'delivery_country': address.countryName,
      'delivery_state': address.stateName,
      'delivery_postcode': address.postcode,
      'delivery_city': address.city,
      'sub_total': subTotal,
    });
    // Always returns a payment URL (subscription always goes through the
    // recurring payment gateway) — open json['data']['url'] in a WebView.
    return json['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSubscription() async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionUpdate);
    return json['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelSubscription() async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionCancel);
    return json['data']['unsubscribe'] as Map<String, dynamic>;
  }

  // ---- Shared profile (customer-scoped) ----

  Future<Map<String, dynamic>> profile() async {
    final json = await _api.post(ApiEndpoints.customerProfile);
    return json['data']['user'] as Map<String, dynamic>;
  }
}
