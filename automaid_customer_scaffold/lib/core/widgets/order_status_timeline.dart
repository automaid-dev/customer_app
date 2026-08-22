import 'package:flutter/material.dart';

/// Vertical status timeline for a rider or merchant order — renders
/// whatever `*_order_statuses` entries the backend returns (each with
/// `code`, `is_done`, and a nested `status.desc` description). Mirrors
/// the customer app's own status timeline so all three apps show the
/// same kind of "here's exactly where this order is" view, just using
/// each role's own more granular status codes.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.statuses});
  final List<dynamic> statuses;

  /// Display order for the rider codes — deliberately NOT plain numeric
  /// order. Code 17 "awaiting wash to complete" is a parallel/waiting
  /// state that happens between the rider dropping off at the outlet
  /// (13) and picking the washed items back up (14), even though its
  /// numeric value sorts after everything else including "Order
  /// delivered" (16). Sorting by raw code string previously pushed it
  /// all the way to the end of the timeline, well past steps that
  /// haven't even happened yet — confusing since it's actually one of
  /// the earliest steps to complete. Any code not listed here (i.e.
  /// merchant codes, which are already in a sensible numeric order)
  /// falls back to its own natural position via the index lookup below.
  static const _riderDisplayOrder = ['11', '12', '13', '17', '14', '15', '16'];

  int _sortKey(String code) {
    final i = _riderDisplayOrder.indexOf(code);
    // Not one of the rider codes (e.g. a merchant code) — keep it in
    // its own natural numeric position by using the code itself,
    // offset well past the rider range so it never interleaves.
    return i != -1 ? i : 100 + (int.tryParse(code) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final entries = statuses.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => _sortKey(a['code']?.toString() ?? '').compareTo(_sortKey(b['code']?.toString() ?? '')));

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No status updates yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++)
          _TimelineTile(
            title: (entries[i]['status'] as Map<String, dynamic>?)?['desc']?.toString() ??
                'Status ${entries[i]['code']}',
            isDone: entries[i]['is_done'] == true || entries[i]['is_done'] == 1,
            doneAt: entries[i]['done_at']?.toString(),
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.isDone,
    required this.isLast,
    this.doneAt,
  });
  final String title;
  final bool isDone;
  final bool isLast;
  final String? doneAt;

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Theme.of(context).colorScheme.primary : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: color, size: 20),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDone ? null : Colors.grey)),
                  if (isDone && doneAt != null)
                    Text(doneAt!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
