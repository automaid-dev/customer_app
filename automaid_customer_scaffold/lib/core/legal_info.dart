import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Company details and policy links shown in the app (Terms & Policies
/// menu, dashboard footer). Single place to update if anything changes.
class LegalInfo {
  LegalInfo._();

  static const privacyPolicyUrl = 'https://lbunlimitedwash.com/policy/privacy_policy.html';
  static const termsOfServiceUrl = 'https://lbunlimitedwash.com/policy/application_tnc.html';
  static const refundPolicyUrl = 'https://lbunlimitedwash.com/policy/refund_cancellation_policy.html';

  static const serviceProvider = 'City Coin Laundry Sdn Bhd (Company No. 910338-D)';
  static const paymentProvider = 'Paynwash Solutions Sdn Bhd (Company No. 1326019H)';
  static const address = '13, Jalan Perindustrian 1B, Desa Aman Puri, 52200 Kuala Lumpur, Malaysia';
  static const supportEmail = 'support@laundrybar.com.my';
  static const hotline = '1-300-82-0018';
  static const hotlineDial = '1300820018';

  /// Opens a policy page in an in-app browser tab (Chrome Custom Tab /
  /// SFSafariViewController), falling back to the external browser.
  static Future<void> openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the page.')));
    }
  }

  static Future<void> emailSupport() => launchUrl(Uri(scheme: 'mailto', path: supportEmail));

  static Future<void> callHotline() => launchUrl(Uri(scheme: 'tel', path: hotlineDial));
}
