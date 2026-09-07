/// Mirrors app/Models/ServiceCategory.php.
class ServiceCategory {
  final int id;
  final String name;
  final List<ServiceItem> items;

  ServiceCategory({required this.id, required this.name, required this.items});

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => ServiceItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

/// Mirrors app/Models/ServiceItem.php.
///
/// Overrides == /hashCode by id — this is used as a Map key in the
/// dry-clean cart (DryCleanDraft.cart), and without value equality,
/// re-fetching the catalog (a new ServiceItem instance for "the same"
/// item) would silently break cart lookups after any rebuild.
class ServiceItem {
  final int id;
  final String name;
  final double pricePerPiece;
  final String? imageUrl;

  ServiceItem({
    required this.id,
    required this.name,
    required this.pricePerPiece,
    this.imageUrl,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        pricePerPiece: double.tryParse(json['price_per_piece']?.toString() ?? '') ?? 0,
        imageUrl: json['image_url']?.toString(),
      );

  @override
  bool operator ==(Object other) => other is ServiceItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
