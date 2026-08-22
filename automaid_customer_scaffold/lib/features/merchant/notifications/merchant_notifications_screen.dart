import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/merchant_providers.dart';

/// The merchant's actual notification history — tracking updates for
/// their own jobs (accepted, pickup confirmed, etc.), read from
/// Laravel's own notifications table. Previously the bell icon on the
/// dashboard routed to order/activity history instead, since this
/// screen never existed.
class MerchantNotificationsScreen extends ConsumerStatefulWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  ConsumerState<MerchantNotificationsScreen> createState() => _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState extends ConsumerState<MerchantNotificationsScreen> {
  List<Map<String, dynamic>>? _notifications;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(merchantRepositoryProvider).notifications();
      if (!mounted) return;
      setState(() {
        _notifications = result;
        _loading = false;
      });
      // Mark read after loading, not before — so the unread badge on
      // the dashboard still reflects reality if this fetch fails.
      await ref.read(merchantRepositoryProvider).markNotificationsRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Could not load notifications: $_error'))
              : (_notifications == null || _notifications!.isEmpty)
                  ? const Center(child: Text('No notifications yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _notifications!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = _notifications![i];
                          final data = n['data'] as Map<String, dynamic>? ?? {};
                          final title = data['title']?.toString() ?? 'Update';
                          final message = data['message']?.toString() ?? '';
                          final isUnread = n['read_at'] == null;
                          final createdAt = DateTime.tryParse(n['created_at']?.toString() ?? '');

                          return ListTile(
                            leading: Icon(
                              Icons.notifications,
                              color: isUnread ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            title: Text(
                              title,
                              style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                            ),
                            subtitle: Text(message),
                            trailing: Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 12)),
                          );
                        },
                      ),
                    ),
    );
  }
}
