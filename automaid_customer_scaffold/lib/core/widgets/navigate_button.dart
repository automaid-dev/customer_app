import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's default maps app (Google Maps on Android, Apple
/// Maps on iOS — url_launcher picks whichever is installed) with
/// turn-by-turn directions to the given coordinates. Used by the rider
/// app to navigate to a customer's pickup address or a merchant's
/// outlet, without needing to build any map UI ourselves.
class NavigateButton extends StatelessWidget {
  const NavigateButton({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label = 'Navigate',
    this.destinationName,
  });

  /// Coordinates as strings, matching how the API returns them —
  /// nullable so a card can pass through the raw value and this widget
  /// stays disabled (and clearly so) if a location was never geocoded.
  final String? latitude;
  final String? longitude;
  final String label;
  final String? destinationName;

  bool get _hasLocation =>
      latitude != null && longitude != null && latitude!.isNotEmpty && longitude!.isNotEmpty;

  Future<void> _open(BuildContext context) async {
    final lat = latitude;
    final lng = longitude;
    // Google Maps' universal directions URL — works whether or not
    // Google Maps is installed (falls back to opening in a browser),
    // and on iOS still hands off to Apple Maps if that's preferred,
    // since it's a normal https link rather than a maps:// scheme.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open a maps app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _hasLocation
        ? (destinationName != null ? '$label to $destinationName' : label)
        : 'Location unavailable';
    return OutlinedButton.icon(
      onPressed: _hasLocation ? () => _open(context) : null,
      icon: const Icon(Icons.directions_outlined, size: 18),
      label: Text(buttonLabel),
    );
  }
}
