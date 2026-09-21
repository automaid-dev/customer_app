import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_providers.dart';
import 'new_support_ticket_screen.dart';
import 'support_ticket_detail_screen.dart';

/// Entry point for customer complaints/help requests — shows past
/// tickets and lets the person file a new one against a specific order.
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  Color _statusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New complaint'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NewSupportTicketScreen()),
          );
          if (created == true) ref.invalidate(supportTicketsProvider);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supportTicketsProvider),
        child: ticketsAsync.when(
          data: (tickets) {
            if (tickets.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "You haven't filed any complaints yet.\nTap \"New complaint\" if you need help with an order.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: tickets.length,
              itemBuilder: (context, i) {
                final ticket = tickets[i];
                final order = ticket['order'] as Map<String, dynamic>?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(ticket['issue_type']?.toString() ?? 'Complaint'),
                    subtitle: Text(
                      order != null ? 'Order #${order['id']}' : 'General inquiry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Chip(
                      label: Text(
                        (ticket['status']?.toString() ?? '-').toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      backgroundColor: _statusColor(ticket['status']?.toString()),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupportTicketDetailScreen(ticketId: ticket['id'] as int),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load tickets: $e')),
        ),
      ),
    );
  }
}
