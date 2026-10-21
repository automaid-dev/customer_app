import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../payment/payment_flow.dart';
import '../providers/customer_providers.dart';
import 'subscription_history_screen.dart';
import '../../../core/utils/service_charge.dart';

/// Subscription always routes through the payment gateway on this backend
/// — so both subscribing and upgrading open a payment link rather than
/// confirming inline.
///
/// Two modes, based on whether the customer already has an active plan:
/// - **No active subscription**: pick any plan, subscribe normally.
/// - **Active subscription**: current plan is shown with usage this
///   cycle. Higher-priced plans show "Upgrade" with the price difference
///   charged now (saved card for GKash / Revenue Monster, checkout for
///   Fiuu); the full new price applies from the next renewal.
///   Lower-priced plans show "Switch at renewal": nothing is charged and
///   the lower plan + price start on the next renewal date. A scheduled
///   switch shows a banner with a "Keep current plan" button.
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

  bool get _usesSavedCard {
    final gw = ref.read(currentSubscriptionProvider).valueOrNull?['payment_gateway']?.toString().toLowerCase();
    return gw == 'gkash' || gw == 'revenuemonster';
  }

  Future<void> _confirmAndUpgrade(SubscriptionPlan targetPlan, double topup) async {
    final pct = ref.read(appSettingProvider).valueOrNull?.serviceChargeSubscription ?? 0;
    final charge = serviceChargeFor(topup, pct);
    final savedCard = _usesSavedCard;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to ${targetPlan.name}?'),
        content: Text(
          "${savedCard ? 'Your saved card will be charged' : "You'll pay"} RM${(topup + charge).toStringAsFixed(2)} now (the difference from your current "
          'plan${charge > 0 ? ' of RM${topup.toStringAsFixed(2)}, plus RM${charge.toStringAsFixed(2)} ${kServiceChargeLabel.toLowerCase()}' : ''}). '
          'Your new plan starts straight away, and your next renewal will bill the full ${targetPlan.name} price.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(savedCard ? 'Pay & upgrade' : 'Upgrade'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _upgrade(targetPlan);
  }

  String _formatDate(String? ymd) {
    final d = ymd == null ? null : DateTime.tryParse(ymd);
    if (d == null) return 'your next renewal';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _confirmAndDowngrade(SubscriptionPlan targetPlan, SubscriptionPlan currentPlan) async {
    final renew = _formatDate(ref.read(currentSubscriptionProvider).valueOrNull?['end_date']?.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${targetPlan.name}?'),
        content: Text(
          "Nothing is charged now. You keep ${currentPlan.name} until $renew, then your plan changes to "
          '${targetPlan.name} and renews at RM${targetPlan.price.toStringAsFixed(2)}/month. '
          'You can change your mind any time before then.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Switch at renewal')),
        ],
      ),
    );
    if (confirmed == true) await _upgrade(targetPlan);
  }

  Future<void> _keepCurrentPlan() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(customerRepositoryProvider).cancelScheduledPlanChange();
      ref.invalidate(currentSubscriptionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('You will stay on your current plan.')));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

      // Downgrade: scheduled for next renewal, nothing to pay.
      if (result['scheduled'] == true) {
        ref.invalidate(currentSubscriptionProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Your plan will change to ${targetPlan.name} on '
              '${_formatDate(result['effective_date']?.toString())}.'),
        ));
        return;
      }

      final orderId = result['order_id'] as int?;
      final url = result['url']?.toString();
      final paid = (url == null || orderId == null)
          ? false
          : await runPaymentFlow(context: context, ref: ref, paymentUrl: url, orderId: orderId);

      if (!mounted) return;
      ref.invalidate(currentSubscriptionProvider);

      if (paid) {
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

  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          "You'll lose your subscriber benefits (free bags, dry-cleaning discount) "
          "once this takes effect. This can't be undone from here — you'd need to "
          'subscribe again to get them back.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep subscription')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancel();
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
              Text('Subscription plans',
                  style: GoogleFonts.fraunces(
                      fontSize: 28, fontWeight: FontWeight.w600, color: const Color(0xFF0E2240))),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final plans = plansAsync.valueOrNull ?? <SubscriptionPlan>[];
                final bags = plans.isEmpty ? 1 : plans.first.freeBagWashPerOrder;
                final anyDryClean = plans.any((p) => p.drycleanDiscountPercent > 0);
                return Text(
                  'Every plan includes $bags free bag wash${bags == 1 ? '' : 'es'} per order'
                  '${anyDryClean ? ', plus a discount on dry cleaning' : ''}. '
                  'Delivery is charged separately at the standard rate, and extra bags in the '
                  'same order are charged the normal per-bag rate.',
                  style: const TextStyle(color: Color(0xFF3D4A5C), height: 1.4),
                );
              }),
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
                              Builder(builder: (context) {
                                final scheduled = currentSub?['scheduled_plan_code']?.toString();
                                if (scheduled == null || scheduled.isEmpty) return const SizedBox.shrink();
                                var name = scheduled;
                                for (final p in plans) {
                                  if (p.code.trim().toLowerCase() == scheduled.trim().toLowerCase()) name = p.name;
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.schedule, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Changing to $name on ${_formatDate(currentSub?['end_date']?.toString())}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ]),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _isSubmitting ? null : _keepCurrentPlan,
                                            child: const Text('Keep current plan'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
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
                        final isLower = !isCurrent && p.price < currentPlan.price;
                        final scheduled = currentSub?['scheduled_plan_code']?.toString().trim().toLowerCase();
                        final isScheduled = isLower && scheduled == p.code.trim().toLowerCase();
                        return _PlanCard(
                          plan: p,
                          isSelected: false,
                          isCurrent: isCurrent,
                          topup: isHigher ? (p.price - currentPlan.price) : null,
                          downgradeLabel: isScheduled
                              ? 'Starts next renewal'
                              : (isLower ? 'Switch at renewal' : null),
                          onTap: _isSubmitting
                              ? null
                              : isHigher
                                  ? () => _confirmAndUpgrade(p, p.price - currentPlan!.price)
                                  : (isLower && !isScheduled)
                                      ? () => _confirmAndDowngrade(p, currentPlan!)
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
              // Payment gateway service charge (admin %, 0 = none).
              Builder(builder: (context) {
                final pct = ref.watch(appSettingProvider).valueOrNull?.serviceChargeSubscription ?? 0;
                if (pct <= 0) return const SizedBox.shrink();
                SubscriptionPlan? selected;
                for (final p in plansAsync.valueOrNull ?? <SubscriptionPlan>[]) {
                  if (p.code == _selectedPlanCode) selected = p;
                }
                final text = (!isActive && selected != null)
                    ? 'Plan RM${selected.price.toStringAsFixed(2)} + ${serviceChargeLabel(pct)} '
                        'RM${serviceChargeFor(selected.price, pct).toStringAsFixed(2)} = '
                        'RM${(selected.price + serviceChargeFor(selected.price, pct)).toStringAsFixed(2)} today. '
                        'Each monthly renewal includes the same ${percentText(pct)}% charge.'
                    : 'A ${percentText(pct)}% payment gateway service charge is added to each subscription payment and monthly renewal.';
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                );
              }),
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
                  onPressed: _isSubmitting ? null : _confirmAndCancel,
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

/// Plan card styled after the lbunlimitedwash.com pricing section:
/// serif tier label + price, divider, orders line, ticked benefits, and a
/// full-width pill button. Platinum is the highlighted navy card with a
/// yellow button. Price, orders, free bags per order and the dry-cleaning
/// discount all come from admin Settings via POST /subscription/plans.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.isCurrent = false,
    this.topup,
    this.downgradeLabel,
  });
  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isCurrent;
  final double? topup;
  final String? downgradeLabel;
  final VoidCallback? onTap;

  static const _navy = Color(0xFF0A3A80);
  static const _ink = Color(0xFF0E2240);
  static const _gold = Color(0xFFF2C14E);

  String _money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final dark = plan.isPlatinum;
    final fg = dark ? Colors.white : _ink;
    final soft = dark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF3D4A5C);
    final tick = dark ? _gold : _navy;
    final serif = GoogleFonts.fraunces();

    final bags = plan.freeBagWashPerOrder;
    final benefits = <InlineSpan>[
      TextSpan(text: '$bags free bag wash${bags == 1 ? '' : 'es'} per order'),
      if (plan.audience.isNotEmpty) TextSpan(text: plan.audience),
      const TextSpan(text: 'Delivery charged separately at the standard rate'),
      if (plan.drycleanDiscountPercent > 0)
        TextSpan(children: [
          TextSpan(
              text: '${_pct(plan.drycleanDiscountPercent)}% off',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const TextSpan(text: '  dry cleaning'),
        ]),
    ];

    // Button wording reflects what tapping will do.
    final String label;
    if (isCurrent) {
      label = 'Current plan';
    } else if (topup != null) {
      label = 'Upgrade  ·  +RM${topup!.toStringAsFixed(2)} now';
    } else if (downgradeLabel != null) {
      label = downgradeLabel!;
    } else if (isSelected) {
      label = 'Selected';
    } else {
      label = 'Choose ${plan.name}';
    }
    final enabled = onTap != null;

    final Widget button;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    const pad = EdgeInsets.symmetric(vertical: 15);
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrent || isSelected) ...[const Icon(Icons.check, size: 18), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
    if (dark) {
      button = FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _ink,
          disabledBackgroundColor: _gold.withValues(alpha: 0.55),
          disabledForegroundColor: _ink.withValues(alpha: 0.8),
          padding: pad,
          shape: shape,
        ),
        child: text,
      );
    } else if (isSelected || isCurrent) {
      button = FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _navy.withValues(alpha: 0.85),
          disabledForegroundColor: Colors.white,
          padding: pad,
          shape: shape,
        ),
        child: text,
      );
    } else {
      button = OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          disabledForegroundColor: _ink.withValues(alpha: 0.45),
          side: BorderSide(color: Colors.grey.shade300),
          padding: pad,
          shape: shape,
        ),
        child: text,
      );
    }

    final highlight = isSelected || isCurrent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Opacity(
        opacity: (!enabled && !isCurrent && downgradeLabel != 'Starts next renewal') ? 0.6 : 1,
        child: Material(
          color: dark ? _navy : Colors.white,
          elevation: dark ? 6 : 0,
          shadowColor: _navy.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: dark
                ? (highlight ? const BorderSide(color: _gold, width: 2) : BorderSide.none)
                : BorderSide(
                    color: highlight ? _navy : const Color(0xFFDCE6F2),
                    width: highlight ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: serif.copyWith(fontSize: 15, color: dark ? _gold : const Color(0xFF1E5BB8))),
                  const SizedBox(height: 6),
                  Text(plan.tagline,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('RM${_money(plan.price)}',
                          style: serif.copyWith(
                              fontSize: 40, fontWeight: FontWeight.w600, color: fg, height: 1)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('/ month', style: TextStyle(fontSize: 13, color: soft)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Divider(
                        height: 1, color: dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDCE6F2)),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: plan.orderQuota == null ? 'Unlimited orders' : '${plan.orderQuota} orders',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' a month'),
                    ]),
                    style: TextStyle(fontSize: 14.5, color: fg),
                  ),
                  const SizedBox(height: 12),
                  for (final b in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(Icons.check, size: 18, color: tick),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(b, style: TextStyle(fontSize: 14, color: soft, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: button),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
