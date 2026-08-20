import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../../../core/widgets/dashboard_banner.dart';
import '../providers/customer_providers.dart';
import '../booking/booking_flow_screen.dart';
import '../bag/bag_screen.dart';
import '../orders/order_list_screen.dart';
import '../subscription/subscription_screen.dart';
import '../subscription/subscription_history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/customer_profile_screen.dart';

/// Bottom-nav shell for the whole customer app — Home / Bag / Booking /
/// Transaction history / Profile, each its own self-contained tab (kept
/// alive via IndexedStack so switching tabs doesn't lose scroll position
/// or re-fetch data every time).
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _HomeTab(),
    BagScreen(),
    OrderListScreen(),
    SubscriptionHistoryScreen(),
    CustomerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Bag'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Booking'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final bookingsAsync = ref.watch(homeBookingsProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = notificationsAsync.valueOrNull?.unreadCount ?? 0;

    return Scaffold(
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
          padding: EdgeInsets.zero,
          children: [
            DashboardBanner(
              name: user?.name ?? '',
              mascotAsset: 'assets/images/mascot_customer.png',
              unreadCount: unreadCount,
              onNotificationTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                ref.invalidate(notificationsProvider);
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const _SubscriptionSection(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Active bookings', style: Theme.of(context).textTheme.titleMedium),
                  ),
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_laundry_service),
        title: Text('Order #${booking.orderId} — ${booking.pickupBagQuantity} bag(s)'),
        subtitle: Text(
          booking.pickupDate != null
              ? 'RM${booking.grandTotal.toStringAsFixed(2)} · Pickup: ${booking.pickupDate!.toLocal().toString().split(' ').first} '
                  '${booking.pickupStartTime ?? ''}'
              : 'RM${booking.grandTotal.toStringAsFixed(2)} · Status: ${booking.status}',
        ),
        trailing: Chip(label: Text(booking.status)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderListScreen(highlightOrderId: booking.orderId)),
        ),
      ),
    );
  }
}
