import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Result of [showPickupHandoffCapture] — both fields are always
/// non-null/non-empty, since the backend rejects a booking without
/// either one.
class PickupHandoffResult {
  const PickupHandoffResult({required this.photoPath, required this.note});
  final String photoPath;
  final String note;
}

/// Bottom sheet requiring a photo of where the laundry is being left
/// (e.g. a hotel lobby, with reception) plus a short note for the
/// rider — shown once, right before the final booking confirmation.
/// Unlike the rider/merchant apps' handoff-step capture, both the photo
/// AND the note are mandatory here, not just the photo — this is the
/// only chance the rider gets to know what to look for when the
/// customer isn't there in person to hand the bag over directly.
///
/// Returns null only if the person backs out entirely before providing
/// both — there's no way to confirm with just one of the two.
Future<PickupHandoffResult?> showPickupHandoffCapture(BuildContext context) {
  return showModalBottomSheet<PickupHandoffResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _PickupHandoffSheet(),
  );
}

class _PickupHandoffSheet extends StatefulWidget {
  const _PickupHandoffSheet();

  @override
  State<_PickupHandoffSheet> createState() => _PickupHandoffSheetState();
}

class _PickupHandoffSheetState extends State<_PickupHandoffSheet> {
  File? _photo;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  bool get _canConfirm => _photo != null && _noteController.text.trim().isNotEmpty;

  void _confirm() {
    if (!_canConfirm) return; // guarded by the button being disabled too
    Navigator.of(context).pop(
      PickupHandoffResult(photoPath: _photo!.path, note: _noteController.text.trim()),
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
          const Text('Where are you leaving your laundry?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Take a photo and add a note so your rider knows exactly what to look for — '
            'e.g. left at the hotel lobby with reception.',
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
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note for rider',
              hintText: 'e.g. Left at hotel lobby with reception, ask for Ariff',
            ),
            maxLines: 2,
            onChanged: (_) => setState(() {}), // refresh the Confirm button's enabled state
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canConfirm ? _confirm : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
