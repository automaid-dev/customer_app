import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_providers.dart';
import 'order_detail_screen.dart';

/// Shows every order for the customer, any status — including cancelled
/// ones, which previously never appeared anywhere in the app at all
/// (this screen used to reuse the home dashboard's "active bookings"
/// data as a workaround for a backend endpoint that didn't work yet).
class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key, this.highlightOrderId});
  final int? highlightOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: ordersAsync.when(
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('No orders yet.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(orderHistoryProvider),
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    final orderId = order['id'] as int?;
                    final rawStatus = order['status']?.toString() ?? '-';
                    final booking = order['booking'] as Map<String, dynamic>?;
                    final isCancelled = rawStatus.toLowerCase() == 'cancelled' || rawStatus.toLowerCase() == 'cancel';
                    // The full flow (pickup -> wash -> delivery) is
                    // done once the `delivered` record exists —
                    // reflect that here rather than the raw payment
                    // status, which stays "paid" forever regardless of
                    // how far the order actually progressed.
                    final isCompleted = order['delivered'] != null;
                    final displayStatus = isCompleted ? 'Completed' : rawStatus;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: orderId == highlightOrderId
                          ? Theme.of(context).colorScheme.primaryContainer
                          : (isCancelled ? Colors.red.withValues(alpha: 0.06) : null),
                      child: ListTile(
                        leading: isCancelled
                            ? const Icon(Icons.cancel_outlined, color: Colors.red)
                            : (isCompleted ? const Icon(Icons.check_circle_outline, color: Colors.green) : null),
                        title: Text('Order #${orderId ?? '-'}'),
                        subtitle: Text(
                          '${booking?['pickup_bag_quantity'] ?? order['quantity'] ?? '-'} bag(s) · '
                          'RM${order['grand_total'] ?? '0.00'} · $displayStatus',
                          style: isCancelled
                              ? const TextStyle(color: Colors.red)
                              : (isCompleted ? const TextStyle(color: Colors.green) : null),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: orderId == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
                                ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load orders: $e')),
      ),
    );
  }
}
