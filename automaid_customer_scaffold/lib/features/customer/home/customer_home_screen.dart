import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/customer_providers.dart';
import '../booking/booking_flow_screen.dart';
import '../address/address_list_screen.dart';
import '../bag/bag_screen.dart';
import '../orders/order_list_screen.dart';
import '../subscription/subscription_screen.dart';
import '../notifications/notifications_screen.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final bookingsAsync = ref.watch(homeBookingsProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = notificationsAsync.valueOrNull?.unreadCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.name ?? ''}'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              ref.invalidate(notificationsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
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
            const SizedBox(height: 16),
            const _SubscriptionSection(),
            const SizedBox(height: 8),
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

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return subscriptionAsync.when(
      data: (subscription) {
        final isActive = subscription != null && subscription['status'] == 'active';
        if (!isActive) return const _SubscribeBanner();
        return _ActiveSubscriptionCard(subscription: subscription);
      },
      // Don't show anything while loading or on error — this is a
      // secondary/contextual section, not worth a spinner or error text
      // crowding the top of the dashboard.
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _ActiveSubscriptionCard extends ConsumerWidget {
  const _ActiveSubscriptionCard({required this.subscription});
  final Map<String, dynamic> subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final planCode = subscription['plan_code']?.toString();
    final used = subscription['orders_used_current_cycle'] ?? 0;
    final renewAt = subscription['renew_at']?.toString();

    return plansAsync.when(
      data: (plans) {
        SubscriptionPlan? plan;
        for (final p in plans) {
          if (p.code.trim().toLowerCase() == planCode?.trim().toLowerCase()) plan = p;
        }
        final planName = plan?.name ?? (planCode ?? 'Subscription');
        // Bug fix (still applies): `plan?.orderQuota == null` was true
        // both when the plan is genuinely unlimited (Platinum) AND when
        // `plan` itself wasn't found at all — the latter incorrectly
        // showed "Unlimited orders" for every non-Platinum plan whenever
        // the lookup failed, instead of showing something that flags
        // the mismatch.
        final String freeBagText;
        final String usedText;
        bool quotaExhausted = false;
        if (plan == null) {
          freeBagText = 'Free bag entitled: unavailable';
          usedText = 'Bags utilised: unavailable';
        } else if (plan.orderQuota == null) {
          freeBagText = 'Free bag entitled: unlimited free 1st bag, every order';
          usedText = 'Bags utilised: $used';
        } else {
          freeBagText =
              'Free bag entitled: ${plan.orderQuota} times free for 1st bag each order';
          usedText = 'Bags utilised: $used/${plan.orderQuota}';
          quotaExhausted = used >= plan.orderQuota!;
        }

        return Card(
          color: quotaExhausted
              ? Colors.orange.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(quotaExhausted ? Icons.info_outline : Icons.card_membership, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscription Plan : $planName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(freeBagText),
                      Text(usedText),
                      if (quotaExhausted)
                        const Text(
                          "You've used all your free bags this cycle — your "
                          "next order's 1st bag will be charged at the normal rate.",
                          style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                        ),
                      if (renewAt != null) Text('Renews: ${renewAt.split('T').first}'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _SubscribeBanner extends StatelessWidget {
  const _SubscribeBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.local_laundry_service, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LB Unlimited Wash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Subscribe to save more.'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
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
        Expanded(
          child: _ActionTile(
            icon: Icons.location_on_rounded,
            label: 'Addresses',
            color: AppColors.blue,
            onTap: onAddresses,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.shopping_bag_rounded,
            label: 'Bags',
            color: AppColors.yellow,
            onTap: onBags,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            color: AppColors.red,
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.card_membership_rounded,
            label: 'Plan',
            color: AppColors.blueDark,
            onTap: onSubscription,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
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

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text("You'll need to log in again to access your account."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref.read(authControllerProvider.notifier).logout();
  }
}
