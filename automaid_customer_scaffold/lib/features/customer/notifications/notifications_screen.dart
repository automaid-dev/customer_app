import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'account_created':
        return Icons.person_outline;
      case 'bag_purchased':
        return Icons.shopping_bag_outlined;
      case 'subscription_created':
        return Icons.card_membership;
      case 'subscription_cancelled':
        return Icons.cancel_outlined;
      case 'new_booking':
        return Icons.local_laundry_service_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notificationsAsync.maybeWhen(
            data: (result) => result.unreadCount > 0
                ? TextButton(
                    onPressed: () async {
                      await ref.read(customerRepositoryProvider).markNotificationsRead();
                      ref.invalidate(notificationsProvider);
                    },
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (result) {
          if (result.notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              itemCount: result.notifications.length,
              itemBuilder: (context, i) {
                final n = result.notifications[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.isRead
                        ? Colors.grey.shade200
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_iconFor(n.type), size: 20),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(n.body),
                  trailing: Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 12)),
                  onTap: n.isRead
                      ? null
                      : () async {
                          await ref.read(customerRepositoryProvider).markNotificationsRead(id: n.id);
                          ref.invalidate(notificationsProvider);
                        },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notifications: $e')),
      ),
    );
  }
}
