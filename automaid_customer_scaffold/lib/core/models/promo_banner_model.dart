/// Mirrors app/Models/Banner.php.
///
/// Named PromoBanner rather than Banner — Flutter's own material
/// library already exports a widget called `Banner` (the diagonal
/// debug ribbon), so naming this class `Banner` would silently shadow
/// or collide with that wherever both are imported in the same file.
class PromoBanner {
  final int id;
  final String? title;
  final String imageUrl;
  final String? link;

  PromoBanner({required this.id, this.title, required this.imageUrl, this.link});

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    final rawLink = json['link']?.toString().trim();
    return PromoBanner(
      id: json['id'] as int,
      title: json['title']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      link: (rawLink == null || rawLink.isEmpty) ? null : rawLink,
    );
  }
}
