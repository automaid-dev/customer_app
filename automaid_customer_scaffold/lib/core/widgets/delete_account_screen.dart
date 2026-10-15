import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../auth/auth_providers.dart';

/// Profile → Delete account. Required by the App Store (guideline
/// 5.1.1(v)) for any app that lets people create an account.
/// Server side: POST /profile/delete-account (AccountDeletionService).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _reason = TextEditingController();
  bool _understood = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text('This cannot be undone. You will be logged out immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(
            password: _password.text,
            reason: _reason.text,
          );
      // Signed out now — the router is already heading to the login
      // screen; just clear anything pushed on top of it.
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
      if (messenger.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.grey[700], height: 1.5);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Deleting your account is permanent.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('What will be deleted:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('''• Your profile, phone number, email and saved addresses
• Any active subscription — it is cancelled and your card will not be charged again
• Your login — you will be signed out on all devices''', style: muted),
          const SizedBox(height: 12),
          const Text('What we keep:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('• Your bookings, payments and receipts are kept for our financial records, without your personal details.', style: muted),
          const SizedBox(height: 12),
          Text(
            'If you have anything still in progress, please let it finish first. '
            'You can sign up again later with the same email or phone number.',
            style: muted,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason for leaving (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Enter your password to confirm',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          CheckboxListTile(
            value: _understood,
            onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I understand my account will be permanently deleted.'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_understood && !_busy) ? _delete : null,
            style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}
