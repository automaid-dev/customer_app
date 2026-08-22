import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/merchant_providers.dart';
import '../jobs/merchant_order_detail_screen.dart';

/// Every order this merchant has accepted, at any stage — see the
/// matching comment on RiderActivityHistoryScreen for why this is a
/// card-per-order list rather than the flat event log it used to be.
class MerchantActivityHistoryScreen extends ConsumerWidget {
  const MerchantActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(merchantActivityHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order history')),
      body: ordersAsync.when(
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('No orders yet.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(merchantActivityHistoryProvider),
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    final orderId = order['id'] as int?;
                    final status = order['status']?.toString() ?? '-';
                    final booking = order['booking'] as Map<String, dynamic>?;
                    final isCancelled = status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'cancel';
                    final isCompleted = order['delivered'] != null;
                    final displayStatus = isCompleted ? 'Completed' : status;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isCancelled ? Colors.red.withValues(alpha: 0.06) : null,
                      child: ListTile(
                        leading: isCancelled
                            ? const Icon(Icons.cancel_outlined, color: Colors.red)
                            : (isCompleted ? const Icon(Icons.check_circle_outline, color: Colors.green) : null),
                        title: Text('Order #${orderId ?? '-'}'),
                        subtitle: Text(
                          '${booking?['pickup_bag_quantity'] ?? '-'} bag(s) · '
                          'RM${order['grand_total'] ?? '0.00'} · $displayStatus',
                          style: isCancelled
                              ? const TextStyle(color: Colors.red)
                              : (isCompleted ? const TextStyle(color: Colors.green) : null),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: orderId == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MerchantOrderDetailScreen(id: orderId, isComplete: true),
                                  ),
                                ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load order history: $e')),
      ),
    );
  }
}
