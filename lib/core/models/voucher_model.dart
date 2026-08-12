/// Mirrors app/Models/Voucher.php.
class Voucher {
  final int id;
  final String code;
  final String? description;
  final double? discountAmount;
  final double? discountPercent;

  Voucher({
    required this.id,
    required this.code,
    this.description,
    this.discountAmount,
    this.discountPercent,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['id'] as int,
        code: json['code']?.toString() ?? '',
        description: json['description']?.toString(),
        discountAmount: json['discount_amount'] != null
            ? double.tryParse(json['discount_amount'].toString())
            : null,
        discountPercent: json['discount_percent'] != null
            ? double.tryParse(json['discount_percent'].toString())
            : null,
      );
}
