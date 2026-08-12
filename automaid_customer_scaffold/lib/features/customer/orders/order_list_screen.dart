import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_providers.dart';
import 'order_detail_screen.dart';

/// The backend's dedicated /customer/order/active and /customer/order/upcoming
/// endpoints don't currently return data (see CustomerRepository.orderActive
/// doc comment — it's a gap in OrderController on the backend). Until that's
/// fixed, this screen reuses the home dashboard's booking list, which does
/// return real data and includes the order_id needed to open order detail.
class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key, this.highlightOrderId});
  final int? highlightOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(homeBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: bookingsAsync.when(
        data: (bookings) => bookings.isEmpty
            ? const Center(child: Text('No orders yet.'))
            : ListView.builder(
                itemCount: bookings.length,
                itemBuilder: (context, i) {
                  final b = bookings[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: b.orderId == highlightOrderId
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text('Order #${b.orderId}'),
                      subtitle: Text(
                        '${b.pickupBagQuantity} bag(s) · RM${b.grandTotal.toStringAsFixed(2)} · ${b.status}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: b.orderId)),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load orders: $e')),
      ),
    );
  }
}
