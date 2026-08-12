import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/address_model.dart';
import '../providers/customer_providers.dart';

/// Country/state are plain text fields for now. The backend has dedicated
/// /country/index and /state/index endpoints (ApiEndpoints.countries /
/// ApiEndpoints.states) meant to back real pickers — worth wiring up before
/// shipping, since `get_country_id()` / `get_state_id()` on the backend do
/// an exact name lookup and silently store null on a typo.
///
/// Latitude/longitude are also plain fields here; swap for a map picker
/// (e.g. google_maps_flutter + Places Autocomplete) when you're ready —
/// the backend requires both and uses them as-is (see AddressController).
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
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
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
    _state = TextEditingController(text: a?.stateName ?? '');
    _country = TextEditingController(text: a?.countryName ?? 'Malaysia');
    _lat = TextEditingController(text: a?.latitude.toString() ?? '');
    _lng = TextEditingController(text: a?.longitude.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _unitNo, _line1, _line2, _city, _postcode, _state, _country, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      stateName: _state.text.trim(),
      countryName: _country.text.trim(),
      latitude: double.tryParse(_lat.text.trim()) ?? 0,
      longitude: double.tryParse(_lng.text.trim()) ?? 0,
    );

    try {
      final notifier = ref.read(addressListProvider.notifier);
      if (widget.existing != null) {
        await notifier.update(address);
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
            TextFormField(
              controller: _state,
              decoration: const InputDecoration(labelText: 'State *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'Country *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    decoration: const InputDecoration(labelText: 'Latitude *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    decoration: const InputDecoration(labelText: 'Longitude *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
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
