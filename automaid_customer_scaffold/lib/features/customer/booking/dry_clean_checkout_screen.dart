import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/address_model.dart';
import '../address/address_form_screen.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../providers/customer_providers.dart';
import 'dry_clean_draft_provider.dart';
import 'pickup_handoff_capture.dart';
import '../payment/payment_flow.dart';

class DryCleanCheckoutScreen extends ConsumerStatefulWidget {
  const DryCleanCheckoutScreen({super.key});

  @override
  ConsumerState<DryCleanCheckoutScreen> createState() => _DryCleanCheckoutScreenState();
}

class _DryCleanCheckoutScreenState extends ConsumerState<DryCleanCheckoutScreen> {
  int? _selectedAddressId;
  DateTime _pickupDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  String? _pickupPhotoPath;
  String? _pickupNote;
  bool _isSubmitting = false;
  String? _error;

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<bool> _requirePickupHandoff() async {
    if (_pickupPhotoPath != null && _pickupNote != null && _pickupNote!.trim().isNotEmpty) {
      return true;
    }
    final result = await showPickupHandoffCapture(context);
    if (result == null) return false;
    setState(() {
      _pickupPhotoPath = result.photoPath;
      _pickupNote = result.note;
    });
    return true;
  }

  Future<void> _submit() async {
    if (_selectedAddressId == null) {
      setState(() => _error = 'Please select a pickup address.');
      return;
    }
    if (!await _requirePickupHandoff()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final notifier = ref.read(dryCleanDraftProvider.notifier);
    notifier.setSchedule(
      pickupLocationId: _selectedAddressId!,
      pickupDate: _pickupDate,
      pickupStartTime: _formatTime(_startTime),
      pickupEndTime: _formatTime(_endTime),
    );
    notifier.setPickupHandoff(photoPath: _pickupPhotoPath!, note: _pickupNote!);

    try {
      final result = await notifier.submit();
      if (!mounted) return;

      if (result.containsKey('url')) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid
                ? 'Payment confirmed — dry-cleaning booking is on!'
                : "Payment wasn't confirmed yet — check My Orders shortly."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dry-cleaning booking confirmed!')));
      }
      ref.invalidate(homeBookingsProvider);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(dryCleanDraftProvider);
    final addressesAsync = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule pickup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items (${draft.totalQuantity})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in draft.cart.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${entry.value} × ${entry.key.name}'),
                    Text('RM${(entry.key.pricePerPiece * entry.value).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            const Divider(height: 24),
            addressesAsync.when(
              data: (addresses) {
                if (_selectedAddressId == null && addresses.isNotEmpty) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => setState(() => _selectedAddressId = addresses.first.id));
                }
                if (addresses.isEmpty) {
                  return TextButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AddressListScreen()))
                        .then((_) => ref.invalidate(addressListProvider)),
                    label: const Text('Add a pickup address first'),
                  );
                }
                Address? selected;
                for (final a in addresses) {
                  if (a.id == _selectedAddressId) selected = a;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedAddressId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Pickup address'),
                            items: addresses
                                .map((a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text('${a.displayLabel} — ${a.fullAddressText}',
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => v != null ? setState(() => _selectedAddressId = v) : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Add new address',
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const AddressFormScreen()))
                              .then((_) => ref.invalidate(addressListProvider)),
                        ),
                      ],
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pickup date: ${_pickupDate.toLocal().toString().split(' ').first}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final today = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _pickupDate,
                  firstDate: DateTime(today.year, today.month, today.day),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) setState(() => _pickupDate = picked);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start: ${_formatTime(_startTime)}'),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('End: ${_formatTime(_endTime)}'),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _pickupPhotoPath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                color: _pickupPhotoPath != null ? Colors.green : null,
              ),
              title: Text(_pickupPhotoPath != null ? 'Pickup photo & note added' : 'Add pickup photo & note'),
              subtitle: _pickupPhotoPath != null ? Text(_pickupNote ?? '') : const Text('Required before confirming'),
              trailing: Text(_pickupPhotoPath != null ? 'Edit' : 'Add'),
              onTap: () async {
                final result = await showPickupHandoffCapture(context);
                if (result != null) {
                  setState(() {
                    _pickupPhotoPath = result.photoPath;
                    _pickupNote = result.note;
                  });
                }
              },
            ),
            const Divider(height: 24),
            const Text('ORDER SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 12)),
            _SummaryRow('Items subtotal', draft.subtotal),
            if (draft.discountAmount > 0)
              _SummaryRow('Subscriber discount (${draft.subscriberDiscountPercent.toStringAsFixed(0)}%)', -draft.discountAmount),
            _SummaryRow('Delivery charge', draft.deliveryCharge),
            if (draft.sstPercent > 0) _SummaryRow('SST (${draft.sstPercent.toStringAsFixed(0)}%)', draft.taxCharge),
            const Divider(),
            Text('Grand total: RM${draft.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.amount);
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text('${amount < 0 ? '-' : ''}RM${amount.abs().toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
