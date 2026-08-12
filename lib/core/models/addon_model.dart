/// Mirrors app/Models/AddOn.php.
class AddOn {
  final int id;
  final String name;
  final double price;
  final String? description;

  AddOn({required this.id, required this.name, required this.price, this.description});

  factory AddOn.fromJson(Map<String, dynamic> json) => AddOn(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        description: json['description']?.toString(),
      );
}
