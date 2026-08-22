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

  SubscriptionPlan({
    required this.code,
    required this.name,
    required this.price,
    this.orderQuota,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => SubscriptionPlan(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        orderQuota: json['order_quota'] != null ? int.tryParse(json['order_quota'].toString()) : null,
      );

  String get quotaLabel => orderQuota == null ? 'Unlimited orders' : '$orderQuota orders / month';
}
