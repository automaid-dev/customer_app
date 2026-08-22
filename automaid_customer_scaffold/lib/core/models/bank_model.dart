/// Mirrors one row from POST /banks/index — used for the bank-name
/// dropdown on rider/merchant registration's bank details step.
class BankModel {
  final int id;
  final String name;

  BankModel({required this.id, required this.name});

  factory BankModel.fromJson(Map<String, dynamic> json) => BankModel(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
      );
}
