import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'register_screen.dart';

/// Shown first when creating an account — logo, welcome message, PDPA
/// notice, and links to the Privacy Notice / General Terms / App T&C.
/// "Continue" pushes the actual multi-step form (RegisterScreen).
///
/// This used to be a header baked directly into the top of
/// RegisterScreen's Stepper, but on shorter-height devices the fixed
/// header ate into the space the Stepper assumed it had, the same
/// class of overflow bug as GettingStartedScreen's hero panel. Splitting
/// this into its own screen removes that constraint entirely — there's
/// no shared layout budget to get wrong.
class RegisterConsentScreen extends StatefulWidget {
  const RegisterConsentScreen({super.key});

  @override
  State<RegisterConsentScreen> createState() => _RegisterConsentScreenState();
}

class _RegisterConsentScreenState extends State<RegisterConsentScreen> {
  late final _privacyNoticeRecognizer = TapGestureRecognizer()
    ..onTap = () => _openPolicyLink('https://lbunlimitedwash.com/policy/privacy_notice.html');
  late final _generalTermsRecognizer = TapGestureRecognizer()
    ..onTap = () => _openPolicyLink('https://lbunlimitedwash.com/policy/general_terms.html');
  late final _applicationTncRecognizer = TapGestureRecognizer()
    ..onTap = () => _openPolicyLink('https://lbunlimitedwash.com/policy/application_tnc.html');

  @override
  void dispose() {
    _privacyNoticeRecognizer.dispose();
    _generalTermsRecognizer.dispose();
    _applicationTncRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openPolicyLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              // Scrollable so the header content itself can never
              // overflow, regardless of device height — the Continue
              // button below stays pinned, not part of the scroll area.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Image.asset('assets/images/laundrybar_logo_transparent.png', height: 90),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to LB Pickup and Delivery App',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your data is protected according to the Personal Data Protection Act 2010',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.security_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                                children: [
                                  const TextSpan(
                                    text: "By continuing, I understand and agree with the LB Pickup "
                                        "and Delivery App's ",
                                  ),
                                  TextSpan(
                                    text: 'Privacy Notice',
                                    style: const TextStyle(color: AppColors.blue, decoration: TextDecoration.underline),
                                    recognizer: _privacyNoticeRecognizer,
                                  ),
                                  const TextSpan(text: ', '),
                                  TextSpan(
                                    text: 'General Terms of use',
                                    style: const TextStyle(color: AppColors.blue, decoration: TextDecoration.underline),
                                    recognizer: _generalTermsRecognizer,
                                  ),
                                  const TextSpan(text: ', and '),
                                  TextSpan(
                                    text: 'Application T&C',
                                    style: const TextStyle(color: AppColors.blue, decoration: TextDecoration.underline),
                                    recognizer: _applicationTncRecognizer,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
