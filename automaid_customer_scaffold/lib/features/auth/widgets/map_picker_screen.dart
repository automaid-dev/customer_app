import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Fixed-center-pin map picker (the same pattern Grab/Foodpanda use for
/// address confirmation): the marker stays glued to the screen center and
/// the map moves underneath it as the person pans/zooms. "Confirm location"
/// captures whatever the camera's center point is at that moment.
///
/// Returns the picked LatLng via Navigator.pop, or null if the person
/// backs out without confirming.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialPosition});

  /// Where to center the map on open. Defaults to Kuala Lumpur if the
  /// caller doesn't have a better starting point (e.g. no address typed
  /// yet) and device location isn't available/granted.
  final LatLng? initialPosition;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _fallback = LatLng(3.1390, 101.6869); // Kuala Lumpur

  GoogleMapController? _controller;
  LatLng _center = _fallback;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _center = widget.initialPosition!;
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent) _showLocationDisabledMessage();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _showPermissionDeniedMessage();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _center = target);
      _controller?.animateCamera(CameraUpdate.newLatLng(target));
    } catch (_) {
      // Silently fall back to the default/initial position — this is a
      // convenience feature, not a blocker for filling in an address.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationDisabledMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Turn on location services to use your current position.')),
    );
  }

  void _showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location permission denied — you can still pin manually.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin your address'),
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            onPressed: _locating ? null : () => _useCurrentLocation(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (controller) => _controller = controller,
            onCameraMove: (position) => _center = position.target,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Fixed center pin — the map moves, this stays put.
          const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.location_pin, size: 48, color: Colors.red),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: const Text('Confirm this location'),
            ),
          ),
        ],
      ),
    );
  }
}
