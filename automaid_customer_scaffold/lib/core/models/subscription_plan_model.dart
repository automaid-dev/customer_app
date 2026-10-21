/// Mirrors one entry from POST /subscription/plans — the admin-configurable
/// bronze/silver/platinum tiers (Subscription::BRONZE / SILVER / PLATINUM
/// on the backend). Prices and quotas here are always live from Settings,
/// never hardcoded, so this app never needs updating if the admin changes
/// pricing.
class SubscriptionPlan {
  final String code; // 'bronze' | 'silver' | 'platinum'
  final String name;
  final double price;
  final int? orderQuota; // null = unlimited (platinum)
  final double drycleanDiscountPercent; // Settings > Dry Cleaning, per plan
  final int freeBagWashPerOrder; // Settings > No. of Bag for Free Wash

  SubscriptionPlan({
    required this.code,
    required this.name,
    required this.price,
    this.orderQuota,
    this.drycleanDiscountPercent = 0,
    this.freeBagWashPerOrder = 1,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => SubscriptionPlan(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        orderQuota: json['order_quota'] != null ? int.tryParse(json['order_quota'].toString()) : null,
        drycleanDiscountPercent:
            double.tryParse(json['dryclean_discount_percent']?.toString() ?? '') ?? 0,
        freeBagWashPerOrder: int.tryParse(json['free_bag_wash_per_order']?.toString() ?? '') ?? 1,
      );

  bool get isPlatinum => code.trim().toLowerCase() == 'platinum';

  /// Marketing copy shown on the plan card — same wording as the website.
  String get tagline => switch (code.trim().toLowerCase()) {
        'bronze' => 'Light & occasional',
        'silver' => 'Steady household',
        'platinum' => 'Unlimited',
        _ => name,
      };

  String get audience => switch (code.trim().toLowerCase()) {
        'bronze' => 'Good for solo households or light users',
        'silver' => 'Best for couples or small families',
        'platinum' => 'Best for families & heavy laundry weeks',
        _ => '',
      };

  String get quotaLabel => orderQuota == null ? 'Unlimited orders' : '$orderQuota orders / month';
}
