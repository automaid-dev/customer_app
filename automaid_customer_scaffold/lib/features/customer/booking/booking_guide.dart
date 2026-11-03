import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';

/// "Booking Instructions" — the packing steps shown when the customer
/// taps New booking, before they choose Wash & Fold or Dry Cleaning.
///
/// Shown every time until the customer ticks "Don't show this again"
/// (remembered on this device). It can always be reopened from the
/// "How booking works" link in the booking-type sheet.
class BookingGuide {
  BookingGuide._();

  static const _storage = FlutterSecureStorage();
  static const _hiddenKey = 'booking_guide_hidden';

  /// Shows the guide unless the customer turned it off. Returns true when
  /// the booking should continue (guide accepted or skipped), false when
  /// they backed out of it.
  static Future<bool> showIfNeeded(BuildContext context) async {
    String? hidden;
    try {
      hidden = await _storage.read(key: _hiddenKey);
    } catch (_) {
      // Storage unavailable — just show the guide.
    }
    if (hidden == '1') return true;
    if (!context.mounted) return false;
    return show(context);
  }

  /// Always shows the guide (e.g. from "How booking works").
  static Future<bool> show(BuildContext context, {bool fromHelpLink = false}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BookingGuideScreen(fromHelpLink: fromHelpLink),
      ),
    );
    return result == true;
  }

  static Future<void> _setHidden(bool hidden) async {
    try {
      if (hidden) {
        await _storage.write(key: _hiddenKey, value: '1');
      } else {
        await _storage.delete(key: _hiddenKey);
      }
    } catch (_) {}
  }

  static Future<bool> _isHidden() async {
    try {
      return await _storage.read(key: _hiddenKey) == '1';
    } catch (_) {
      return false;
    }
  }
}

class _GuideStep {
  const _GuideStep(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _steps = <_GuideStep>[
  _GuideStep(
    Icons.local_laundry_service_rounded,
    AppColors.blue,
    'Put all clothes inside the laundry bag',
    'Pack your clothes in the laundry bag, making sure everything fits without overstuffing.',
  ),
  _GuideStep(
    Icons.qr_code_2_rounded,
    Color(0xFFE6A700),
    'Write & attach the serial number to your bag',
    'Write the bag\'s serial number on paper and attach it to your bag so it\'s easy to identify.',
  ),
  _GuideStep(
    Icons.location_on_rounded,
    Color(0xFFE53935),
    'Place the laundry bag at the pickup location',
    'Leave the packed bag at your pickup location before the pickup time you choose.',
  ),
  _GuideStep(
    Icons.add_a_photo_rounded,
    Color(0xFF2E7D32),
    'Describe the landmark & upload photos',
    'Tell the rider where the bag is and upload up to 3 photos to help them find it quickly.',
  ),
];

class _BookingGuideScreen extends StatefulWidget {
  const _BookingGuideScreen({required this.fromHelpLink});
  final bool fromHelpLink;

  @override
  State<_BookingGuideScreen> createState() => _BookingGuideScreenState();
}

class _BookingGuideScreenState extends State<_BookingGuideScreen> {
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    BookingGuide._isHidden().then((v) {
      if (mounted) setState(() => _dontShowAgain = v);
    });
  }

  Future<void> _continue() async {
    await BookingGuide._setHidden(_dontShowAgain);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Instructions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PACKING INSTRUCTIONS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Do these before your pickup so the rider can collect your bag smoothly.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < _steps.length; i++) ...[
                    _StepRow(number: i + 1, step: _steps[i]),
                    if (i < _steps.length - 1) const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _dontShowAgain,
                onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                title: const Text("Don't show this again"),
              ),
              FilledButton(
                onPressed: _continue,
                child: Text(widget.fromHelpLink ? 'Got it' : 'Got it, start booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});
  final int number;
  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIllustration(number: number, icon: step.icon, color: step.color),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.25),
              ),
              const SizedBox(height: 4),
              Text(
                step.body,
                style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A soft rounded tile with a large icon and a numbered badge — drawn in
/// code, so no image assets are needed and it stays sharp on any screen.
class _StepIllustration extends StatelessWidget {
  const _StepIllustration({required this.number, required this.icon, required this.color});
  final int number;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.24)],
              ),
            ),
            child: Icon(icon, size: 38, color: color),
          ),
          Positioned(
            top: -6,
            left: -6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
