import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/merchant_providers.dart';
import 'merchant_profile_edit_screen.dart';

/// Wraps POST /merchant/profile (Api/Merchant/ProfileController::profile), which
/// eager-loads wallet.transactions and activities. Tap the edit icon to
/// update profile fields (name, IC, address, equipment, company, bank
/// info + avatar) via MerchantProfileEditScreen.
class MerchantProfileScreen extends ConsumerStatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  ConsumerState<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends ConsumerState<MerchantProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ref.read(merchantRepositoryProvider).profile();
      setState(() {
        _user = user;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _user?['wallet'] as Map<String, dynamic>?;
    final activities = (_user?['activities'] as List<dynamic>? ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MerchantProfileEditScreen(initialUser: _user!)),
                );
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_user?['name']?.toString() ?? '-',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(_user?['email']?.toString() ?? '-'),
                    Text(_user?['mobile_no']?.toString() ?? '-'),
                    const Divider(height: 32),
                    Text('Wallet balance', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'RM${wallet?['balance']?.toString() ?? '0.00'}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32),
                    Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (activities.isEmpty)
                      const Text('No activity yet.')
                    else
                      ...activities.map((a) {
                        final activity = a as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(activity['title']?.toString() ?? '-'),
                            subtitle: Text('Order #${activity['order_id'] ?? '-'}'),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
