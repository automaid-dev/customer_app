import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/widgets/form_section_card.dart';
import 'widgets/map_picker_screen.dart';

/// Full rider registration — matches RiderController::register's field
/// list exactly (see AuthRepository.registerRider). [typeRider] comes
/// from RegisterRoleScreen ('gig' or 'staff').
///
/// All 5 verification documents (IC front/back, license front/back, AND
/// JPJ grant) are required here — the flow spec explicitly flagged that
/// the previous app never collected the JPJ grant even though the
/// backend has always supported it (RiderController::register accepts
/// `jpj_grant` alongside the other 4 files). Continue only enables once
/// all 5 are attached.
class RegisterRiderScreen extends ConsumerStatefulWidget {
  const RegisterRiderScreen({super.key, required this.typeRider});
  final String typeRider;

  @override
  ConsumerState<RegisterRiderScreen> createState() => _RegisterRiderScreenState();
}

class _RegisterRiderScreenState extends ConsumerState<RegisterRiderScreen> {
  int _step = 0;
  bool _isSubmitting = false;
  String? _error;
  int? _userId;

  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  String? _idType;
  final _icno = TextEditingController();

  // Address
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _postcode = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Malaysia');
  String? _selectedState;
  LatLng? _pinnedLocation;

  // Emergency contact
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _emergencyRelation = TextEditingController();

  // Vehicle
  String? _vehicleType;
  final _plateNo = TextEditingController();
  final _vehicleMake = TextEditingController();
  final _vehicleModel = TextEditingController();
  String? _vehicleColor;
  final _vehicleColorOther = TextEditingController();

  // Bank (optional)
  String? _bankName;
  final _bankNo = TextEditingController();

  // Password
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  // Documents
  File? _icFront, _icBack, _licenseFront, _licenseBack, _jpjGrant;

  // OTP
  final _otp = TextEditingController();

  static const _idTypes = ['NRIC', 'Passport'];
  static const _vehicleTypes = ['Motorcycle', 'Car', 'Van', 'Bicycle'];
  static const _vehicleColors = ['Black', 'White', 'Red', 'Blue', 'Silver', 'Other'];

  @override
  void dispose() {
    for (final c in [
      _name, _email, _mobile, _icno, _addressLine1, _addressLine2, _postcode, _city, _country,
      _emergencyName, _emergencyPhone, _emergencyRelation, _plateNo, _vehicleMake, _vehicleModel,
      _vehicleColorOther, _bankNo, _password, _confirmPassword, _otp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _normalizedMobile {
    var digits = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '60$digits';
  }

  String get _normalizedEmergencyPhone {
    var digits = _emergencyPhone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '60$digits';
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context)
        .push<LatLng>(MaterialPageRoute(builder: (_) => MapPickerScreen(initialPosition: _pinnedLocation)));
    if (result != null) setState(() => _pinnedLocation = result);
  }

  Future<void> _pickDocument(void Function(File) onPicked) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() => onPicked(File(picked.path)));
  }

  bool get _allDocumentsAttached =>
      _icFront != null && _icBack != null && _licenseFront != null && _licenseBack != null && _jpjGrant != null;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pinnedLocation == null) {
      setState(() => _error = 'Please pin your address on the map.');
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submitRegistration() async {
    if (!_allDocumentsAttached) {
      setState(() => _error = 'Please attach all 5 documents before continuing.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).registerRider(
            name: _name.text.trim(),
            email: _email.text.trim(),
            mobileNo: _normalizedMobile,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
            icno: _icno.text.trim(),
            idType: _idType,
            addressLine1: _addressLine1.text.trim(),
            addressLine2: _addressLine2.text.trim(),
            countryName: _country.text.trim(),
            stateName: _selectedState ?? '',
            postcode: _postcode.text.trim(),
            city: _city.text.trim(),
            typeRider: widget.typeRider,
            typeVehicle: _vehicleType ?? '',
            emergencyName: _emergencyName.text.trim(),
            emergencyPhone: _normalizedEmergencyPhone,
            emergencyRelation: _emergencyRelation.text.trim(),
            plateNo: _plateNo.text.trim(),
            vehicleMake: _vehicleMake.text.trim(),
            vehicleModel: _vehicleModel.text.trim(),
            vehicleColor: _vehicleColor == 'Other' ? _vehicleColorOther.text.trim() : _vehicleColor,
            bankName: _bankName,
            bankNo: _bankNo.text.trim().isEmpty ? null : _bankNo.text.trim(),
            latitude: _pinnedLocation!.latitude,
            longitude: _pinnedLocation!.longitude,
            icFrontPath: _icFront!.path,
            icBackPath: _icBack!.path,
            licenseFrontPath: _licenseFront!.path,
            licenseBackPath: _licenseBack!.path,
            jpjGrantPath: _jpjGrant!.path,
          );
      if (result.status && result.userId != null) {
        setState(() {
          _userId = result.userId;
          _step = 2;
        });
      } else {
        setState(() => _error = result.message);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitOtp() async {
    if (_otp.text.trim().isEmpty || _userId == null) {
      setState(() => _error = 'Please enter the OTP sent to your phone.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .verifyRegisterRider(userId: _userId!, otp: _otp.text.trim());
      if (!result.status) {
        setState(() => _error = result.message ?? 'Invalid OTP.');
        return;
      }
      // Router redirects automatically once auth state flips — it'll
      // land on the pending-approval screen since status is ONBOARDING
      // until admin approves.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendOtp() async {
    final result = await ref.read(authControllerProvider.notifier).resendOtp(_email.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Step ${_step + 1}/3')),
      body: Column(
        children: [
          StepProgressBar(currentStep: _step, totalSteps: 3),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _buildFormStep(),
                _buildDocumentsStep(),
                _buildOtpStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            icon: Icons.person_outline,
            title: 'Personal Information',
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
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
              DropdownButtonFormField<String>(
                value: _idType,
                decoration: const InputDecoration(labelText: 'ID Type *'),
                items: _idTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _idType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _icno,
                decoration: InputDecoration(labelText: '${_idType ?? "ID"} Number *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
          FormSectionCard(
            icon: Icons.location_on_outlined,
            title: 'Address',
            children: [
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
                    data: (states) => DropdownButtonFormField<String>(
                      value: _selectedState,
                      decoration: const InputDecoration(labelText: 'State *'),
                      items: states.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                      onChanged: (v) => setState(() => _selectedState = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
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
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: Icon(_pinnedLocation == null ? Icons.map_outlined : Icons.check_circle, size: 18),
                label: Text(_pinnedLocation == null ? 'Pin address on map' : 'Location pinned — tap to adjust'),
              ),
            ],
          ),
          FormSectionCard(
            icon: Icons.emergency_outlined,
            title: 'Emergency Contact',
            children: [
              TextFormField(
                controller: _emergencyName,
                decoration: const InputDecoration(labelText: 'Full name *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone *', prefixText: '+60 '),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length < 9 ? 'Enter a valid phone number' : null;
                },
              ),
              TextFormField(
                controller: _emergencyRelation,
                decoration: const InputDecoration(labelText: 'Relation *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
          FormSectionCard(
            icon: Icons.two_wheeler_outlined,
            title: 'Vehicle Information',
            children: [
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(labelText: 'Vehicle type *'),
                items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _vehicleType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _plateNo,
                decoration: const InputDecoration(labelText: 'Plate number *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _vehicleMake,
                decoration: const InputDecoration(labelText: 'Vehicle make *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _vehicleModel,
                decoration: const InputDecoration(labelText: 'Vehicle model *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _vehicleColor,
                decoration: const InputDecoration(labelText: 'Vehicle colour'),
                items: _vehicleColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _vehicleColor = v),
              ),
              if (_vehicleColor == 'Other')
                TextFormField(
                  controller: _vehicleColorOther,
                  decoration: const InputDecoration(labelText: 'Colour (other) *'),
                  validator: (v) =>
                      (_vehicleColor == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                ),
            ],
          ),
          FormSectionCard(
            icon: Icons.account_balance_outlined,
            title: 'Bank Information (optional)',
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final banksAsync = ref.watch(banksProvider);
                  return banksAsync.when(
                    data: (banks) => DropdownButtonFormField<String>(
                      value: _bankName,
                      decoration: const InputDecoration(labelText: 'Bank name'),
                      items: banks.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(),
                      onChanged: (v) => setState(() => _bankName = v),
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
                decoration: const InputDecoration(labelText: 'Bank account number'),
              ),
            ],
          ),
          FormSectionCard(
            icon: Icons.lock_outline,
            title: 'Create Password',
            children: [
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password *'),
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              TextFormField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password *'),
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: _submitForm, child: const Text('Next')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('RIDER VERIFICATION', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        _DocumentTile(
          label: 'Identity Card (Front)',
          file: _icFront,
          onTap: () => _pickDocument((f) => _icFront = f),
        ),
        _DocumentTile(
          label: 'Identity Card (Back)',
          file: _icBack,
          onTap: () => _pickDocument((f) => _icBack = f),
        ),
        _DocumentTile(
          label: 'Driving License (Front)',
          file: _licenseFront,
          onTap: () => _pickDocument((f) => _licenseFront = f),
        ),
        _DocumentTile(
          label: 'Driving License (Back)',
          file: _licenseBack,
          onTap: () => _pickDocument((f) => _licenseBack = f),
        ),
        _DocumentTile(
          label: 'JPJ Grant',
          file: _jpjGrant,
          onTap: () => _pickDocument((f) => _jpjGrant = f),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitRegistration,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Back')),
      ],
    );
  }

  Widget _buildOtpStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('We sent a code to +60 ${_mobile.text.trim()}.'),
        const SizedBox(height: 12),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'OTP code'),
        ),
        TextButton(onPressed: _resendOtp, child: const Text('Resend OTP')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitOtp,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify & finish'),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.label, required this.file, required this.onTap});
  final String label;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          file != null ? Icons.check_circle : Icons.camera_alt_outlined,
          color: file != null ? Colors.green : null,
        ),
        title: Text(label),
        subtitle: Text(file != null ? 'Captured — tap to retake' : 'Tap to take photo'),
        onTap: onTap,
      ),
    );
  }
}
