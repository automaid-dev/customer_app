import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../auth/widgets/map_picker_screen.dart';
import '../providers/merchant_providers.dart';

/// Editable merchant profile — matches
/// Api/Merchant/ProfileController::profileUpdate's field list exactly.
/// Pre-fills from the values already loaded on the read-only profile
/// screen (passed in via [initialUser]) so this doesn't need a second fetch.
class MerchantProfileEditScreen extends ConsumerStatefulWidget {
  const MerchantProfileEditScreen({super.key, required this.initialUser});
  final Map<String, dynamic> initialUser;

  @override
  ConsumerState<MerchantProfileEditScreen> createState() => _MerchantProfileEditScreenState();
}

class _MerchantProfileEditScreenState extends ConsumerState<MerchantProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _icno;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _unitNo;
  late final TextEditingController _block;
  late final TextEditingController _postcode;
  late final TextEditingController _city;
  late final TextEditingController _country;
  String? _selectedState;
  LatLng? _pinnedLocation;

  late final TextEditingController _washerQuantity;
  late final TextEditingController _dryerQuantity;
  late final TextEditingController _companyName;
  late final TextEditingController _ssmNo;

  String? _bankName;
  late final TextEditingController _bankNo;

  File? _avatar;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    final merchant = u['merchant'] as Map<String, dynamic>?;
    _name = TextEditingController(text: u['name']?.toString() ?? '');
    _mobile = TextEditingController(text: u['mobile_no']?.toString() ?? '');
    _icno = TextEditingController(text: u['icno']?.toString() ?? '');
    _addressLine1 = TextEditingController(text: merchant?['address_line_1']?.toString() ?? '');
    _addressLine2 = TextEditingController(text: merchant?['address_line_2']?.toString() ?? '');
    _unitNo = TextEditingController(text: merchant?['unit_no']?.toString() ?? '');
    _block = TextEditingController(text: merchant?['block']?.toString() ?? '');
    _postcode = TextEditingController(text: merchant?['postcode']?.toString() ?? '');
    _city = TextEditingController(text: merchant?['city']?.toString() ?? '');
    _country = TextEditingController(text: 'Malaysia');
    final lat = double.tryParse(u['latitude']?.toString() ?? '');
    final lng = double.tryParse(u['longitude']?.toString() ?? '');
    if (lat != null && lng != null) _pinnedLocation = LatLng(lat, lng);

    _washerQuantity = TextEditingController(text: merchant?['washer_quantity']?.toString() ?? '');
    _dryerQuantity = TextEditingController(text: merchant?['dryer_quantity']?.toString() ?? '');
    _companyName = TextEditingController(text: merchant?['company_name']?.toString() ?? '');
    _ssmNo = TextEditingController(text: merchant?['ssm_no']?.toString() ?? '');
    _bankName = merchant?['bank_name']?.toString();
    _bankNo = TextEditingController(text: merchant?['bank_no']?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _mobile, _icno, _addressLine1, _addressLine2, _unitNo, _block, _postcode, _city,
      _country, _washerQuantity, _dryerQuantity, _companyName, _ssmNo, _bankNo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context)
        .push<LatLng>(MaterialPageRoute(builder: (_) => MapPickerScreen(initialPosition: _pinnedLocation)));
    if (result != null) setState(() => _pinnedLocation = result);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _avatar = File(picked.path));
  }

  String get _normalizedMobile {
    var digits = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('60')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '60$digits';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(merchantRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            mobileNo: _normalizedMobile,
            icno: _icno.text.trim(),
            addressLine1: _addressLine1.text.trim(),
            addressLine2: _addressLine2.text.trim().isEmpty ? null : _addressLine2.text.trim(),
            unitNo: _unitNo.text.trim().isEmpty ? null : _unitNo.text.trim(),
            block: _block.text.trim().isEmpty ? null : _block.text.trim(),
            countryName: _country.text.trim(),
            stateName: _selectedState ?? '',
            postcode: _postcode.text.trim(),
            city: _city.text.trim(),
            washerQuantity: int.tryParse(_washerQuantity.text.trim()) ?? 0,
            dryerQuantity: int.tryParse(_dryerQuantity.text.trim()) ?? 0,
            companyName: _companyName.text.trim(),
            ssmNo: _ssmNo.text.trim(),
            bankName: _bankName ?? '',
            bankNo: _bankNo.text.trim(),
            latitude: _pinnedLocation?.latitude,
            longitude: _pinnedLocation?.longitude,
            avatarPath: _avatar?.path,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated.')));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                  child: _avatar == null ? const Icon(Icons.camera_alt_outlined, size: 28) : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile phone *', prefixText: '+60 '),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 9 ? 'Enter a valid mobile number' : null;
              },
            ),
            TextFormField(
              controller: _icno,
              decoration: const InputDecoration(labelText: 'IC / ID number *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('OUTLET ADDRESS', style: TextStyle(color: Colors.grey, fontSize: 12)),
            TextFormField(
              controller: _unitNo,
              decoration: const InputDecoration(labelText: 'Unit no.'),
            ),
            TextFormField(
              controller: _block,
              decoration: const InputDecoration(labelText: 'Block'),
            ),
            TextFormField(
              controller: _addressLine1,
              decoration: const InputDecoration(labelText: 'Address line 1 *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _addressLine2,
              decoration: const InputDecoration(labelText: 'Address line 2'),
            ),
            TextFormField(
              controller: _postcode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Postcode *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            Consumer(
              builder: (context, ref, _) {
                final statesAsync = ref.watch(statesProvider);
                return statesAsync.when(
                  data: (states) {
                    final validValue =
                        states.any((s) => s.name == _selectedState) ? _selectedState : null;
                    return DropdownButtonFormField<String>(
                      value: validValue,
                      decoration: const InputDecoration(labelText: 'State *'),
                      items: states.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                      onChanged: (v) => setState(() => _selectedState = v),
                      validator: (v) => v == null ? 'Required' : null,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text('Could not load states: $e'),
                );
              },
            ),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'Country *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(_pinnedLocation == null ? 'Pin outlet location on map' : 'Location pinned ✓ (tap to adjust)'),
            ),
            const SizedBox(height: 16),
            const Text('LAUNDRY EQUIPMENT DETAILS', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _washerQuantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Washer quantity *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dryerQuantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dryer quantity *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('COMPANY INFORMATION', style: TextStyle(color: Colors.grey, fontSize: 12)),
            TextFormField(
              controller: _companyName,
              decoration: const InputDecoration(labelText: 'Company name *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _ssmNo,
              decoration: const InputDecoration(labelText: 'SSM number *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('BANK INFORMATION', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Consumer(
              builder: (context, ref, _) {
                final banksAsync = ref.watch(banksProvider);
                return banksAsync.when(
                  data: (banks) => DropdownButtonFormField<String>(
                    value: banks.any((b) => b.name == _bankName) ? _bankName : null,
                    decoration: const InputDecoration(labelText: 'Bank name *'),
                    items: banks.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(),
                    onChanged: (v) => setState(() => _bankName = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text('Could not load banks: $e'),
                );
              },
            ),
            TextFormField(
              controller: _bankNo,
              decoration: const InputDecoration(labelText: 'Bank account number *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
