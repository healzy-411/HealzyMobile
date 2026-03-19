import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Marker verisi icin ortak model
class PharmacyMarkerData {
  final String name;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String? distanceBadge;
  final Color? badgeColor;
  final Color? markerColor;

  const PharmacyMarkerData({
    required this.name,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.distanceBadge,
    this.badgeColor,
    this.markerColor,
  });
}

class PharmacyMapView extends StatefulWidget {
  final List<PharmacyMarkerData> pharmacies;
  final double? userLat;
  final double? userLng;

  const PharmacyMapView({
    super.key,
    required this.pharmacies,
    this.userLat,
    this.userLng,
  });

  @override
  State<PharmacyMapView> createState() => _PharmacyMapViewState();
}

class _PharmacyMapViewState extends State<PharmacyMapView> {
  final MapController _mapController = MapController();
  int? _selectedIndex;

  LatLng get _defaultCenter {
    // Kullanici konumu varsa onu kullan
    if (widget.userLat != null && widget.userLng != null) {
      return LatLng(widget.userLat!, widget.userLng!);
    }
    // Eczaneler varsa ilkini kullan
    if (widget.pharmacies.isNotEmpty) {
      final first = widget.pharmacies.first;
      return LatLng(first.latitude, first.longitude);
    }
    // Fallback: Kibris merkez
    return const LatLng(35.185, 33.382);
  }

  void _centerOnUser() {
    if (widget.userLat != null && widget.userLng != null) {
      _mapController.move(
        LatLng(widget.userLat!, widget.userLng!),
        14.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // Eczane marker'lari
    for (int i = 0; i < widget.pharmacies.length; i++) {
      final p = widget.pharmacies[i];
      if (p.latitude == 0 && p.longitude == 0) continue;

      markers.add(
        Marker(
          point: LatLng(p.latitude, p.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = _selectedIndex == i ? null : i;
              });
            },
            child: Icon(
              Icons.location_on,
              color: _selectedIndex == i
                  ? Colors.red
                  : (p.markerColor ?? Colors.green[700]),
              size: 36,
            ),
          ),
        ),
      );
    }

    // Kullanici konumu marker
    if (widget.userLat != null && widget.userLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.userLat!, widget.userLng!),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 13.0,
            onTap: (_, _) {
              setState(() => _selectedIndex = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.healzy.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // Popup
        if (_selectedIndex != null &&
            _selectedIndex! < widget.pharmacies.length)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildPopup(widget.pharmacies[_selectedIndex!]),
          ),

        // Kullanici konumuna center butonu
        if (widget.userLat != null && widget.userLng != null)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'centerOnUser',
              backgroundColor: Colors.white,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
      ],
    );
  }

  Widget _buildPopup(PharmacyMarkerData p) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (p.distanceBadge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.badgeColor ?? Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p.distanceBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.address,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(p.phone, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
