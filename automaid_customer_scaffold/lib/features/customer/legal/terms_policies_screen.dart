import 'package:flutter/material.dart';
import '../../../core/legal_info.dart';

/// Profile → Terms & Policies. Each item opens the published policy page
/// on lbunlimitedwash.com, so policy updates never need an app release.
class TermsPoliciesScreen extends StatelessWidget {
  const TermsPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.privacy_tip_outlined, 'Privacy Policy', 'How we collect, use and protect your data', LegalInfo.privacyPolicyUrl),
      (Icons.description_outlined, 'Terms of Service', 'The terms for using the LB Pickup & Delivery app', LegalInfo.termsOfServiceUrl),
      (Icons.currency_exchange, 'Refund & Cancellation Policy', 'Cancelling bookings and subscriptions, and refunds', LegalInfo.refundPolicyUrl),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Policies')),
      body: ListView(
        children: [
          for (final (icon, title, subtitle, url) in items)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: () => LegalInfo.openUrl(context, url),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Service provided by ${LegalInfo.serviceProvider}.\n'
              'Payments processed by ${LegalInfo.paymentProvider}.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
