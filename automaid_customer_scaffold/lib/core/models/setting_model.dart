/// Mirrors the single Setting row (Setting::find(1)) the backend reads
/// pricing/config from. Returned by POST /setting.
class AppSetting {
  final double washFee;
  final double deliveryPrice;
  final double bagPrice;
  final int totalBagFreeWash;
  final int totalBagFreeDelivery;
  final double subscriptionPrice;
  final double insuranceFee;
  final double discountPercent;
  final double discountLimit;
  final double birthdayRewardAmount;
  final String? termsConditionsUrl;
  final String? companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyRegistrationNo;
  final String? sameDayCutoffTime;

  AppSetting({
    required this.washFee,
    required this.deliveryPrice,
    required this.bagPrice,
    required this.totalBagFreeWash,
    required this.totalBagFreeDelivery,
    required this.subscriptionPrice,
    required this.insuranceFee,
    required this.discountPercent,
    required this.discountLimit,
    required this.birthdayRewardAmount,
    this.termsConditionsUrl,
    this.companyName,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
    this.companyRegistrationNo,
    this.sameDayCutoffTime,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
        washFee: _d(json['wash_fee']),
        deliveryPrice: _d(json['delivery_price']),
        bagPrice: _d(json['bag_price']),
        totalBagFreeWash: int.tryParse(json['total_bag_free_wash']?.toString() ?? '') ?? 0,
        totalBagFreeDelivery:
            int.tryParse(json['total_bag_free_delivery']?.toString() ?? '') ?? 0,
        subscriptionPrice: _d(json['subscription_price']),
        insuranceFee: _d(json['insurance_fee']),
        discountPercent: _d(json['discount_percent']),
        discountLimit: _d(json['discount_limit']),
        birthdayRewardAmount: _d(json['birthday_reward_amount']),
        termsConditionsUrl: json['terms_conditions_url']?.toString(),
        companyName: json['company_name']?.toString(),
        companyAddress: json['company_address']?.toString(),
        companyPhone: json['company_phone']?.toString(),
        companyEmail: json['company_email']?.toString(),
        companyRegistrationNo: json['company_registration_no']?.toString(),
        sameDayCutoffTime: json['same_day_cutoff_time']?.toString(),
      );

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
}
