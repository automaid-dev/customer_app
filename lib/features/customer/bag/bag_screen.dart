import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';

class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasedAsync = ref.watch(purchasedBagsProvider);
    final assignedAsync = ref.watch(assignedBagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bags')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan bag'),
        onPressed: () => _openScanner(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(purchasedBagsProvider);
          ref.invalidate(assignedBagsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Purchased bags', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            purchasedAsync.when(
              data: (bags) => bags.isEmpty
                  ? const Text('No bags purchased yet.')
                  : Column(children: bags.map((b) => _BagCard(bag: b)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load: $e'),
            ),
            const SizedBox(height: 24),
            Text('Assigned QR codes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            assignedAsync.when(
              data: (bags) => bags.isEmpty
                  ? const Text('No bags scanned yet — scan a bag to assign its QR code.')
                  : Column(children: bags.map((b) => _QrCard(qrcode: b)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner(BuildContext context, WidgetRef ref) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (code == null) return;
    if (!context.mounted) return;

    try {
      await ref.read(customerRepositoryProvider).bagScan(qrcode: code, type: 'scan');
      ref.invalidate(assignedBagsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bag successfully scanned.')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _BagCard extends StatelessWidget {
  const _BagCard({required this.bag});
  final Map<String, dynamic> bag;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shopping_bag_outlined),
        title: Text('Bag #${bag['id']}'),
        subtitle: Text('Status: ${bag['status'] ?? '-'} · Qty: ${bag['quantity'] ?? 1}'),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.qrcode});
  final Map<String, dynamic> qrcode;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.qr_code_2),
        title: Text(qrcode['series_no']?.toString() ?? '-'),
        subtitle: Text('Status: ${qrcode['status'] ?? '-'}'),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan bag QR code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final barcode = capture.barcodes.firstOrNull;
          final value = barcode?.rawValue;
          if (value != null) {
            _handled = true;
            Navigator.of(context).pop(value);
          }
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
