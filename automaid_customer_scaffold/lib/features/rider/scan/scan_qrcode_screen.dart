import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api/api_client.dart';
import '../providers/rider_providers.dart';

/// Wraps POST /rider/scan/qrcode (ScanQrcodeController::scanQrcode).
/// Scanning a bag's QR shows the customer's booking(s) scheduled for
/// today — this is how a rider confirms they've got the right bag at
/// pickup, before tapping "Confirm pickup" back on the home screen.
class ScanQrcodeScreen extends ConsumerStatefulWidget {
  const ScanQrcodeScreen({super.key});

  @override
  ConsumerState<ScanQrcodeScreen> createState() => _ScanQrcodeScreenState();
}

class _ScanQrcodeScreenState extends ConsumerState<ScanQrcodeScreen> {
  bool _handled = false;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>>? _bookings;

  Future<void> _onDetected(String code) async {
    if (_handled) return;
    _handled = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings =
          await ref.read(riderRepositoryProvider).scanQrcode(qrcode: code, type: 'scan');
      setState(() => _bookings = bookings);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scanAgain() {
    setState(() {
      _handled = false;
      _bookings = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan bag QR code')),
      body: _bookings != null || _error != null
          ? _ResultView(
              bookings: _bookings,
              error: _error,
              onScanAgain: _scanAgain,
            )
          : Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) _onDetected(value);
                  },
                ),
                if (_isLoading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.bookings, required this.error, required this.onScanAgain});
  final List<Map<String, dynamic>>? bookings;
  final String? error;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings!.length,
                  itemBuilder: (context, i) {
                    final b = bookings![i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: Text('Booking #${b['id']}'),
                        subtitle: Text(
                          'Pickup: ${b['pickup_date'] ?? '-'} · Bags: ${b['pickup_bag_quantity'] ?? '-'}',
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: onScanAgain, child: const Text('Scan another bag')),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
