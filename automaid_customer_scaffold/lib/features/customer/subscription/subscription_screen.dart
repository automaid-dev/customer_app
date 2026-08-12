import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../payment/payment_flow.dart';
import '../providers/customer_providers.dart';
import 'subscription_history_screen.dart';

/// Subscription always routes through the payment gateway on this backend
/// — so both subscribing and upgrading open a payment link rather than
/// confirming inline.
///
/// Two modes, based on whether the customer already has an active plan:
/// - **No active subscription**: pick any plan, subscribe normally.
/// - **Active subscription**: current plan is shown with usage this
///   cycle; other plans show as "Upgrade" (only for strictly higher-priced
///   tiers — downgrades aren't supported) with the topup amount the
///   backend will actually charge (the price difference, not the full
///   new-plan price — that applies automatically from the next renewal).
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

      if (!mounted) return;

      final orderId = result['order_id'] as int?;
      final url = result['url']?.toString();
      final paid = (url == null || orderId == null)
          ? false
          : await runPaymentFlow(context: context, ref: ref, paymentUrl: url, orderId: orderId);

      if (!mounted) return;

      if (paid) {
        ref.invalidate(currentSubscriptionProvider);
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Subscribed!'),
            content: Text('You\'re now on the ${plan.name} plan.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment wasn't confirmed yet — check back shortly."),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmAndUpgrade(SubscriptionPlan targetPlan, double topup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to ${targetPlan.name}?'),
        content: Text(
          "You'll pay RM${topup.toStringAsFixed(2)} now (the difference from your current "
          'plan). Your next renewal will bill the full ${targetPlan.name} price going forward.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upgrade')),
        ],
      ),
    );
    if (confirmed == true) await _upgrade(targetPlan);
  }

  Future<void> _upgrade(SubscriptionPlan targetPlan) async {
    final user = ref.read(authControllerProvider).user;
    final addresses = ref.read(addressListProvider).valueOrNull ?? [];
    if (_selectedAddressId == null) {
      setState(() => _error = 'Please select a billing address.');
      return;
    }
    final address = addresses.firstWhere((a) => a.id == _selectedAddressId);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).upgradeSubscription(
            planCode: targetPlan.code,
            billingName: user?.name ?? '',
            billingEmail: user?.email ?? '',
            billingPhone: user?.mobileNo ?? '',
            address: address,
          );

      if (!mounted) return;

      final orderId = result['order_id'] as int?;
      final url = result['url']?.toString();
      final paid = (url == null || orderId == null)
          ? false
          : await runPaymentFlow(context: context, ref: ref, paymentUrl: url, orderId: orderId);

      if (!mounted) return;

      if (paid) {
        ref.invalidate(currentSubscriptionProvider);
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Upgraded!'),
            content: Text("You're now on the ${targetPlan.name} plan."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment wasn't confirmed yet — check back shortly."),
          ),
        );
      }
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
      ref.invalidate(currentSubscriptionProvider);
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

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressListProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final currentSubAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Subscription history',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SubscriptionHistoryScreen())),
          ),
        ],
      ),
      body: currentSubAsync.when(
        data: (currentSub) {
          final isActive = currentSub != null && currentSub['status'] == 'active';
          final currentPlanCode = currentSub?['plan_code']?.toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Every plan includes 1 free bag wash per order (delivery is '
                'charged separately at the standard rate). Extra bags in the '
                'same order are charged the normal per-bag wash and delivery rate.',
              ),
              const SizedBox(height: 16),
              plansAsync.when(
                data: (plans) {
                  SubscriptionPlan? currentPlan;
                  for (final p in plans) {
                    if (p.code.trim().toLowerCase() == currentPlanCode?.trim().toLowerCase()) currentPlan = p;
                  }

                  if (isActive && currentPlan != null) {
                    final used = currentSub['orders_used_current_cycle'] ?? 0;
                    final quotaText = currentPlan.orderQuota == null
                        ? 'Unlimited orders'
                        : '$used/${currentPlan.orderQuota} orders used this cycle';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current plan: ${currentPlan.name}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(quotaText),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              plansAsync.when(
                data: (plans) {
                  SubscriptionPlan? currentPlan;
                  for (final p in plans) {
                    if (p.code.trim().toLowerCase() == currentPlanCode?.trim().toLowerCase()) currentPlan = p;
                  }
                  return Column(
                    children: plans.map((p) {
                      if (isActive && currentPlan != null) {
                        final isCurrent = p.code.trim().toLowerCase() == currentPlanCode?.trim().toLowerCase();
                        final isHigher = p.price > currentPlan!.price;
                        return _PlanCard(
                          plan: p,
                          isSelected: false,
                          isCurrent: isCurrent,
                          topup: isHigher ? (p.price - currentPlan.price) : null,
                          onTap: isHigher
                              ? () => _confirmAndUpgrade(p, p.price - currentPlan!.price)
                              : null,
                        );
                      }
                      return _PlanCard(
                        plan: p,
                        isSelected: _selectedPlanCode == p.code,
                        onTap: () => setState(() => _selectedPlanCode = p.code),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load plans: $e'),
              ),
              const SizedBox(height: 16),
              addressesAsync.when(
                data: (addresses) {
                  if (_selectedAddressId == null && addresses.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedAddressId == null) {
                        setState(() => _selectedAddressId = addresses.first.id);
                      }
                    });
                  }
                  if (addresses.isEmpty) {
                    return TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const AddressListScreen())),
                      child: const Text('Add a billing/delivery address first'),
                    );
                  }

                  Address? selected;
                  for (final a in addresses) {
                    if (a.id == _selectedAddressId) selected = a;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedAddressId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Billing / delivery address'),
                        items: addresses
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.displayLabel} — ${a.fullAddressText}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedAddressId = v),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        AddressPreviewCard(address: selected),
                      ],
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Could not load addresses: $e'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              if (!isActive)
                FilledButton(
                  onPressed: _isSubmitting ? null : _subscribe,
                  child: _isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Subscribe'),
                ),
              if (isActive) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _cancel,
                  child: const Text('Cancel subscription'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load subscription: $e')),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.isCurrent = false,
    this.topup,
  });
  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isCurrent;
  final double? topup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null && !isCurrent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected || isCurrent ? scheme.primaryContainer : null,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (topup == null && !isCurrent)
                  Radio<String>(
                    value: plan.code,
                    groupValue: isSelected ? plan.code : null,
                    onChanged: onTap == null ? null : (_) => onTap!(),
                  ),
                if (isCurrent) const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check_circle, color: Colors.green),
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
                if (isCurrent)
                  const Text('Current plan', style: TextStyle(fontWeight: FontWeight.bold))
                else if (topup != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('RM${plan.price.toStringAsFixed(2)}/mo',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Upgrade: +RM${topup!.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                else
                  Text(
                    'RM${plan.price.toStringAsFixed(2)}/mo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
