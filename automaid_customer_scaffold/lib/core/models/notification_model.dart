/// Mirrors one row from the backend's `notifications` table (see
/// POST /customer/notifications). Named `AppNotification` rather than
/// `Notification` to avoid clashing with Flutter's own
/// dart:ui/material Notification widget class.
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? orderId;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        orderId: json['order_id'] as int?,
        readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
