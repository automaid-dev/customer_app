import 'package:flutter/material.dart';

/// Shared display helpers for the order detail + booking receipt screens.

/// Wash type for a booking: prefers the backend's `service_type`
/// ("Wash & Fold" / "Dry Cleaning"), falling back to the same
/// convention the backend uses (service_category_id or dry-clean items
/// present == dry cleaning) if the field isn't there.
String? orderServiceType(Map<String, dynamic> order) {
  if (order['order_type']?.toString() != 'booking') return null;
  final fromApi = order['service_type']?.toString();
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;

  final booking = order['booking'] as Map<String, dynamic>?;
  final Object? items = booking?['items'];
  final bool hasItems = items is List ? items.isNotEmpty : (items != null && items.toString().isNotEmpty);
  return (booking?['service_category_id'] != null || hasItems) ? 'Dry Cleaning' : 'Wash & Fold';
}

/// "Booking - Wash & Fold", "Booking - Dry Cleaning", "Purchase Bag", ...
String orderTypeLabel(Map<String, dynamic> order) {
  final raw = order['order_type']?.toString();
  if (raw == null || raw.isEmpty) return '-';
  final base = raw
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  final service = orderServiceType(order);
  return service != null ? '$base - $service' : base;
}

String? customerAddressOf(Map<String, dynamic> order) {
  final v = order['customer_address']?.toString();
  return (v == null || v.isEmpty) ? null : v;
}

String? merchantAddressOf(Map<String, dynamic> order) {
  final v = order['merchant_address']?.toString();
  return (v == null || v.isEmpty) ? null : v;
}

/// Label on top, address wrapped underneath — used for the customer /
/// merchant addresses shown after Grand total.
class OrderAddressBlock extends StatelessWidget {
  const OrderAddressBlock({
    super.key,
    required this.icon,
    required this.label,
    this.name,
    this.address,
    this.emptyText = '-',
  });

  final IconData icon;
  final String label;
  final String? name;
  final String? address;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                if (name != null && name!.isNotEmpty)
                  Text(name!, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  address ?? emptyText,
                  style: TextStyle(color: address == null ? Colors.grey : null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
