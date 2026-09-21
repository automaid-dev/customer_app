import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../providers/customer_providers.dart';

/// Preset complaint subjects — kept as a fixed list rather than a
/// free-text field so tickets are consistently categorized for admin
/// (the backend's `issue_type` column just stores whatever string is
/// sent, no server-side enum to keep in sync with).
const _issueTypes = [
  'Report order cancellation',
  'Map issues',
  'Missing or wrong items',
  'Quality/hygiene issues',
  "Driver didn't arrive",
  'Payment charge issues',
  'Promo issues',
  'Other',
];

class NewSupportTicketScreen extends ConsumerStatefulWidget {
  const NewSupportTicketScreen({super.key});

  @override
  ConsumerState<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends ConsumerState<NewSupportTicketScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loadingOrders = true;
  int? _selectedOrderId;
  String? _selectedIssueType;
  final _issueController = TextEditingController();
  File? _photo;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await ref.read(customerRepositoryProvider).supportTicketOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loadingOrders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOrders = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_selectedIssueType == null) {
      setState(() => _error = 'Please choose what your complaint is about.');
      return;
    }
    if (_issueController.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the issue.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(customerRepositoryProvider).createSupportTicket(
            orderId: _selectedOrderId,
            issueType: _selectedIssueType!,
            issue: _issueController.text.trim(),
            imagePath: _photo?.path,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('What order is this about?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _loadingOrders
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<int?>(
                  value: _selectedOrderId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('General inquiry (no specific order)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('General inquiry (no specific order)'),
                    ),
                    for (final order in _orders)
                      DropdownMenuItem<int?>(
                        value: order['id'] as int,
                        child: Text(
                          'Order #${order['id']} — ${order['status'] ?? ''}'.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedOrderId = v),
                ),
          const SizedBox(height: 24),
          Text('What is this complaint about?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _issueTypes)
                ChoiceChip(
                  label: Text(type),
                  selected: _selectedIssueType == type,
                  onSelected: (selected) => setState(() => _selectedIssueType = selected ? type : null),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Describe the issue', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _issueController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Tell us what happened so we can help resolve it quickly.',
            ),
          ),
          const SizedBox(height: 16),
          Text('Attach a photo (optional)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                image: _photo != null
                    ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                    : null,
              ),
              child: _photo == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(height: 4),
                          Text('Tap to attach a photo'),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                        onPressed: () => setState(() => _photo = null),
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit complaint'),
          ),
        ],
      ),
    );
  }
}
