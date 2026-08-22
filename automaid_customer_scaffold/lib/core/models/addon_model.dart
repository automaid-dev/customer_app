/// Mirrors app/Models/AddOn.php.
class AddOn {
  final int id;
  final String title;
  final double price;
  final String? description;

  AddOn({required this.id, required this.title, required this.price, this.description});

  factory AddOn.fromJson(Map<String, dynamic> json) => AddOn(
        id: json['id'] as int,
        // Backend's add_ons table column is `title`, not `name` — this
        // previously read the wrong JSON key, so every add-on's display
        // name silently came through as an empty string everywhere this
        // model was used (the add-on selection checklist included).
        title: json['title']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
        description: json['description']?.toString(),
      );
}
