import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/addon_model.dart';
import '../../../core/models/address_model.dart';
import '../address/address_form_screen.dart';
import '../address/address_list_screen.dart';
import '../address/address_preview_card.dart';
import '../legal/terms_conditions_screen.dart';
import '../payment/payment_flow.dart';
import '../providers/customer_providers.dart';
import 'booking_draft_provider.dart';

/// Booking flow, step by step:
/// 1. Bag quantity -> calculateRate
/// 2. Add-ons (optional) -> checkAddonDiscount
/// 3. Voucher code (optional) -> checkVoucher
/// 4. Pickup address + date/time + which scanned QR codes to send
/// 5. Confirm & submit -> schedule()
///
/// On submit, either the booking is confirmed instantly (subscriber with no
/// extra charges, or zero grand total) or a payment URL comes back that
/// needs to be opened (e.g. in a WebView) to complete payment.
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  int _step = 0;
  bool _isSubmitting = false;
  String? _error;

  // Step 1 state
  int _quantity = 1;
  bool _rateLoaded = false;

  // Step 4 state
  int? _selectedAddressId;
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  final Set<String> _selectedQrcodes = {};

  final _voucherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load the rate for the default quantity right away so the person
    // sees real pricing immediately, not just after tapping Next once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRate());
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    setState(() => _error = null);
    try {
      await ref.read(bookingDraftProvider.notifier).setQuantity(_quantity);
      setState(() => _rateLoaded = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _changeQuantity(int delta) {
    setState(() {
      _quantity += delta;
      _rateLoaded = false;
    });
    // Recalculate immediately rather than waiting for "Next" — the
    // person should see the real total update as soon as they change
    // the quantity, not after an extra tap.
    _loadRate();
  }

  Future<void> _refreshAddonDiscount() async {
    await ref.read(bookingDraftProvider.notifier).refreshAddonDiscount();
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    final error = await ref.read(bookingDraftProvider.notifier).applyVoucher(code);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Shows the Terms & Conditions PDF and requires explicit acceptance
  /// before the booking proceeds to payment. If the admin hasn't
  /// uploaded a document yet (Settings > Legal Documents), this step is
  /// skipped entirely rather than blocking booking on a document that
  /// doesn't exist.
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
    if (_selectedQrcodes.length < _quantity) {
      setState(() => _error = 'Please select $_quantity QR code(s) for this booking.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    ref.read(bookingDraftProvider.notifier).setSchedule(
          pickupLocationId: _selectedAddressId!,
          pickupDate: _pickupDate,
          pickupStartTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          pickupEndTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
          qrcodeSeriesNumbers: _selectedQrcodes.toList(),
        );

    try {
      final result = await ref.read(bookingDraftProvider.notifier).submit();
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
                ? 'Payment confirmed — booking is on!'
                : "Payment wasn't confirmed yet — check My Orders shortly."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking confirmed!')));
      }
      ref.invalidate(homeBookingsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New booking')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () async {
          if (_step == 0 && !_rateLoaded) {
            await _loadRate();
            if (!_rateLoaded) return;
          }
          if (_step < 3) {
            setState(() => _step++);
          } else {
            final accepted = await _requireTermsAcceptance();
            if (accepted) await _submit();
          }
        },
        onStepCancel: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              FilledButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_step == 3 ? 'Confirm booking' : 'Next'),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Bags'),
            isActive: _step >= 0,
            state: _rateLoaded ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('How many bags?'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity > 1 ? () => _changeQuantity(-1) : null,
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _changeQuantity(1),
                    ),
                  ],
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final settingAsync = ref.watch(appSettingProvider);
                    return settingAsync.when(
                      data: (setting) => Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'RM${setting.washFee.toStringAsFixed(2)}/bag washing · '
                          'RM${setting.deliveryPrice.toStringAsFixed(2)}/bag delivery',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    );
                  },
                ),
                if (!_rateLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_rateLoaded) ...[
                  Text('Washing total: RM${draft.washingCharge.toStringAsFixed(2)}'),
                  Text('Delivery total: RM${draft.deliveryCharge.toStringAsFixed(2)}'),
                ],
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Step(
            title: const Text('Add-ons'),
            isActive: _step >= 1,
            content: _AddonsStep(
              selected: draft.selectedAddons,
              onChanged: (addon) async {
                ref.read(bookingDraftProvider.notifier).toggleAddon(addon);
                await _refreshAddonDiscount();
              },
            ),
          ),
          Step(
            title: const Text('Voucher'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  Chip(
                    label: Text('Applied: ${draft.voucher!.code}'),
                    onDeleted: () => ref.read(bookingDraftProvider.notifier).removeVoucher(),
                  ),
              ],
            ),
          ),
          Step(
            title: const Text('Schedule'),
            isActive: _step >= 3,
            content: _ScheduleStep(
              selectedAddressId: _selectedAddressId,
              onAddressSelected: (id) => setState(() => _selectedAddressId = id),
              pickupDate: _pickupDate,
              onDateChanged: (d) => setState(() => _pickupDate = d),
              startTime: _startTime,
              onStartTimeChanged: (t) => setState(() => _startTime = t),
              endTime: _endTime,
              onEndTimeChanged: (t) => setState(() => _endTime = t),
              selectedQrcodes: _selectedQrcodes,
              requiredQuantity: _quantity,
              onQrcodeToggled: (code) => setState(() {
                if (_selectedQrcodes.contains(code)) {
                  _selectedQrcodes.remove(code);
                } else {
                  _selectedQrcodes.add(code);
                }
              }),
              draft: draft,
              error: _error,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonsStep extends ConsumerWidget {
  const _AddonsStep({required this.selected, required this.onChanged});
  final List<AddOn> selected;
  final void Function(AddOn) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(customerRepositoryProvider);
    return FutureBuilder<List<AddOn>>(
      future: repo.addOnList(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final addons = snapshot.data!;
        if (addons.isEmpty) return const Text('No add-ons available.');
        return Column(
          children: addons.map((a) {
            final isSelected = selected.any((s) => s.id == a.id);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => onChanged(a),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(a.name),
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
    );
  }
}

class _ScheduleStep extends ConsumerWidget {
  const _ScheduleStep({
    required this.selectedAddressId,
    required this.onAddressSelected,
    required this.pickupDate,
    required this.onDateChanged,
    required this.startTime,
    required this.onStartTimeChanged,
    required this.endTime,
    required this.onEndTimeChanged,
    required this.selectedQrcodes,
    required this.requiredQuantity,
    required this.onQrcodeToggled,
    required this.draft,
    required this.error,
  });

  final int? selectedAddressId;
  final ValueChanged<int> onAddressSelected;
  final DateTime pickupDate;
  final ValueChanged<DateTime> onDateChanged;
  final TimeOfDay startTime;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final TimeOfDay endTime;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final Set<String> selectedQrcodes;
  final int requiredQuantity;
  final ValueChanged<String> onQrcodeToggled;
  final BookingDraft draft;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressListProvider);
    final repo = ref.read(customerRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        addressesAsync.when(
          data: (addresses) {
            // Auto-select the default (first) address so the customer
            // doesn't have to manually pick it every booking — still
            // changeable via the dropdown below.
            if (selectedAddressId == null && addresses.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => onAddressSelected(addresses.first.id));
            }
            if (addresses.isEmpty) {
              return TextButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddressListScreen()),
                ).then((_) => ref.invalidate(addressListProvider)),
                label: const Text('Add a pickup address first'),
              );
            }

            Address? selected;
            for (final a in addresses) {
              if (a.id == selectedAddressId) selected = a;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedAddressId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Pickup address'),
                        items: addresses
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.displayLabel} — ${a.fullAddressText}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => v != null ? onAddressSelected(v) : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add new address',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddressFormScreen()),
                      ).then((_) => ref.invalidate(addressListProvider)),
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
          title: Text('Pickup date: ${pickupDate.toLocal().toString().split(' ').first}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: pickupDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (picked != null) onDateChanged(picked);
          },
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Start: ${startTime.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: startTime);
                  if (picked != null) onStartTimeChanged(picked);
                },
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('End: ${endTime.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: endTime);
                  if (picked != null) onEndTimeChanged(picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Select $requiredQuantity scanned bag QR code(s):'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.bookingQrcodes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final qrcodes = snapshot.data!;
            if (qrcodes.isEmpty) {
              return const Text('No scanned bags available — scan a bag first.');
            }
            return Column(
              children: qrcodes.map((q) {
                final series = q['series_no']?.toString() ?? '';
                return CheckboxListTile(
                  value: selectedQrcodes.contains(series),
                  onChanged: (_) => onQrcodeToggled(series),
                  title: Text(series),
                );
              }).toList(),
            );
          },
        ),
        const Divider(),
        const Text('ORDER SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 12)),
        _SummaryRow('Washing charge', draft.washingCharge),
        if (draft.addonCharge > 0) _SummaryRow('Add-on charge', draft.addonCharge),
        if (draft.addonDiscount > 0) _SummaryRow('Add-on discount', -draft.addonDiscount),
        if (draft.insuranceSelected) _SummaryRow('Risk-Free Insurance', draft.insuranceFee),
        if (draft.voucher != null) _SummaryRow('Voucher discount', -draft.voucherDiscountAmount),
        if (draft.birthdayRewardSelected) _SummaryRow('Birthday reward', -draft.birthdayRewardAmount),
        _SummaryRow('Delivery charge', draft.deliveryCharge),
        if (draft.sstPercent > 0) _SummaryRow('SST (${draft.sstPercent.toStringAsFixed(0)}%)', draft.taxCharge),
        const Divider(),
        Text('Grand total: RM${draft.grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.amount);
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            '${isNegative ? '-' : ''}RM${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(color: isNegative ? Colors.green : null),
          ),
        ],
      ),
    );
  }
}
