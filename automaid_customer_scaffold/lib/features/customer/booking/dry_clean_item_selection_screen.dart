import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/service_category_model.dart';
import '../providers/customer_providers.dart';
import 'dry_clean_draft_provider.dart';
import 'dry_clean_checkout_screen.dart';

/// Entry point for the dry-cleaning booking flow — fetches the active
/// catalog (POST /customer/booking/service-category/lists), lets the
/// customer build a cart with quantity steppers, then proceeds to
/// DryCleanCheckoutScreen once at least one item is added.
class DryCleanItemSelectionScreen extends ConsumerStatefulWidget {
  const DryCleanItemSelectionScreen({super.key});

  @override
  ConsumerState<DryCleanItemSelectionScreen> createState() => _DryCleanItemSelectionScreenState();
}

class _DryCleanItemSelectionScreenState extends ConsumerState<DryCleanItemSelectionScreen> {
  bool _loading = true;
  String? _error;
  List<ServiceCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(customerRepositoryProvider).serviceCategoryList();
      // Today there's only one launched category (Dry Cleaning) — the
      // backend already filters to is_active=true, so the first one
      // returned is it. If more categories launch later, this becomes
      // a category-picker step before item selection.
      final category = result.categories.isNotEmpty ? result.categories.first : null;
      if (category != null) {
        ref.read(dryCleanDraftProvider.notifier).applyCatalogInfo(
              serviceCategoryId: category.id,
              subscriberDiscountPercent: result.subscriberDiscountPercent,
              maxItemsPerBag: result.maxItemsPerBag,
            );
        ref.read(dryCleanDraftProvider.notifier).loadDeliveryEstimate();
      }
      if (!mounted) return;
      setState(() {
        _categories = result.categories;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(dryCleanDraftProvider);
    final category = _categories.isNotEmpty ? _categories.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Dry Cleaning')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : category == null || category.items.isEmpty
                  ? const Center(child: Text('No dry-cleaning items available right now.'))
                  : Column(
                      children: [
                        if (draft.subscriberDiscountPercent > 0)
                          Container(
                            width: double.infinity,
                            color: Colors.green.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'Your subscription gives you ${draft.subscriberDiscountPercent.toStringAsFixed(0)}% off dry cleaning',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: category.items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = category.items[index];
                              final qty = draft.cart[item] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    if (item.imageUrl != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(item.imageUrl!, width: 48, height: 48, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('RM${item.pricePerPiece.toStringAsFixed(2)} / piece',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: qty > 0
                                          ? () => ref.read(dryCleanDraftProvider.notifier).decrement(item)
                                          : null,
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => ref.read(dryCleanDraftProvider.notifier).increment(item),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (draft.isOverLimit)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'This bag holds up to ${draft.maxItemsPerBag} items — you have ${draft.totalQuantity}. Remove some to continue.',
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${draft.totalQuantity} item(s)', style: const TextStyle(color: Colors.grey)),
                                    if (draft.discountAmount > 0)
                                      Text('RM${draft.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 13)),
                                    Text('RM${draft.itemsTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: (draft.isEmpty || draft.isOverLimit)
                                      ? null
                                      : () => Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => const DryCleanCheckoutScreen()),
                                          ),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
