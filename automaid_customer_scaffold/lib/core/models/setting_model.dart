/// Mirrors the single Setting row (Setting::find(1)) the backend reads
/// pricing/config from. Returned by POST /setting.
class AppSetting {
  final double washFee;
  final double deliveryPrice;
  final int totalBagFreeWash;
  final int totalBagFreeDelivery;
  final double subscriptionPrice;
  final double insuranceFee;
  final double discountPercent;
  final double discountLimit;
  final double birthdayRewardAmount;

  AppSetting({
    required this.washFee,
    required this.deliveryPrice,
    required this.totalBagFreeWash,
    required this.totalBagFreeDelivery,
    required this.subscriptionPrice,
    required this.insuranceFee,
    required this.discountPercent,
    required this.discountLimit,
    required this.birthdayRewardAmount,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
        washFee: _d(json['wash_fee']),
        deliveryPrice: _d(json['delivery_price']),
        totalBagFreeWash: int.tryParse(json['total_bag_free_wash']?.toString() ?? '') ?? 0,
        totalBagFreeDelivery:
            int.tryParse(json['total_bag_free_delivery']?.toString() ?? '') ?? 0,
        subscriptionPrice: _d(json['subscription_price']),
        insuranceFee: _d(json['insurance_fee']),
        discountPercent: _d(json['discount_percent']),
        discountLimit: _d(json['discount_limit']),
        birthdayRewardAmount: _d(json['birthday_reward_amount']),
      );

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
}
