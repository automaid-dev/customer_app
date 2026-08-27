import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../providers/customer_providers.dart';

/// Chat-style thread for a single complaint — the original issue (plus
/// its photo, if any) shown as the first message, followed by every
/// reply in order. Replies don't carry an explicit "who sent this"
/// flag on the backend, so ownership is inferred by comparing each
/// reply's `created_by` to the current customer's own id: their own
/// messages align right, anything else (i.e. admin/staff) aligns left.
class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});
  final int ticketId;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends ConsumerState<SupportTicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  String? _error;
  final _replyController = TextEditingController();
  bool _isSending = false;

  /// Strips HTML tags and un-escapes the handful of entities the
  /// RichEditor's toolbar can actually produce (bold/italic/link/list) —
  /// good enough for a plain-text chat bubble without pulling in a full
  /// HTML rendering package for what's normally a short reply.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ticket = await ref.read(customerRepositoryProvider).supportTicketDetail(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final updated = await ref.read(customerRepositoryProvider).replySupportTicket(
            ticketId: widget.ticketId,
            description: text,
          );
      _replyController.clear();
      if (!mounted) return;
      setState(() => _ticket = updated);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final ticket = _ticket;
    final order = ticket?['order'] as Map<String, dynamic>?;
    final replies = (ticket?['replies'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final isClosed = ticket?['status']?.toString() == 'closed';

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket?['issue_type']?.toString() ?? 'Complaint'),
        bottom: order != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Order #${order['id']}', style: const TextStyle(fontSize: 12)),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          // The original complaint — always the customer's
                          // own message, so it's always right-aligned.
                          _ChatBubble(
                            isMe: true,
                            text: ticket?['issue']?.toString() ?? '',
                            imageUrl: ticket?['image_url']?.toString(),
                            timestamp: ticket?['created_at']?.toString(),
                          ),
                          for (final reply in replies)
                            _ChatBubble(
                              isMe: reply['created_by'] == myUserId,
                              // Admin replies come from a rich-text
                              // editor on the backend (see the Filament
                              // TicketReply widget), so this can
                              // contain HTML — stripped to plain text
                              // here since this is a simple text
                              // bubble, not an HTML renderer.
                              text: _stripHtml(reply['description']?.toString() ?? ''),
                              title: reply['title']?.toString(),
                              timestamp: reply['created_at']?.toString(),
                            ),
                        ],
                      ),
                    ),
                    if (isClosed)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'This ticket has been closed.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message…',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  minLines: 1,
                                  maxLines: 4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                icon: _isSending
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.send),
                                onPressed: _isSending ? null : _sendReply,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.isMe,
    required this.text,
    this.title,
    this.imageUrl,
    this.timestamp,
  });
  final bool isMe;
  final String text;
  final String? title;
  final String? imageUrl;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.grey.shade200;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Support team', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ),
            if (title != null && title!.isNotEmpty) ...[
              Text(title!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
            ],
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl!, height: 160, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
            ],
            if (text.isNotEmpty) Text(text),
          ],
        ),
      ),
    );
  }
}
