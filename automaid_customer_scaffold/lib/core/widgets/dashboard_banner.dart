import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Top-of-dashboard banner matching the requested AEON-app style —
/// gradient background, "Good day, {name}" greeting with the current
/// date/time, a notification bell (with unread badge), and a character
/// mascot image anchored bottom-right, partly overlapping the banner.
/// Shared by customer, rider, and merchant dashboards — each passes its
/// own mascot asset and unread count.
class DashboardBanner extends StatelessWidget {
  const DashboardBanner({
    super.key,
    required this.name,
    required this.mascotAsset,
    required this.onNotificationTap,
    this.unreadCount = 0,
    this.subtitle,
  });

  final String name;
  final String mascotAsset;
  final VoidCallback onNotificationTap;
  final int unreadCount;
  final String? subtitle;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedNow() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final period = now.hour < 12 ? 'AM' : 'PM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '${now.day} ${months[now.month - 1]} ${now.year} · $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, AppColors.blueDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()},',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formattedNow(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onNotificationTap,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Badge(
                        label: Text('$unreadCount'),
                        isLabelVisible: unreadCount > 0,
                        child: const Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Image.asset(mascotAsset, height: 150, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
