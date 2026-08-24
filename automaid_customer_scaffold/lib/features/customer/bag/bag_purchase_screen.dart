import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/address_model.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../providers/customer_providers.dart';
import '../payment/payment_flow.dart';
import 'bag_receipt_screen.dart';

/// Purchases one or more bags at the admin-configured `bag_price`
/// (Settings > bag_price) — matches OrderBagController::placeOrder exactly.
/// A quantity of 1 at zero grand total is treated by the backend as a free
/// first-bag claim (instant, no payment gateway); anything else routes
/// through the payment gateway the same way booking/subscription do.
class BagPurchaseScreen extends ConsumerStatefulWidget {
  const BagPurchaseScreen({super.key});

  @override
  ConsumerState<BagPurchaseScreen> createState() => _BagPurchaseScreenState();
}

class _BagPurchaseScreenState extends ConsumerState<BagPurchaseScreen> {
  int _quantity = 1;
  int? _selectedAddressId;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _purchase() async {
    final user = ref.read(authControllerProvider).user;
    final addresses = ref.read(addressListProvider).valueOrNull ?? [];
    final settingAsync = ref.read(appSettingProvider);

    if (_selectedAddressId == null) {
      setState(() => _error = 'Please select an address.');
      return;
    }
    final setting = settingAsync.valueOrNull;
    if (setting == null) {
      setState(() => _error = 'Pricing not loaded yet — please try again in a moment.');
      return;
    }

    final address = addresses.firstWhere((a) => a.id == _selectedAddressId);
    final total = setting.bagPrice * _quantity;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).purchaseBag(
            billingName: user?.name ?? '',
            billingEmail: user?.email ?? '',
            billingPhone: user?.mobileNo ?? '',
            address: address,
            quantity: _quantity,
            subTotal: total,
            grandTotal: total,
          );

      if (!mounted) return;

      if (result.containsKey('order')) {
        // Free first bag — instant. Jump straight to the receipt.
        ref.invalidate(purchasedBagsProvider);
        final orderId = result['order']?['id'] as int?;
        if (orderId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => BagReceiptScreen(orderId: orderId)),
          );
        } else {
          Navigator.of(context).pop();
        }
      } else if (result.containsKey('url')) {
        final orderId = result['order_id'] as int?;
        final paid = orderId == null
            ? false
            : await runPaymentFlow(
                context: context,
                ref: ref,
                paymentUrl: result['url'].toString(),
                orderId: orderId,
              );

        if (!mounted) return;
        ref.invalidate(purchasedBagsProvider);

        if (paid && orderId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => BagReceiptScreen(orderId: orderId)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Payment wasn't confirmed yet — check My Bags shortly for your receipt.",
              ),
            ),
          );
          Navigator.of(context).pop();
        }
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
    final settingAsync = ref.watch(appSettingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase bag')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          settingAsync.when(
            data: (setting) => Text(
              'RM${setting.bagPrice.toStringAsFixed(2)} per bag',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load pricing: $e'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Quantity'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          addressesAsync.when(
            data: (addresses) {
              if (_selectedAddressId == null && addresses.isNotEmpty) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => setState(() => _selectedAddressId = addresses.first.id));
              }
              if (addresses.isEmpty) {
                return TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AddressListScreen())),
                  child: const Text('Add a delivery address first'),
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
                    decoration: const InputDecoration(labelText: 'Delivery address'),
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
          if (settingAsync.valueOrNull != null) ...[
            const SizedBox(height: 16),
            Text(
              'Total: RM${(settingAsync.value!.bagPrice * _quantity).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _purchase,
            child: _isSubmitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Purchase'),
          ),
        ],
      ),
    );
  }
}
