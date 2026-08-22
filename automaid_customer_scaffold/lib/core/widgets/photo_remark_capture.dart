import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Result of [showPhotoRemarkCapture] — photoPath is always non-null,
/// since a photo is required to confirm any handoff step; remark stays
/// optional.
class PhotoRemarkResult {
  const PhotoRemarkResult({required this.photoPath, this.remark});
  final String photoPath;
  final String? remark;
}

/// Bottom sheet: take a **required** photo + optional remark before
/// confirming a handoff step (pickup, delivered to outlet, wash in
/// progress, wash complete, pickup from outlet, delivery to customer).
/// Shared between the rider and merchant apps rather than duplicated,
/// since the UX is identical.
///
/// Returns null if the person backs out entirely (dismissed sheet
/// without confirming) — otherwise always has a photo attached; there's
/// no way to confirm without one.
Future<PhotoRemarkResult?> showPhotoRemarkCapture(
  BuildContext context, {
  required String title,
  String remarkHint = 'Add a note (optional)',
}) {
  return showModalBottomSheet<PhotoRemarkResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => _PhotoRemarkSheet(title: title, remarkHint: remarkHint),
  );
}

class _PhotoRemarkSheet extends StatefulWidget {
  const _PhotoRemarkSheet({required this.title, required this.remarkHint});
  final String title;
  final String remarkHint;

  @override
  State<_PhotoRemarkSheet> createState() => _PhotoRemarkSheetState();
}

class _PhotoRemarkSheetState extends State<_PhotoRemarkSheet> {
  File? _photo;
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  void _confirm() {
    if (_photo == null) return; // guarded by the button being disabled too
    Navigator.of(context).pop(
      PhotoRemarkResult(
        photoPath: _photo!.path,
        remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'A photo is required to confirm this step.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: _photo == null ? Border.all(color: Colors.red.shade200) : null,
                image: _photo != null
                    ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                    : null,
              ),
              child: _photo == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 32),
                          SizedBox(height: 4),
                          Text('Tap to take a photo'),
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
          const SizedBox(height: 12),
          TextField(
            controller: _remarkController,
            decoration: InputDecoration(labelText: widget.remarkHint),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _photo == null ? null : _confirm,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
