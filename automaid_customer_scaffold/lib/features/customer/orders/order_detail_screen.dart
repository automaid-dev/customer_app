import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';
import 'booking_receipt_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  int _riderStars = 0;
  int _merchantStars = 0;
  final _riderComment = TextEditingController();
  final _merchantComment = TextEditingController();
  bool _isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _riderComment.dispose();
    _merchantComment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final order = await ref.read(customerRepositoryProvider).orderDetail(widget.orderId);
      setState(() {
        _order = order;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool get _isDelivered => _order?['delivered'] != null;
  bool get _isAlreadyRated => (_order?['delivered']?['is_rated'] ?? 0) == 1;

  Future<void> _submitRating() async {
    setState(() => _isSubmittingRating = true);
    try {
      await ref.read(customerRepositoryProvider).rateOrder(
            orderId: widget.orderId,
            riderStars: _riderStars > 0 ? _riderStars : null,
            riderComment: _riderComment.text.trim().isEmpty ? null : _riderComment.text.trim(),
            merchantStars: _merchantStars > 0 ? _merchantStars : null,
            merchantComment:
                _merchantComment.text.trim().isEmpty ? null : _merchantComment.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'View / download receipt',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookingReceiptScreen(orderId: widget.orderId)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Type: ${_order?['order_type'] ?? '-'}'),
                    Text('Status: ${_order?['status'] ?? '-'}'),
                    Text('Quantity: ${_order?['quantity'] ?? '-'}'),
                    Text('Grand total: RM${_order?['grand_total'] ?? '0.00'}'),
                    const Divider(height: 32),
                    if (_order?['order_type'] == 'booking') ...[
                      const Text('ORDER STATUS', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 8),
                      _StatusTimeline(order: _order!),
                      const Divider(height: 32),
                      _StepPhotosSection(order: _order!),
                      const Divider(height: 32),
                    ],
                    if (_isDelivered && !_isAlreadyRated) _RatingForm(state: this),
                    if (_isAlreadyRated)
                      const Text('You already rated this order — thanks for the feedback!'),
                    if (!_isDelivered)
                      const Text('Rating becomes available once this order is delivered.'),
                  ],
                ),
    );
  }
}

/// The 5-step customer-facing lifecycle (Order.customer_order_statuses,
/// codes 01-05) — matches the flow spec's vertical tracker exactly:
/// Waiting rider for pickup -> Delivering to wash outlet -> Wash in
/// progress -> Delivering to customer -> Order delivered.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});
  final Map<String, dynamic> order;

  static const _steps = [
    ('01', 'Waiting rider for pickup', 'Rider is on the way to pick up your laundry'),
    ('02', 'Delivering to wash outlet', 'Rider is delivering your laundry to the washing outlet'),
    ('03', 'Wash in progress', 'Your laundry is being washed and processed at the facility'),
    ('04', 'Delivering to customer', 'Rider is en route to the drop off location'),
    ('05', 'Order delivered', "Your booking is completed! We'd love to hear your feedback"),
  ];

  @override
  Widget build(BuildContext context) {
    final orderStatus = order['status']?.toString().toLowerCase();
    if (orderStatus == 'cancelled' || orderStatus == 'cancel') {
      return Card(
        color: Colors.red.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Order cancelled', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('This order was cancelled by our team. Contact support if you have questions.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statuses = (order['customer_order_statuses'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    bool isDone(String code) =>
        statuses.any((s) => s['code']?.toString() == code && (s['is_done'] == true || s['is_done'] == 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _steps.length; i++)
          _TimelineTile(
            title: _steps[i].$2,
            subtitle: _steps[i].$3,
            isDone: isDone(_steps[i].$1),
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isLast,
  });
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Theme.of(context).colorScheme.primary : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.circle_outlined,
                color: color,
                size: 22,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? null : Colors.grey)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photos + remarks captured at each handoff (rider pickup, merchant
/// wash start/complete, rider pickup-from-outlet) — see
/// Order::step_photos on the backend.
class _StepPhotosSection extends StatelessWidget {
  const _StepPhotosSection({required this.order});
  final Map<String, dynamic> order;

  static const _labels = {
    '13': 'Picked up / delivered to outlet',
    '23': 'Wash in progress',
    '24': 'Wash completed',
    '14': 'Picked up from outlet',
  };

  @override
  Widget build(BuildContext context) {
    final photos = (order['step_photos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UPDATES', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        for (final photo in photos)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labels[photo['code']?.toString()] ?? 'Update',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (photo['image_url'] != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(photo['image_url'].toString(), height: 160, fit: BoxFit.cover),
                    ),
                  ],
                  if (photo['remark'] != null && photo['remark'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(photo['remark'].toString()),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RatingForm extends StatelessWidget {
  const _RatingForm({required this.state});
  final _OrderDetailScreenState state;

  Widget _starRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        ...List.generate(
          5,
          (i) => IconButton(
            icon: Icon(i < value ? Icons.star : Icons.star_border, color: Colors.amber),
            onPressed: () => onChanged(i + 1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _starRow('Rider', state._riderStars, (v) => setLocalState(() => state._riderStars = v)),
            TextField(
              controller: state._riderComment,
              decoration: const InputDecoration(labelText: 'Comment about rider (optional)'),
            ),
            const SizedBox(height: 12),
            _starRow(
                'Outlet', state._merchantStars, (v) => setLocalState(() => state._merchantStars = v)),
            TextField(
              controller: state._merchantComment,
              decoration: const InputDecoration(labelText: 'Comment about outlet (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state._isSubmittingRating ? null : state._submitRating,
              child: state._isSubmittingRating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit rating'),
            ),
          ],
        );
      },
    );
  }
}
