import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../address/address_list_screen.dart';
import '../providers/customer_providers.dart';

/// Subscription always routes through the payment gateway on this backend
/// (SubscriptionController::placeOrder always returns a payment `url`,
/// never an instant confirmation) — so subscribing here opens a payment
/// link rather than confirming inline.
///
/// Plan prices/quotas are fetched live from POST /subscription/plans —
/// never hardcoded — so this screen always reflects whatever the admin
/// has set in Settings > Subscription Fees/Discounts.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _selectedPlanCode;
  int? _selectedAddressId;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _subscribe() async {
    final user = ref.read(authControllerProvider).user;
    final addresses = ref.read(addressListProvider).valueOrNull ?? [];
    final plans = ref.read(subscriptionPlansProvider).valueOrNull ?? [];

    if (_selectedPlanCode == null) {
      setState(() => _error = 'Please choose a plan.');
      return;
    }
    if (_selectedAddressId == null) {
      setState(() => _error = 'Please select an address.');
      return;
    }

    final address = addresses.firstWhere((a) => a.id == _selectedAddressId);
    final plan = plans.firstWhere((p) => p.code == _selectedPlanCode);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).subscribe(
            planCode: plan.code,
            billingName: user?.name ?? '',
            billingEmail: user?.email ?? '',
            billingPhone: user?.mobileNo ?? '',
            address: address,
            subTotal: plan.price,
          );
      if (mounted) _showPaymentDialog(result['url']?.toString());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(customerRepositoryProvider).cancelSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Subscription cancelled.')));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPaymentDialog(String? url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment required'),
        content: Text('Open this link to complete payment:\n${url ?? '-'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressListProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Every plan includes 1 free bag (wash + delivery) per order. '
            'Extra bags in the same order are charged the normal per-bag '
            'and delivery rate.',
          ),
          const SizedBox(height: 16),
          plansAsync.when(
            data: (plans) => Column(
              children: plans
                  .map((p) => _PlanCard(
                        plan: p,
                        isSelected: _selectedPlanCode == p.code,
                        onTap: () => setState(() => _selectedPlanCode = p.code),
                      ))
                  .toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load plans: $e'),
          ),
          const SizedBox(height: 16),
          addressesAsync.when(
            data: (addresses) => addresses.isEmpty
                ? TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AddressListScreen())),
                    child: const Text('Add a billing/delivery address first'),
                  )
                : DropdownButtonFormField<int>(
                    value: _selectedAddressId,
                    decoration: const InputDecoration(labelText: 'Billing / delivery address'),
                    items: addresses
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.displayLabel)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAddressId = v),
                  ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Could not load addresses: $e'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _subscribe,
            child: _isSubmitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Subscribe'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isSubmitting ? null : _cancel,
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isSelected, required this.onTap});
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: plan.code,
                groupValue: isSelected ? plan.code : null,
                onChanged: (_) => onTap(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(plan.quotaLabel),
                  ],
                ),
              ),
              Text(
                'RM${plan.price.toStringAsFixed(2)}/mo',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
