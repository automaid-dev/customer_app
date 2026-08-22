import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/assign_job_model.dart';
import '../../../core/widgets/order_status_timeline.dart';
import '../../../core/widgets/navigate_button.dart';
import '../providers/rider_providers.dart';

/// Full order detail for a rider's job, with delivery-proof photo upload
/// once the order has reached "delivered" status (code 16) — wraps
/// POST /rider/order/detail and POST /rider/order/delivery/upload.
///
/// [id] + [isComplete] map directly to the backend's dual-purpose lookup:
/// pass an order_id with isComplete=true, or an assign_job id with
/// isComplete=false (matches OrderController::orderDetail exactly).
class RiderOrderDetailScreen extends ConsumerStatefulWidget {
  const RiderOrderDetailScreen({super.key, required this.id, this.isComplete = false});
  final int id;
  final bool isComplete;

  @override
  ConsumerState<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends ConsumerState<RiderOrderDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final List<File> _proofPhotos = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(riderRepositoryProvider);
      final data = await repo.orderDetail(id: widget.id, isComplete: widget.isComplete);
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool get _isDelivered {
    // When isComplete=true, `_data` is the order itself and its status
    // reaches 16 (CUSTOMER_ORDER_DELIVERED) via rider_order_statuses;
    // when false, `_data` is the assign_job whose own code is 16.
    if (widget.isComplete) {
      final statuses = (_data?['rider_order_statuses'] as List<dynamic>? ?? []);
      return statuses.any((s) =>
          (s as Map<String, dynamic>)['code'] == RiderStatusCode.orderDelivered &&
          s['is_done'] == true);
    }
    return _data?['code'] == RiderStatusCode.orderDelivered;
  }

  /// The order object regardless of which response shape `_data` is —
  /// itself directly when isComplete=true, or nested under 'order' when
  /// it's an assign_job (isComplete=false).
  Map<String, dynamic>? get _order =>
      widget.isComplete ? _data : _data?['order'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _pickupLocation =>
      (_order?['booking'] as Map<String, dynamic>?)?['pickup_location'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _booking => _order?['booking'] as Map<String, dynamic>?;

  String? get _pickupPhotoUrl => _booking?['pickup_photo_url']?.toString();
  String? get _pickupNote => _booking?['pickup_note']?.toString();

  Map<String, dynamic>? get _merchant => _order?['merchant'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _merchantUser => _merchant?['user'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _outlet {
    final merchantProfile = _merchantUser?['merchant'] as Map<String, dynamic>?;
    return merchantProfile?['outlet'] as Map<String, dynamic>?;
  }

  /// The merchant's location for navigation — prefers the outlet's own
  /// geocoded address, but falls back to the merchant user's own
  /// latitude/longitude (the same coordinates the backend's
  /// auto-assign matching relies on, so they're reliably populated)
  /// if the outlet record itself has no coordinates set. Previously
  /// this only ever looked at the outlet, so a merchant whose outlet
  /// address was never geocoded showed no usable navigate button at
  /// all even though a perfectly good location existed one level up.
  Map<String, dynamic>? get _merchantLocation {
    final outlet = _outlet;
    if (outlet != null && outlet['latitude'] != null && outlet['longitude'] != null) {
      return outlet;
    }
    if (_merchantUser != null && _merchantUser!['latitude'] != null && _merchantUser!['longitude'] != null) {
      return _merchantUser;
    }
    return null;
  }

  Widget _buildNavigateButtons() {
    final pickup = _pickupLocation;
    final merchantLocation = _merchantLocation;
    if (pickup == null && merchantLocation == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (pickup != null)
          NavigateButton(
            latitude: pickup['latitude']?.toString(),
            longitude: pickup['longitude']?.toString(),
            label: 'Navigate to customer',
          ),
        if (merchantLocation != null)
          NavigateButton(
            latitude: merchantLocation['latitude']?.toString(),
            longitude: merchantLocation['longitude']?.toString(),
            label: 'Navigate to merchant',
            destinationName: (_outlet?['name'] ?? _merchantUser?['name'])?.toString(),
          ),
      ],
    );
  }

  int get _assignId => widget.isComplete ? (_data?['id'] as int? ?? widget.id) : widget.id;

  Future<void> _pickPhoto() async {
    if (_proofPhotos.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) {
      setState(() => _proofPhotos.add(File(picked.path)));
    }
  }

  Future<void> _uploadProof() async {
    if (_proofPhotos.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final formData = FormData.fromMap({
        'assign_id': _assignId,
        for (var i = 0; i < _proofPhotos.length && i < 3; i++)
          'image${i + 1}': await MultipartFile.fromFile(_proofPhotos[i].path),
      });
      await ref.read(apiClientProvider).post(ApiEndpoints.riderOrderDeliveryUpload, data: formData);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delivery proof uploaded.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Order ID: ${_data?['order_id'] ?? _data?['id'] ?? '-'}'),
                    Text('Status code: ${_data?['code'] ?? '-'}'),
                    const SizedBox(height: 12),
                    // Customer's pickup handoff photo + note — set once
                    // at booking time (e.g. "left at hotel lobby with
                    // reception, ask for Ariff"), shown here for the
                    // whole life of the job rather than tied to any
                    // specific step, since it's relevant from the
                    // moment this job is assigned all the way through
                    // to actually collecting the bag.
                    if (_pickupPhotoUrl != null || (_pickupNote?.isNotEmpty ?? false)) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Where to collect', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              if (_pickupPhotoUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _pickupPhotoUrl!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              if (_pickupNote?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 8),
                                Text(_pickupNote!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildNavigateButtons(),
                    const Divider(height: 32),
                    if (_order?['rider_order_statuses'] != null) ...[
                      Text('Order status', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      OrderStatusTimeline(statuses: _order!['rider_order_statuses'] as List<dynamic>),
                      const Divider(height: 32),
                    ],
                    if (_isDelivered) ...[
                      Text('Delivery proof', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Attach up to 3 photos as proof of delivery.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final photo in _proofPhotos)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(photo, width: 90, height: 90, fit: BoxFit.cover),
                            ),
                          if (_proofPhotos.length < 3)
                            InkWell(
                              onTap: _pickPhoto,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_a_photo_outlined),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isUploading || _proofPhotos.isEmpty ? null : _uploadProof,
                        child: _isUploading
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Upload proof photos'),
                      ),
                    ],
                  ],
                ),
    );
  }
}
