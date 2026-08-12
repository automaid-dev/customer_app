import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/addon_model.dart';
import '../address/address_list_screen.dart';
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
        // Needs payment — open result['url'] in a WebView / external browser.
        // Wire up url_launcher or webview_flutter here.
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment required'),
            content: Text('Open this link to complete payment:\n${result['url']}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
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
            await _submit();
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
                      onPressed: _quantity > 1
                          ? () => setState(() {
                                _quantity--;
                                _rateLoaded = false;
                              })
                          : null,
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() {
                        _quantity++;
                        _rateLoaded = false;
                      }),
                    ),
                  ],
                ),
                if (_rateLoaded) ...[
                  Text('Washing: RM${draft.washingCharge.toStringAsFixed(2)}'),
                  Text('Delivery: RM${draft.deliveryCharge.toStringAsFixed(2)}'),
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
              grandTotal: draft.grandTotal,
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
              title: Text(a.name),
              subtitle: Text('RM${a.price.toStringAsFixed(2)}'),
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
    required this.grandTotal,
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
  final double grandTotal;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressListProvider);
    final repo = ref.read(customerRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        addressesAsync.when(
          data: (addresses) => addresses.isEmpty
              ? TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddressListScreen()),
                  ),
                  child: const Text('Add a pickup address first'),
                )
              : DropdownButtonFormField<int>(
                  value: selectedAddressId,
                  decoration: const InputDecoration(labelText: 'Pickup address'),
                  items: addresses
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.displayLabel)))
                      .toList(),
                  onChanged: (v) => v != null ? onAddressSelected(v) : null,
                ),
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
        Text('Grand total: RM${grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}
