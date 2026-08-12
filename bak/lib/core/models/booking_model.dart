/// The backend returns `Booking` with a deeply nested `order` relation
/// (order_addons, qrcode_users, customer_and_rider_status, delivered, etc.)
/// whose exact shape varies by endpoint (home / orderDetail / schedule /
/// orderRating all eager-load slightly different relations).
///
/// Rather than modeling every nested relation up front (which would need
/// constant updates as the backend's `->load([...])` calls change), this
/// wrapper extracts the handful of top-level fields every screen needs and
/// keeps the full raw JSON available via [raw] for anything else —
/// e.g. `booking.raw['customer_and_rider_status']`.
class BookingSummary {
  final int id;
  final int orderId;
  final String status; // Booking::ACTIVE / PENDING / CANCEL
  final DateTime? pickupDate;
  final String? pickupStartTime;
  final String? pickupEndTime;
  final int pickupBagQuantity;
  final double grandTotal;
  final String? landmark;
  final Map<String, dynamic> raw;

  BookingSummary({
    required this.id,
    required this.orderId,
    required this.status,
    required this.pickupBagQuantity,
    required this.grandTotal,
    required this.raw,
    this.pickupDate,
    this.pickupStartTime,
    this.pickupEndTime,
    this.landmark,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    return BookingSummary(
      id: json['id'] as int,
      orderId: json['order_id'] as int? ?? 0,
      status: json['status']?.toString() ?? '',
      pickupDate:
          json['pickup_date'] != null ? DateTime.tryParse(json['pickup_date'].toString()) : null,
      pickupStartTime: json['pickup_start_time']?.toString(),
      pickupEndTime: json['pickup_end_time']?.toString(),
      pickupBagQuantity: int.tryParse(json['pickup_bag_quantity']?.toString() ?? '') ?? 0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '') ?? 0,
      landmark: json['landmark']?.toString(),
      raw: json,
    );
  }

  /// The nested `order` object, if the endpoint loaded it — check the
  /// controller's `->load([...])` call to know what's inside for a given screen.
  Map<String, dynamic>? get order => raw['order'] as Map<String, dynamic>?;
}

/// Wraps an `Order` row directly (used by orderDetail, which returns the
/// order — not a booking — as the primary object, with `booking` nested inside).
class OrderSummary {
  final int id;
  final String orderType; // Order::BOOKING / PURCHASE_BAG / SUBSCRIPTION / ...
  final String status; // Order::PENDING / PAID / ...
  final int quantity;
  final double grandTotal;
  final String? seriesNo;
  final Map<String, dynamic> raw;

  OrderSummary({
    required this.id,
    required this.orderType,
    required this.status,
    required this.quantity,
    required this.grandTotal,
    required this.raw,
    this.seriesNo,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: json['id'] as int,
      orderType: json['order_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '') ?? 0,
      seriesNo: json['series_no']?.toString(),
      raw: json,
    );
  }

  Map<String, dynamic>? get booking => raw['booking'] as Map<String, dynamic>?;

  /// Present only once the order has been delivered — see OrderController::orderRating,
  /// which reads/writes rate_rider_star, rate_rider_comment, rate_merchant_star,
  /// rate_merchant_comment on this relation.
  Map<String, dynamic>? get delivered => raw['delivered'] as Map<String, dynamic>?;
}
