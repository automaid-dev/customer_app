import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/widgets/confirm_dialog.dart';

/// Shown when the account is authenticated (OTP verified) but the
/// Rider/Merchant entity itself hasn't been approved by admin yet —
/// matches AppUser.isPendingApproval (User.status == 'onboarding').
/// Matches the flow spec's "Waiting admin approval" state exactly.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Thank you for signing up${user?.name != null ? ', ${user!.name}' : ''}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                "We've received your registration. Once your details are "
                "confirmed, you'll receive the training information in your "
                'email. Stay tuned!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () async {
                  final confirmed = await showLogoutConfirmDialog(context);
                  if (confirmed) {
                    ref.read(authControllerProvider.notifier).logout();
                  }
                },
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
