import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';
import 'subscription_receipt_screen.dart';

/// Lists every subscription-related order (initial subscribe, renewals,
/// card updates, upgrades) — wraps POST /customer/subscription/history.
/// Tapping an entry opens its receipt.
class SubscriptionHistoryScreen extends ConsumerStatefulWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  ConsumerState<SubscriptionHistoryScreen> createState() => _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends ConsumerState<SubscriptionHistoryScreen> {
  List<Map<String, dynamic>>? _orders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await ref.read(customerRepositoryProvider).subscriptionHistory();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'subscription':
        return 'New subscription';
      case 'subscription_renewal':
        return 'Renewal';
      case 'subscription_update':
        return 'Card update';
      case 'subscription_upgrade':
        return 'Upgrade';
      default:
        return type ?? 'Subscription';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription history')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_orders?.isEmpty ?? true)
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('No subscription history yet.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders!.length,
                          itemBuilder: (context, i) {
                            final order = _orders![i];
                            final createdAt = order['created_at']?.toString().split('T').first;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long_outlined),
                                title: Text(_typeLabel(order['order_type']?.toString())),
                                subtitle: Text(
                                  '${createdAt ?? '-'} · ${order['status'] ?? '-'}',
                                ),
                                trailing: Text(
                                  'RM${order['grand_total']?.toString() ?? '0.00'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SubscriptionReceiptScreen(orderId: order['id'] as int),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
