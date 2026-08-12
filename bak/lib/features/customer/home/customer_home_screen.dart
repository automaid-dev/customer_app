import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/booking_model.dart';
import '../providers/customer_providers.dart';
import '../booking/booking_flow_screen.dart';
import '../address/address_list_screen.dart';
import '../bag/bag_screen.dart';
import '../orders/order_list_screen.dart';
import '../subscription/subscription_screen.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final bookingsAsync = ref.watch(homeBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New booking'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BookingFlowScreen()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(homeBookingsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _QuickActions(
              onAddresses: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AddressListScreen())),
              onBags: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BagScreen())),
              onOrders: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const OrderListScreen())),
              onSubscription: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
            ),
            const SizedBox(height: 24),
            Text('Active bookings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            bookingsAsync.when(
              data: (bookings) => bookings.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No active bookings right now.')),
                    )
                  : Column(children: bookings.map((b) => _BookingCard(booking: b)).toList()),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Could not load bookings: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddresses,
    required this.onBags,
    required this.onOrders,
    required this.onSubscription,
  });

  final VoidCallback onAddresses;
  final VoidCallback onBags;
  final VoidCallback onOrders;
  final VoidCallback onSubscription;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionTile(icon: Icons.location_on, label: 'Addresses', onTap: onAddresses)),
        const SizedBox(width: 8),
        Expanded(child: _ActionTile(icon: Icons.qr_code, label: 'Bags', onTap: onBags)),
        const SizedBox(width: 8),
        Expanded(child: _ActionTile(icon: Icons.receipt_long, label: 'Orders', onTap: onOrders)),
        const SizedBox(width: 8),
        Expanded(child: _ActionTile(icon: Icons.card_membership, label: 'Plan', onTap: onSubscription)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_laundry_service),
        title: Text('${booking.pickupBagQuantity} bag(s) — RM${booking.grandTotal.toStringAsFixed(2)}'),
        subtitle: Text(
          booking.pickupDate != null
              ? 'Pickup: ${booking.pickupDate!.toLocal().toString().split(' ').first} '
                  '${booking.pickupStartTime ?? ''}'
              : 'Status: ${booking.status}',
        ),
        trailing: Chip(label: Text(booking.status)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderListScreen(highlightOrderId: booking.orderId)),
        ),
      ),
    );
  }
}
