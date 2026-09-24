import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';

/// Shown from the "not covered" dialog when a pickup address falls
/// outside the service area — collects contact details so admin can
/// reach out once coverage expands to that area. Name/email/phone are
/// pre-filled from the customer's own profile, and postcode from
/// whichever address was just found to be uncovered, so the customer
/// can submit with a single tap rather than re-typing anything.
Future<void> showJoinWaitingListSheet(BuildContext context, {String? initialPostcode}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _WaitingListForm(initialPostcode: initialPostcode),
  );
}

class _WaitingListForm extends ConsumerStatefulWidget {
  const _WaitingListForm({this.initialPostcode});
  final String? initialPostcode;

  @override
  ConsumerState<_WaitingListForm> createState() => _WaitingListFormState();
}

class _WaitingListFormState extends ConsumerState<_WaitingListForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postcodeController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _isLoadingProfile = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _postcodeController.text = widget.initialPostcode ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(customerRepositoryProvider).profile();
      if (!mounted) return;
      setState(() {
        _nameController.text = profile['name']?.toString() ?? '';
        _emailController.text = profile['email']?.toString() ?? '';
        _phoneController.text = profile['mobile_no']?.toString() ?? '';
      });
    } catch (_) {
      // Non-fatal — same reasoning as everywhere else this pattern is
      // used: if pre-fill fails (network, etc.), the customer can
      // still fill the form in manually rather than being blocked.
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(customerRepositoryProvider).joinWaitingList(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            postcode: _postcodeController.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _submitted ? _buildSuccess(context) : _buildForm(context),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 12),
        const Text(
          "You're on the list!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          "We'll notify you as soon as we launch in your area.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Join our waiting list', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            "We'll let you know as soon as AutoMaid is available in your area.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone number'),
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _postcodeController,
            decoration: const InputDecoration(labelText: 'Postcode'),
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_isSubmitting || _isLoadingProfile) ? null : _submit,
            child: (_isSubmitting || _isLoadingProfile)
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Join waiting list'),
          ),
        ],
      ),
    );
  }
}
