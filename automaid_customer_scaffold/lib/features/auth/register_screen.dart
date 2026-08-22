import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/address_model.dart';
import '../customer/providers/customer_providers.dart';
import 'widgets/map_picker_screen.dart';

/// Sign-up flow: personal info -> address (typed fields + map pin) -> OTP.
///
/// Matches the backend exactly (see AuthController::register /
/// verifyRegister): step 1 creates the account and triggers an SMS OTP;
/// step 3 verifies it and signs the user in. The address itself has no
/// registration-time endpoint on the backend, so it's collected here in
/// the UI and then saved via the normal (authenticated) address endpoint
/// immediately after OTP verification succeeds — see _finishWithAddress().
///
/// Note on OTP delivery: the backend currently sends this OTP via SMS
/// (OneWaySmsService), not OneSignal — OneSignal is used elsewhere in the
/// backend only for the post-verification welcome email. If you want the
/// OTP itself delivered via OneSignal instead, that's a backend change,
/// not something this screen controls.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;
  bool _isSubmitting = false;
  String? _error;

  // Step 1 — personal info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController(); // local number, no leading 0, no country code
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _dob;
  final _step1FormKey = GlobalKey<FormState>();

  // Step 2 — address
  final _labelController = TextEditingController(text: 'Home');
  final _unitNoController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedState;
  final _countryController = TextEditingController(text: 'Malaysia');
  LatLng? _pinnedLocation;
  final _step2FormKey = GlobalKey<FormState>();

  // Step 3 — OTP
  final _otpController = TextEditingController();
  int? _userId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
    _labelController.dispose();
    _unitNoController.dispose();
    _countryController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Local mobile input -> the `60XXXXXXXXX` shape the backend requires
  /// (regex `^60\d{9,10}$`). Strips a leading 0 if the person typed the
  /// number the way they normally would (e.g. 012-3456789 -> 60123456789).
  String get _normalizedMobile {
    var digits = _mobileController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '60$digits';
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialPosition: _pinnedLocation)),
    );
    if (result != null) {
      setState(() => _pinnedLocation = result);
    }
  }

  Future<void> _submitPersonalInfo() async {
    if (!_step1FormKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  /// Account creation (and the OTP SMS it triggers) now happens here, not
  /// on step 1 — so the OTP only gets sent once the person has finished
  /// entering their address and is about to land on the "Verify phone"
  /// step, matching what they'd expect from the step label.
  Future<void> _submitAddress() async {
    if (!_step2FormKey.currentState!.validate()) return;
    if (_pinnedLocation == null) {
      setState(() => _error = 'Please pin your address location on the map.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(authControllerProvider.notifier).register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            mobileNo: _normalizedMobile,
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
            dob: _dob,
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
      // Surface all field-level validation errors (e.g. "email already
      // taken"), not just the first one, so nothing gets hidden.
      final errorsMap = e.errors;
      String? detail;
      if (errorsMap != null && errorsMap.isNotEmpty) {
        final lines = <String>[];
        for (final value in errorsMap.values) {
          if (value is List) {
            lines.addAll(value.map((v) => v.toString()));
          } else if (value != null) {
            lines.add(value.toString());
          }
        }
        if (lines.isNotEmpty) detail = lines.join('\n');
      }
      setState(() => _error = detail ?? e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitOtp() async {
    if (_otpController.text.trim().isEmpty || _userId == null) {
      setState(() => _error = 'Please enter the OTP sent to your phone.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(authControllerProvider.notifier).verifyRegister(
            userId: _userId!,
            otp: _otpController.text.trim(),
          );
      if (!result.status) {
        setState(() => _error = result.message ?? 'Invalid OTP.');
        return;
      }
      // Account is now verified and the token is stored, but auth state
      // is deliberately not "authenticated" yet (see
      // AuthController.verifyRegister's doc comment) — this save runs
      // with a valid token, and the router won't navigate away from this
      // screen out from under it.
      final addressSaved = await _saveCollectedAddress();
      if (!addressSaved && mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Address not saved'),
            content: const Text(
              "Your account is verified, but we couldn't save your address "
              'automatically. You can add it from My Addresses.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
      // Now sign the user in — the router sends them to /customer/home.
      ref.read(authControllerProvider.notifier).activateSession(result.user);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Returns true on success. Errors are not silently swallowed anymore —
  /// the caller shows the person a message if this comes back false, since
  /// finding this out later on My Addresses (with no address there and no
  /// explanation why) was confusing.
  Future<bool> _saveCollectedAddress() async {
    try {
      await ref.read(customerRepositoryProvider).saveAddress(
            Address(
              id: 0,
              unitNo: _unitNoController.text.trim().isEmpty ? null : _unitNoController.text.trim(),
              addressLine1: _addressLine1Controller.text.trim(),
              addressLine2: _addressLine2Controller.text.trim().isEmpty
                  ? null
                  : _addressLine2Controller.text.trim(),
              city: _cityController.text.trim(),
              postcode: _postcodeController.text.trim(),
              stateName: _selectedState ?? '',
              countryName: _countryController.text.trim(),
              latitude: _pinnedLocation!.latitude,
              longitude: _pinnedLocation!.longitude,
              addressTitle: _labelController.text.trim().isEmpty ? 'Home' : _labelController.text.trim(),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _resendOtp() async {
    final result =
        await ref.read(authControllerProvider.notifier).resendOtp(_emailController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Stepper(
        currentStep: _step,
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              FilledButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_step == 2 ? 'Verify & finish' : 'Next'),
              ),
              if (_step > 0 && _step < 2) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ],
          ),
        ),
        onStepContinue: () {
          switch (_step) {
            case 0:
              _submitPersonalInfo();
              break;
            case 1:
              _submitAddress();
              break;
            case 2:
              _submitOtp();
              break;
          }
        },
        onStepCancel: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
        steps: [
          Step(
            title: const Text('Your details'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _step1FormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile phone',
                      prefixText: '+60 ',
                      helperText: 'e.g. 12-3456789 (without the leading 0)',
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 9) return 'Enter a valid mobile number';
                      return null;
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_dob == null
                        ? 'Date of birth'
                        : 'DOB: ${_dob!.toLocal().toString().split(' ').first}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _dob = picked);
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'At least 8 characters' : null,
                  ),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                    validator: (v) => (v != _passwordController.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                  if (_error != null && _step == 0) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Address'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _step2FormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _labelController,
                    decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)'),
                  ),
                  TextFormField(
                    controller: _unitNoController,
                    decoration: const InputDecoration(labelText: 'Unit no.'),
                  ),
                  TextFormField(
                    controller: _addressLine1Controller,
                    decoration: const InputDecoration(labelText: 'Address line 1 *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _addressLine2Controller,
                    decoration: const InputDecoration(labelText: 'Address line 2'),
                  ),
                  TextFormField(
                    controller: _postcodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Postcode *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  Builder(
                    builder: (context) {
                      final statesAsync = ref.watch(statesProvider);
                      return statesAsync.when(
                        data: (states) => DropdownButtonFormField<String>(
                          value: _selectedState,
                          decoration: const InputDecoration(labelText: 'State *'),
                          items: states
                              .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedState = v),
                          validator: (v) => (v == null) ? 'Required' : null,
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        error: (e, _) => Text('Could not load states: $e'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(_pinnedLocation == null
                        ? 'Pin address on map'
                        : 'Location pinned ✓ (tap to adjust)'),
                  ),
                  if (_error != null && _step == 1) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Verify phone'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We sent a code to +60 ${_mobileController.text.trim()}.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OTP code'),
                ),
                TextButton(onPressed: _resendOtp, child: const Text('Resend OTP')),
                if (_error != null && _step == 2) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
