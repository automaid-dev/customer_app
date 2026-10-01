import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Contact via WhatsApp" buttons built from the order detail API's
/// `contacts` list — each entry is {role, name, whatsapp, link}, where
/// `link` is a ready wa.me URL pre-filled with the order reference.
///
/// The backend decides who appears: the other party (rider / customer /
/// merchant) only while the order is active, admin support always.
/// Renders nothing if the list is empty or missing (e.g. backend not
/// yet updated).
class WhatsAppContacts extends StatelessWidget {
  const WhatsAppContacts({super.key, required this.contacts, this.title = 'Contact via WhatsApp'});

  final List<dynamic>? contacts;
  final String title;

  static const _whatsAppGreen = Color(0xFF25D366);

  static String _roleLabel(String role) {
    switch (role) {
      case 'rider':
        return 'Rider';
      case 'customer':
        return 'Customer';
      case 'merchant':
        return 'Merchant';
      case 'admin':
        return 'Support';
      default:
        return role;
    }
  }

  static IconData _roleIcon(String role) {
    switch (role) {
      case 'rider':
        return Icons.delivery_dining_outlined;
      case 'customer':
        return Icons.person_outline;
      case 'merchant':
        return Icons.storefront_outlined;
      default:
        return Icons.support_agent_outlined;
    }
  }

  Future<void> _open(BuildContext context, String link) async {
    // Plain https wa.me link: opens WhatsApp if installed, otherwise the
    // browser (which offers to install/open it). No <queries> manifest
    // entry needed since we don't call canLaunchUrl first.
    final launched = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (contacts ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((c) => (c['link']?.toString() ?? '').isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(_roleIcon(c['role']?.toString() ?? ''), size: 20, color: Colors.grey[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_roleLabel(c['role']?.toString() ?? ''),
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text(
                        c['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _whatsAppGreen,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _open(context, c['link'].toString()),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
