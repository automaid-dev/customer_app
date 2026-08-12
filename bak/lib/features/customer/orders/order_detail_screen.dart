import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';

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
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
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
