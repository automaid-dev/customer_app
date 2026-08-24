import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/setting_model.dart';
import '../providers/customer_providers.dart';
import '../payment/receipt_pdf.dart';

String _receiptTitle(String? orderType) {
  switch (orderType) {
    case 'subscription':
      return 'Subscription Receipt';
    case 'subscription_renewal':
      return 'Subscription Renewal Receipt';
    case 'subscription_update':
      return 'Card Update Receipt';
    case 'subscription_upgrade':
      return 'Subscription Upgrade Receipt';
    default:
      return 'Subscription Receipt';
  }
}

/// Receipt view for any subscription-related order (initial subscribe,
/// renewal, card update, upgrade) — same pattern as BagReceiptScreen,
/// reusing the generic orderDetail endpoint and receipt PDF builder.
class SubscriptionReceiptScreen extends ConsumerStatefulWidget {
  const SubscriptionReceiptScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<SubscriptionReceiptScreen> createState() => _SubscriptionReceiptScreenState();
}

class _SubscriptionReceiptScreenState extends ConsumerState<SubscriptionReceiptScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download / share receipt',
              onPressed: () => _downloadReceipt(_order!),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _ReceiptBody(order: _order!),
    );
  }

  Future<void> _downloadReceipt(Map<String, dynamic> order) async {
    final setting = await ref.read(customerRepositoryProvider).setting();
    final letterhead = ReceiptLetterhead(
      companyName: setting.companyName,
      companyAddress: setting.companyAddress,
      companyPhone: setting.companyPhone,
      companyEmail: setting.companyEmail,
      companyRegistrationNo: setting.companyRegistrationNo,
    );
    final rows = <MapEntry<String, String>>[
      MapEntry('Order #', '${order['id'] ?? '-'}'),
      if (order['series_no'] != null) MapEntry('Reference', order['series_no'].toString()),
      if (order['created_at'] != null)
        MapEntry('Date', order['created_at'].toString().split('T').first),
      MapEntry('Status', '${order['status'] ?? '-'}'),
      MapEntry('Subtotal', 'RM${order['sub_total']?.toString() ?? '0.00'}'),
      MapEntry('Grand total', 'RM${order['grand_total']?.toString() ?? '0.00'}'),
    ];
    final bytes = await buildReceiptPdf(
      title: _receiptTitle(order['order_type']?.toString()),
      rows: rows,
      footerNote: 'Thank you for using Automaid.',
      letterhead: letterhead,
    );
    if (!mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: 'automaid_subscription_receipt_${order['id']}.pdf');
  }
}

class _ReceiptBody extends ConsumerWidget {
  const _ReceiptBody({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingAsync = ref.watch(appSettingProvider);
    final payment = order['payment'] as Map<String, dynamic>?;
    final subTotal = order['sub_total']?.toString() ?? '0.00';
    final grandTotal = order['grand_total']?.toString() ?? '0.00';
    final createdAt = order['created_at']?.toString();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                settingAsync.when(
                  data: (setting) => _Letterhead(setting: setting),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                Icon(Icons.receipt_long, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  _receiptTitle(order['order_type']?.toString()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 32),
                _ReceiptRow(label: 'Order #', value: '${order['id'] ?? '-'}'),
                if (order['series_no'] != null)
                  _ReceiptRow(label: 'Reference', value: order['series_no'].toString()),
                if (createdAt != null) _ReceiptRow(label: 'Date', value: createdAt.split('T').first),
                _ReceiptRow(label: 'Status', value: '${order['status'] ?? '-'}'),
                if (payment != null)
                  _ReceiptRow(label: 'Payment status', value: '${payment['status'] ?? '-'}'),
                const Divider(height: 32),
                _ReceiptRow(label: 'Subtotal', value: 'RM$subTotal'),
                _ReceiptRow(
                  label: 'Grand total',
                  value: 'RM$grandTotal',
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Letterhead extends StatelessWidget {
  const _Letterhead({required this.setting});
  final AppSetting setting;

  @override
  Widget build(BuildContext context) {
    final hasInfo = setting.companyName != null ||
        setting.companyAddress != null ||
        setting.companyPhone != null ||
        setting.companyEmail != null;
    if (!hasInfo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (setting.companyName != null)
            Text(
              setting.companyName!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          if (setting.companyAddress != null)
            Text(
              setting.companyAddress!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          if (setting.companyPhone != null || setting.companyEmail != null)
            Text(
              [setting.companyPhone, setting.companyEmail].where((v) => v != null).join('  ·  '),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style.copyWith(color: emphasize ? null : Colors.grey[700])),
          Text(value, style: style),
        ],
      ),
    );
  }
}
