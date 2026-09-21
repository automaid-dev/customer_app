import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/address_model.dart';

/// Shows the full address text plus a small read-only map pin — used
/// wherever a saved address is selected from a dropdown (Purchase Bag,
/// New Booking's Schedule step, Subscription), since a label like "Home"
/// alone isn't enough for a customer to recognize which saved address
/// they're about to use.
class AddressPreviewCard extends StatelessWidget {
  const AddressPreviewCard({super.key, required this.address});
  final Address address;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: IgnorePointer(
              // Read-only preview — just shows where the pin is, not for
              // interacting with (picking a different address happens via
              // the dropdown above, or My Addresses to fix the pin itself).
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(address.latitude, address.longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_address'),
                    position: LatLng(address.latitude, address.longitude),
                  ),
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                liteModeEnabled: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(address.fullAddressText, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
