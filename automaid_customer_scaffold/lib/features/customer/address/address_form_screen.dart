import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/address_model.dart';
import '../../auth/widgets/map_picker_screen.dart';
import '../providers/customer_providers.dart';

/// Same address-entry pattern as sign-up's address step: typed fields for
/// line 1/2, postcode, city, country, plus a map pin for lat/long instead
/// of typing coordinates directly. State is a dropdown sourced from
/// /state/index (the backend's own seeded list) rather than free text —
/// free text broke in practice because the seeded dataset names the Kuala
/// Lumpur federal territory "Wp Kuala Lumpur", not "Kuala Lumpur", which
/// nobody would guess by typing. Country is still free-text (defaulted to
/// Malaysia) since this is a single-country app for now.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});
  final Address? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _unitNo;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _postcode;
  late final TextEditingController _country;
  String? _selectedState;
  LatLng? _pinnedLocation;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _title = TextEditingController(text: a?.addressTitle ?? '');
    _unitNo = TextEditingController(text: a?.unitNo ?? '');
    _line1 = TextEditingController(text: a?.addressLine1 ?? '');
    _line2 = TextEditingController(text: a?.addressLine2 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _postcode = TextEditingController(text: a?.postcode ?? '');
    _country = TextEditingController(text: a?.countryName ?? 'Malaysia');
    _selectedState = a?.stateName;
    if (a != null) {
      _pinnedLocation = LatLng(a.latitude, a.longitude);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _unitNo, _line1, _line2, _city, _postcode, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialPosition: _pinnedLocation)),
    );
    if (result != null) {
      setState(() => _pinnedLocation = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null) {
      setState(() => _error = 'Please select a state.');
      return;
    }
    if (_pinnedLocation == null) {
      setState(() => _error = 'Please pin this address on the map.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final address = Address(
      id: widget.existing?.id ?? 0,
      addressTitle: _title.text.trim().isEmpty ? null : _title.text.trim(),
      unitNo: _unitNo.text.trim().isEmpty ? null : _unitNo.text.trim(),
      addressLine1: _line1.text.trim(),
      addressLine2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim(),
      postcode: _postcode.text.trim(),
      stateName: _selectedState!,
      countryName: _country.text.trim(),
      latitude: _pinnedLocation!.latitude,
      longitude: _pinnedLocation!.longitude,
    );

    try {
      final notifier = ref.read(addressListProvider.notifier);
      if (widget.existing != null) {
        await notifier.updateAddress(address);
      } else {
        await notifier.add(address);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(statesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add address' : 'Edit address')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)'),
            ),
            TextFormField(
              controller: _unitNo,
              decoration: const InputDecoration(labelText: 'Unit no.'),
            ),
            TextFormField(
              controller: _line1,
              decoration: const InputDecoration(labelText: 'Address line 1 *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _line2,
              decoration: const InputDecoration(labelText: 'Address line 2'),
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _postcode,
              decoration: const InputDecoration(labelText: 'Postcode *'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            statesAsync.when(
              data: (states) {
                // If editing an existing address whose stored state name
                // isn't in the fetched list for some reason, fall back to
                // null rather than crashing the dropdown on a value with
                // no matching item.
                final validValue =
                    states.any((s) => s.name == _selectedState) ? _selectedState : null;
                return DropdownButtonFormField<String>(
                  value: validValue,
                  decoration: const InputDecoration(labelText: 'State *'),
                  items: states
                      .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedState = v),
                  validator: (v) => (v == null) ? 'Required' : null,
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Could not load states: $e'),
            ),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'Country *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(_pinnedLocation == null
                  ? 'Pin address on map'
                  : 'Location pinned ✓ (tap to adjust)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save address'),
            ),
          ],
        ),
      ),
    );
  }
}
