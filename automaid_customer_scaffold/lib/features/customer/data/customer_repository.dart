import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/addon_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/models/setting_model.dart';
import '../../../core/models/state_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/models/voucher_model.dart';

/// Every method here maps 1:1 to a route under the `customer` prefix in
/// routes/api.php. Kept as one repository (rather than splitting per
/// screen) because that's how the backend groups them too — makes it easy
/// to check "does this exist on the backend?" by searching this file.
class CustomerRepository {
  CustomerRepository(this._api);
  final ApiClient _api;

  /// The backend returns HTTP 200 for almost everything, including
  /// business-logic failures — it signals failure via a `status: false`
  /// flag in the body, not an HTTP error code. ApiClient only converts
  /// actual HTTP errors into ApiException, so every method here must
  /// check `status` itself before assuming `data` is present and
  /// shaped as expected. Route every `json['data']` access through this
  /// helper instead of indexing directly — a raw `json['data']['x']` on a
  /// status:false response (which usually has no `data` key at all)
  /// throws an unhandled Dart type error instead of a catchable
  /// ApiException, which silently breaks the calling screen with no
  /// visible error (exactly the "nothing happens" bug this fixes).
  Map<String, dynamic> _data(Map<String, dynamic> json, {String fallback = 'Request failed.'}) {
    if (json['status'] == false) {
      final errors =
          json['errors'] is Map<String, dynamic> ? json['errors'] as Map<String, dynamic> : null;
      throw ApiException(_describeFailure(json, errors, fallback), errors: errors);
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// Turns a Laravel-style {"field": ["reason", ...]} error bag into a
  /// readable multi-line message. Falls back to the top-level `message`
  /// (which is often just a generic "Validation error") only when there's
  /// no per-field detail to show instead.
  String _describeFailure(
    Map<String, dynamic> json,
    Map<String, dynamic>? errors,
    String fallback,
  ) {
    if (errors != null && errors.isNotEmpty) {
      final lines = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          lines.addAll(value.map((v) => v.toString()));
        } else if (value != null) {
          lines.add(value.toString());
        }
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }
    return json['message']?.toString() ?? fallback;
  }

  // ---- Reference data ----

  /// Fetches the live list of Malaysian states from the backend's own
  /// seeded data — use this instead of free-text state entry. The exact
  /// names here matter (e.g. the Kuala Lumpur federal territory is seeded
  /// as "Wp Kuala Lumpur", not "Kuala Lumpur"), so picking from this list
  /// guarantees whatever the customer selects will match on save.
  Future<List<StateModel>> states() async {
    final json = await _api.post(ApiEndpoints.states);
    final list = (_data(json)['states'] as List<dynamic>? ?? []);
    return list.map((s) => StateModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// After the payment WebView reports the gateway flow reached its
  /// return page, this is the actual source of truth: poll the order's
  /// own status a few times (the webhook that flips it to Order::PAID
  /// can take a moment to arrive after the redirect) rather than trusting
  /// anything from the gateway's page itself. Returns true once the order
  /// shows as paid, false if it still hasn't after all attempts (doesn't
  /// necessarily mean failure — the person can check back in My Bags /
  /// My Orders shortly).
  Future<bool> waitForPaymentConfirmation(
    int orderId, {
    int attempts = 5,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final order = await orderDetail(orderId);
        if (order['status'] == 'paid') return true;
      } catch (_) {
        // keep retrying — a transient error here shouldn't give up early
      }
      if (i < attempts - 1) await Future.delayed(interval);
    }
    return false;
  }

  // ---- Home / announcements ----

  /// Returns active (non-delivered, non-cancelled) bookings for the dashboard.
  Future<List<BookingSummary>> home() async {
    final json = await _api.post(ApiEndpoints.customerHome);
    final bookings = (_data(json)['bookings'] as List<dynamic>? ?? []);
    return bookings
        .map((b) => BookingSummary.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> announcements() async {
    final json = await _api.post(ApiEndpoints.customerAnnouncements);
    return (_data(json)['announcements'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ---- Settings (public, but used throughout the customer flow) ----

  Future<AppSetting> setting() async {
    final json = await _api.post(ApiEndpoints.setting);
    // SettingController::setting returns the row under a `setting` key,
    // not `data` (unlike almost every other endpoint in this backend) —
    // reading `data` here silently zeroed out every single field on
    // AppSetting (bag price, wash fee, delivery price, all of it), not
    // just the one that happened to get noticed first.
    final data = json['setting'] as Map<String, dynamic>? ?? {};
    return AppSetting.fromJson(data);
  }

  // ---- Addresses ----

  Future<Address> saveAddress(Address address) async {
    final json = await _api.post(ApiEndpoints.customerAddressStore,
        data: address.toRequestBody());
    return Address.fromJson(
        _data(json, fallback: 'Could not save address.')['address'] as Map<String, dynamic>);
  }

  Future<Address> updateAddress(Address address) async {
    final json = await _api.post(ApiEndpoints.customerAddressUpdate,
        data: address.toRequestBody(addressId: address.id));
    return Address.fromJson(
        _data(json, fallback: 'Could not update address.')['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int addressId) async {
    final json =
        await _api.post(ApiEndpoints.customerAddressDelete, data: {'address_id': addressId});
    _data(json, fallback: 'Could not delete address.');
  }

  // ---- Bag / QR ----

  /// Retrieves a random pending QR code to print/assign to a newly purchased bag.
  Future<Map<String, dynamic>> bagQrcode() async {
    final json = await _api.post(ApiEndpoints.customerBagQrcode);
    return _data(json)['qrcode'] as Map<String, dynamic>;
  }

  /// Scans (or manually enters) a bag's QR code to claim it.
  /// [type] must be 'scan' or 'manual' (anything else is treated as manual by the backend).
  Future<Map<String, dynamic>> bagScan({required String qrcode, required String type}) async {
    final json = await _api.post(ApiEndpoints.customerBagScan, data: {
      'qrcode': qrcode,
      'type': type,
    });
    return _data(json, fallback: 'Could not scan this bag.');
  }

  Future<List<Map<String, dynamic>>> bagPurchased() async {
    final json = await _api.post(ApiEndpoints.customerBagPurchased);
    return (_data(json)['bag_purchases'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> bagAssigned() async {
    final json = await _api.post(ApiEndpoints.customerBagAssigned);
    return (_data(json)['bag_assigns'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
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
    return _data(json, fallback: 'Could not purchase bag.');
  }

  /// Assigns available QR codes to any purchased-but-unassigned bags.
  Future<List<Map<String, dynamic>>> assignQrcode() async {
    final json = await _api.post(ApiEndpoints.customerQrcodeAssign);
    return (_data(json)['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---- Booking (new pickup) ----

  /// Step 1: get washing_charge + delivery_change (sic — backend key, not a typo
  /// on our side) + SST for a given bag quantity.
  Future<({double washingCharge, double deliveryCharge, double sstPercent, double taxCharge})> calculateRate(
      int bagQuantity) async {
    final json = await _api.post(ApiEndpoints.customerBookingCalculateRate, data: {
      'pickup_bag_quantity': bagQuantity,
    });
    final data = _data(json, fallback: 'Could not calculate rate.');
    return (
      washingCharge: double.tryParse(data['washing_charge']?.toString() ?? '') ?? 0,
      deliveryCharge: double.tryParse(data['delivery_change']?.toString() ?? '') ?? 0,
      sstPercent: double.tryParse(data['sst_percent']?.toString() ?? '') ?? 0,
      taxCharge: double.tryParse(data['tax_charge']?.toString() ?? '') ?? 0,
    );
  }

  Future<List<AddOn>> addOnList() async {
    final json = await _api.post(ApiEndpoints.customerBookingAddonList);
    return (_data(json)['addons'] as List<dynamic>? ?? [])
        .map((a) => AddOn.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<Voucher?> checkVoucher(String code) async {
    final json = await _api.post(ApiEndpoints.customerBookingVoucher, data: {'code': code});
    if (json['status'] != true) return null; // not found / inactive / already used / limit reached
    return Voucher.fromJson(_data(json)['voucher'] as Map<String, dynamic>);
  }

  Future<List<Voucher>> voucherList() async {
    final json = await _api.post(ApiEndpoints.customerBookingVoucherList);
    return (_data(json)['vouchers'] as List<dynamic>? ?? [])
        .map((v) => Voucher.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Scanned QR codes available to attach to a new booking.
  Future<List<Map<String, dynamic>>> bookingQrcodes() async {
    final json = await _api.post(ApiEndpoints.customerBookingQrcodes);
    return (_data(json)['qrcodes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<double> checkAddonDiscount(double totalAddonCharge) async {
    final json = await _api.post(ApiEndpoints.customerBookingAddonCheckDiscount, data: {
      'total_addon_charge': totalAddonCharge,
    });
    return double.tryParse(_data(json)['total_addon_discount']?.toString() ?? '') ?? 0;
  }

  Future<double> checkInsurance() async {
    final json = await _api.post(ApiEndpoints.customerBookingInsuranceCheck);
    return double.tryParse(_data(json)['insurance_fee']?.toString() ?? '') ?? 0;
  }

  /// Returns null if no birthday reward is available; otherwise the reward amount.
  /// [isAlreadyClaimed] mirrors the backend's `is_claim` flag.
  Future<({double? amount, bool isAlreadyClaimed})> checkBirthday() async {
    final json = await _api.post(ApiEndpoints.customerBookingBirthdayCheck);
    final claimed = json['is_claim'] == 1;
    final amount = json['status'] == true
        ? double.tryParse(_data(json)['birthday_reward_amount']?.toString() ?? '')
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
      'qrcodes': jsonEncode(qrcodeSeriesNumbers), // backend validates this as a string, then json_decodes it server-side
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
    return _data(json, fallback: 'Could not place booking.');
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
    return _data(json, fallback: 'Could not save instructions.')['booking'] as Map<String, dynamic>;
  }

  // ---- Orders ----

  Future<Map<String, dynamic>> orderDetail(int orderId) async {
    final json = await _api.post(ApiEndpoints.customerOrderDetail, data: {'order_id': orderId});
    return _data(json, fallback: 'Could not load order.')['order'] as Map<String, dynamic>;
  }

  /// Every order for this customer, any status (including cancelled) —
  /// now genuinely implemented server-side. Previously a backend stub
  /// that never returned data, so the order list screen worked around
  /// it by reusing the home dashboard's "active bookings" only — which
  /// is why a cancelled order never showed up anywhere at all.
  Future<List<Map<String, dynamic>>> orderHistory() async {
    final json = await _api.post(ApiEndpoints.customerOrderActive);
    return (_data(json, fallback: 'Could not load orders.')['orders'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

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
    return _data(json, fallback: 'Could not submit rating.')['booking'] as Map<String, dynamic>;
  }

  // ---- Subscription ----

  /// Live prices/quotas for all three tiers — always call this rather than
  /// hardcoding prices client-side, since the admin can change them anytime
  /// in Settings > Subscription Fees/Discounts.
  Future<List<SubscriptionPlan>> subscriptionPlans() async {
    final json = await _api.post(ApiEndpoints.subscriptionPlans);
    final plans = (_data(json)['plans'] as List<dynamic>? ?? []);
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
    // recurring payment gateway) — open data['url'] in a WebView.
    return _data(json, fallback: 'Could not subscribe.');
  }

  /// Upgrades the customer's active subscription to a higher tier.
  /// [planCode] must be a strictly higher tier than their current plan —
  /// the backend rejects downgrades here. Returns a payment URL for the
  /// topup amount (the flat price difference, not the full new-plan
  /// price) plus order_id for verification, same pattern as subscribe().
  /// On confirmed payment, the backend switches plan_code on the
  /// existing subscription and resets this cycle's order-quota usage —
  /// no new subscription record, no additional address/billing fields
  /// needed since the existing subscription's billing info carries over.
  Future<Map<String, dynamic>> upgradeSubscription({
    required String planCode,
    required String billingName,
    required String billingEmail,
    required String billingPhone,
    required Address address,
  }) async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionUpgrade, data: {
      'plan_code': planCode,
      'billing_name': billingName,
      'billing_email': billingEmail,
      'billing_phone': billingPhone,
      'billing_address_line_1': address.addressLine1,
      'billing_country': address.countryName,
      'billing_state': address.stateName,
      'billing_postcode': address.postcode,
      'billing_city': address.city,
    });
    return _data(json, fallback: 'Could not upgrade subscription.');
  }

  /// Every subscription-related order for this customer (initial
  /// subscribe, renewals, card updates, upgrades) — for the Subscription
  /// History screen. Each entry's `id` can be passed straight to
  /// [orderDetail] to build a receipt, same as bag purchase receipts do.
  Future<List<Map<String, dynamic>>> subscriptionHistory() async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionHistory);
    return (_data(json, fallback: 'Could not load subscription history.')['orders']
            as List<dynamic>? ??
        [])
        .cast<Map<String, dynamic>>();
  }

  /// Returns (notifications, unreadCount) — POST /customer/notifications.
  Future<({List<AppNotification> notifications, int unreadCount})> notifications() async {
    final json = await _api.post(ApiEndpoints.customerNotifications);
    final data = _data(json, fallback: 'Could not load notifications.');
    final list = (data['notifications'] as List<dynamic>? ?? [])
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    return (notifications: list, unreadCount: data['unread_count'] as int? ?? 0);
  }

  /// Marks one notification read (pass [id]), or every unread
  /// notification if [id] is omitted.
  Future<void> markNotificationsRead({int? id}) async {
    final json = await _api.post(ApiEndpoints.customerNotificationsRead, data: {
      if (id != null) 'id': id,
    });
    _data(json, fallback: 'Could not update notifications.');
  }

  Future<Map<String, dynamic>> updateSubscription() async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionUpdate);
    return _data(json, fallback: 'Could not update subscription.');
  }

  Future<Map<String, dynamic>> cancelSubscription() async {
    final json = await _api.post(ApiEndpoints.customerSubscriptionCancel);
    return _data(json, fallback: 'Could not cancel subscription.')['unsubscribe']
        as Map<String, dynamic>;
  }

  // ---- Shared profile (customer-scoped) ----

  Future<Map<String, dynamic>> profile() async {
    final json = await _api.post(ApiEndpoints.customerProfile);
    return _data(json, fallback: 'Could not load profile.')['user'] as Map<String, dynamic>;
  }

  /// The customer's subscription, if any — profile() already eager-loads
  /// this relation (ProfileController::profile -> 'subscribe.order'), so
  /// no separate endpoint is needed. Null if they've never subscribed.
  /// Check the `status` field (Subscription::ACTIVE/PENDING/CANCELLED/INACTIVE)
  /// before treating it as a live subscription — a cancelled or pending
  /// one is still present here, just not currently active.
  Future<Map<String, dynamic>?> currentSubscription() async {
    final user = await profile();
    return user['subscribe'] as Map<String, dynamic>?;
  }
}
