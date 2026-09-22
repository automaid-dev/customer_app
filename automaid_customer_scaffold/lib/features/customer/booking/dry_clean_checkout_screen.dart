import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/addon_model.dart';
import '../address/address_form_screen.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../providers/customer_providers.dart';
import '../legal/terms_conditions_screen.dart';
import 'dry_clean_draft_provider.dart';
import 'pickup_handoff_capture.dart';
import 'waiting_list_dialog.dart';
import '../payment/payment_flow.dart';

class DryCleanCheckoutScreen extends ConsumerStatefulWidget {
  const DryCleanCheckoutScreen({super.key});

  @override
  ConsumerState<DryCleanCheckoutScreen> createState() => _DryCleanCheckoutScreenState();
}

class _DryCleanCheckoutScreenState extends ConsumerState<DryCleanCheckoutScreen> {
  int? _selectedAddressId;
  // null = not yet checked (e.g. addresses still loading), true =
  // confirmed within coverage, false = confirmed NOT covered. Confirm
  // booking is disabled specifically on false — not on null, so the
  // button isn't disabled while the very first check is still in
  // flight.
  bool? _isAddressCovered;
  DateTime _pickupDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  String? _pickupPhotoPath;
  String? _pickupNote;
  bool _isSubmitting = false;
  String? _error;
  final _voucherController = TextEditingController();
  // Local copy of the fee/coverage figures fetched once via
  // checkInsurance() — same reasoning as the normal booking flow's
  // equivalent: draft.insuranceFee only gets set once the customer
  // actually toggles insurance ON, so this is needed to show the
  // fee/coverage text even before that toggle.
  double? _insuranceFee;
  double? _insuranceCoverage;

  @override
  void initState() {
    super.initState();
    _loadInsuranceInfo();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadInsuranceInfo() async {
    try {
      final result = await ref.read(customerRepositoryProvider).checkInsurance();
      if (mounted) {
        setState(() {
          _insuranceFee = result.fee;
          _insuranceCoverage = result.coverage;
        });
      }
    } catch (_) {
      // Non-fatal — same as the normal booking flow: insurance just
      // won't show fee/coverage figures if this fails.
    }
  }

  Future<void> _refreshAddonDiscount() async {
    await ref.read(dryCleanDraftProvider.notifier).refreshAddonDiscount();
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    final error = await ref.read(dryCleanDraftProvider.notifier).applyVoucher(code);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      _voucherController.clear();
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Same coverage-area check as the normal booking flow
  /// (BookingFlowScreen._onAddressSelected) — checks the address right
  /// after it's applied, and if it's not covered, offers the same two
  /// options: pick a different address, or join the waiting list.
  /// Duplicated here rather than shared, so this screen doesn't depend
  /// on changes to the normal flow's screen (and vice versa).
  Future<void> _onAddressSelected(int id) async {
    setState(() {
      _selectedAddressId = id;
      _isAddressCovered = null;
    });
    try {
      final covered = await ref.read(customerRepositoryProvider).checkCoverage(id);
      if (!mounted) return;
      setState(() => _isAddressCovered = covered);
      if (!covered) {
        await _showNotCoveredDialog();
      }
    } catch (_) {
      // Non-fatal — same reasoning as the normal booking flow: don't
      // block over a failed coverage check itself, so a network hiccup
      // here doesn't lock the customer out of booking entirely.
      if (mounted) setState(() => _isAddressCovered = true);
    }
  }

  Future<void> _showNotCoveredDialog() {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Outside service area'),
        content: const Text(
          'This pickup location is not in our coverage area yet. '
          'You can enter a new pickup address, or join our waiting list '
          "and we'll notify you as soon as we launch in your area.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showJoinWaitingListSheet(context);
            },
            child: const Text('Join waiting list'),
          ),
        ],
      ),
    );
  }

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

  /// Same as BookingFlowScreen._requireTermsAcceptance — shows the T&C
  /// PDF and requires explicit acceptance before proceeding to payment.
  /// Skipped entirely if the admin hasn't uploaded a document (Settings
  /// > Legal Documents), same as the normal booking flow.
  Future<bool> _requireTermsAcceptance() async {
    final setting = await ref.read(customerRepositoryProvider).setting();
    final url = setting.termsConditionsUrl;
    if (url == null || url.isEmpty) return true;

    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TermsConditionsScreen(pdfUrl: url)),
    );
    return accepted == true;
  }

  Future<void> _submit() async {
    if (_selectedAddressId == null) {
      setState(() => _error = 'Please select a pickup address.');
      return;
    }
    if (!await _requirePickupHandoff()) return;
    if (!await _requireTermsAcceptance()) return;

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
            // Dry-clean pricing is per-piece, not per-bag — this isn't
            // for pricing. It's sent as pickup_bag_quantity though,
            // since BookingController::schedule() uses that same field
            // to calculate delivery_charge for every order type, and it
            // doubles as a remark telling the rider how many bags to
            // expect at pickup.
            Row(
              children: [
                Text('Number of bags', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: draft.bagQuantity > 1
                      ? () => ref.read(dryCleanDraftProvider.notifier).setBagQuantity(draft.bagQuantity - 1)
                      : null,
                ),
                Text('${draft.bagQuantity}', style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => ref.read(dryCleanDraftProvider.notifier).setBagQuantity(draft.bagQuantity + 1),
                ),
              ],
            ),
            Text(
              'How many bags your items are packed into — helps the rider at pickup.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            addressesAsync.when(
              data: (addresses) {
                if (_selectedAddressId == null && addresses.isNotEmpty) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _onAddressSelected(addresses.first.id));
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
                            onChanged: (v) => v != null ? _onAddressSelected(v) : null,
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
            Text('Add-ons', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            FutureBuilder<List<AddOn>>(
              future: ref.read(customerRepositoryProvider).addOnList(forDryCleaning: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final addons = snapshot.data!;
                if (addons.isEmpty) return const Text('No add-ons available.');
                return Column(
                  children: addons.map((a) {
                    final isSelected = draft.selectedAddons.any((s) => s.id == a.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) async {
                        ref.read(dryCleanDraftProvider.notifier).toggleAddon(a);
                        await _refreshAddonDiscount();
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(a.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RM${a.price.toStringAsFixed(2)}'),
                          if (a.description != null && a.description!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                a.description!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const Divider(height: 24),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: draft.insuranceSelected,
              onChanged: (checked) =>
                  ref.read(dryCleanDraftProvider.notifier).toggleInsurance(checked ?? false),
              title: const Text('Risk-Free Insurance'),
              subtitle: Text(
                _insuranceFee != null
                    ? 'RM${_insuranceFee!.toStringAsFixed(2)} — covers up to '
                        'RM${(_insuranceCoverage ?? 0).toStringAsFixed(2)} if your laundry is lost or damaged'
                    : 'Optional — protects your laundry against loss or damage',
              ),
            ),
            const Divider(height: 24),
            Text('Voucher', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherController,
                    decoration: const InputDecoration(labelText: 'Voucher code'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _applyVoucher, child: const Text('Apply')),
              ],
            ),
            if (draft.voucher != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  label: Text('Applied: ${draft.voucher!.code}'),
                  onDeleted: () => ref.read(dryCleanDraftProvider.notifier).removeVoucher(),
                ),
              ),
            const Divider(height: 24),
            const Text('ORDER SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 12)),
            _SummaryRow('Items subtotal', draft.subtotal),
            if (draft.discountAmount > 0)
              _SummaryRow('Subscriber discount (${draft.subscriberDiscountPercent.toStringAsFixed(0)}%)', -draft.discountAmount),
            if (draft.addonCharge > 0) _SummaryRow('Add-ons', draft.addonCharge),
            if (draft.addonDiscount > 0) _SummaryRow('Add-on discount', -draft.addonDiscount),
            _SummaryRow('Delivery charge', draft.deliveryCharge),
            if (draft.sstPercent > 0) _SummaryRow('SST (${draft.sstPercent.toStringAsFixed(0)}%)', draft.taxCharge),
            if (draft.insuranceSelected) _SummaryRow('Risk-Free Insurance', draft.insuranceFee),
            if (draft.voucher != null) _SummaryRow('Voucher discount', -draft.voucherDiscountAmount),
            const Divider(),
            Text('Grand total: RM${draft.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_isAddressCovered == false) ...[
              const SizedBox(height: 8),
              const Text(
                'This address is outside our service area. Please choose a different pickup address to continue.',
                style: TextStyle(color: Colors.red, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_isSubmitting || _isAddressCovered == false) ? null : _submit,
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
