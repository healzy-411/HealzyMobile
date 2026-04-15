import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  final VoidCallback? onTap;
  final double? rating;
  final int? reviewCount;

  const PharmacyMarkerData({
    required this.name,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.distanceBadge,
    this.badgeColor,
    this.markerColor,
    this.onTap,
    this.rating,
    this.reviewCount,
  });
}

class ActiveOrderRoute {
  final double pharmacyLat;
  final double pharmacyLng;
  final double deliveryLat;
  final double deliveryLng;
  final String status;

  const ActiveOrderRoute({
    required this.pharmacyLat,
    required this.pharmacyLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.status,
  });
}

class PharmacyMapView extends StatefulWidget {
  final List<PharmacyMarkerData> pharmacies;
  final double? userLat;
  final double? userLng;
  final ActiveOrderRoute? activeRoute;
  final bool showControls;
  final bool simpleStyle;
  final ValueChanged<bool>? onStyleChanged;

  const PharmacyMapView({
    super.key,
    required this.pharmacies,
    this.userLat,
    this.userLng,
    this.activeRoute,
    this.showControls = true,
    this.simpleStyle = false,
    this.onStyleChanged,
  });

  @override
  State<PharmacyMapView> createState() => _PharmacyMapViewState();
}

class _PharmacyMapViewState extends State<PharmacyMapView> {
  final MapController _mapController = MapController();
  int? _selectedIndex;

  // OSRM rota cache
  List<LatLng>? _routePoints;
  String? _lastRouteKey;

  // Harita stili toggle
  late bool _simpleStyle;

  LatLng get _defaultCenter {
    if (widget.userLat != null && widget.userLng != null) {
      return LatLng(widget.userLat!, widget.userLng!);
    }
    if (widget.pharmacies.isNotEmpty) {
      final first = widget.pharmacies.first;
      return LatLng(first.latitude, first.longitude);
    }
    return const LatLng(35.185, 33.382);
  }

  @override
  void didUpdateWidget(covariant PharmacyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.simpleStyle != oldWidget.simpleStyle) {
      _simpleStyle = widget.simpleStyle;
    }
    if (widget.activeRoute != null) {
      final key = "${widget.activeRoute!.pharmacyLat},${widget.activeRoute!.pharmacyLng}"
          "-${widget.activeRoute!.deliveryLat},${widget.activeRoute!.deliveryLng}";
      if (key != _lastRouteKey) {
        _fetchRoute(widget.activeRoute!);
      }
    } else {
      _routePoints = null;
      _lastRouteKey = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _simpleStyle = widget.simpleStyle;
    if (widget.activeRoute != null) {
      _fetchRoute(widget.activeRoute!);
    }
  }

  Future<void> _fetchRoute(ActiveOrderRoute route) async {
    final key = "${route.pharmacyLat},${route.pharmacyLng}"
        "-${route.deliveryLat},${route.deliveryLng}";
    _lastRouteKey = key;

    try {
      // OSRM public API (ucretsiz, kayit gerektirmez)
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${route.pharmacyLng},${route.pharmacyLat};'
        '${route.deliveryLng},${route.deliveryLat}'
        '?overview=full&geometries=geojson',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coords = data['routes']?[0]?['geometry']?['coordinates'] as List?;
        if (coords != null && mounted && _lastRouteKey == key) {
          setState(() {
            _routePoints = coords
                .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          });
        }
      }
    } catch (_) {
      // OSRM basarisiz olursa duz cizgi fallback
    }
  }

  void _centerOnUser() {
    if (widget.userLat != null && widget.userLng != null) {
      _mapController.move(
        LatLng(widget.userLat!, widget.userLng!),
        14.0,
      );
    }
  }

  void _zoomIn() {
    final zoom = _mapController.camera.zoom + 1;
    _mapController.move(_mapController.camera.center, zoom);
  }

  void _zoomOut() {
    final zoom = _mapController.camera.zoom - 1;
    _mapController.move(_mapController.camera.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.activeRoute;
    final hasRoute = route != null;
    final markers = <Marker>[];
    final polylines = <Polyline>[];

    if (hasRoute) {
      final pharmacyPoint = LatLng(route.pharmacyLat, route.pharmacyLng);
      final deliveryPoint = LatLng(route.deliveryLat, route.deliveryLng);

      // Rota cizgisi (OSRM varsa yol tarifi, yoksa duz cizgi)
      final routeLinePoints = _routePoints ?? [pharmacyPoint, deliveryPoint];
      final isPending = route.status == "Pending" || route.status == "Preparing";

      polylines.add(
        Polyline(
          points: routeLinePoints,
          color: _routeColor(route.status),
          strokeWidth: 5.0,
          pattern: isPending
              ? const StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
      );

      // Eczane marker
      markers.add(
        Marker(
          point: pharmacyPoint,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _routeColor(route.status), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _routeColor(route.status).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: _routeColor(route.status),
              size: 24,
            ),
          ),
        ),
      );

      // Teslimat adresi marker
      markers.add(
        Marker(
          point: deliveryPoint,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.deepPurple, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.home,
              color: Colors.deepPurple,
              size: 24,
            ),
          ),
        ),
      );
    } else {
      // Normal mod: tum eczane marker'lari
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
    }

    // Kullanici konumu marker (her zaman goster)
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

    // Aktif rota varsa haritayi rotaya ortala
    final center = hasRoute
        ? LatLng(
            (route.pharmacyLat + route.deliveryLat) / 2,
            (route.pharmacyLng + route.deliveryLng) / 2,
          )
        : _defaultCenter;

    final useSimple = _simpleStyle;
    final tileUrl = useSimple
        ? 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    final subdomains = useSimple ? ['a', 'b', 'c', 'd'] : <String>[];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasRoute ? 14.0 : 13.0,
            onTap: (_, _) {
              setState(() => _selectedIndex = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: subdomains,
              userAgentPackageName: 'com.healzy.app',
            ),
            if (polylines.isNotEmpty)
              PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),

        // Popup (sadece normal modda)
        if (!hasRoute &&
            _selectedIndex != null &&
            _selectedIndex! < widget.pharmacies.length)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildPopup(widget.pharmacies[_selectedIndex!]),
          ),

        // Sag ust butonlar: konum + zoom (sadece showControls true ise)
        if (widget.showControls)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                if (widget.userLat != null && widget.userLng != null)
                  _mapButton(
                    heroTag: 'centerOnUser',
                    icon: Icons.my_location,
                    color: Colors.blue,
                    onPressed: _centerOnUser,
                  ),
                if (widget.userLat != null && widget.userLng != null)
                  const SizedBox(height: 8),
                _mapButton(
                  heroTag: 'zoomIn',
                  icon: Icons.add,
                  color: Colors.black87,
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                _mapButton(
                  heroTag: 'zoomOut',
                  icon: Icons.remove,
                  color: Colors.black87,
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 8),
                _mapButton(
                  heroTag: 'toggleStyle',
                  icon: _simpleStyle ? Icons.map_outlined : Icons.layers_outlined,
                  color: _simpleStyle ? Colors.teal : Colors.black87,
                  onPressed: () {
                    setState(() => _simpleStyle = !_simpleStyle);
                    widget.onStyleChanged?.call(_simpleStyle);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mapButton({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: Colors.white,
      onPressed: onPressed,
      child: Icon(icon, color: color),
    );
  }

  Color _routeColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Preparing":
        return Colors.blue;
      case "Ready":
        return Colors.teal;
      case "Dispatched":
        return Colors.green;
      case "Delivered":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _openDirections(PharmacyMarkerData p) async {
    final lat = p.latitude;
    final lng = p.longitude;
    // iOS: Apple Maps, Android: Google Maps
    final Uri url;
    if (Platform.isIOS) {
      url = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    } else {
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildPopup(PharmacyMarkerData p) {
    final isRegistered = p.distanceBadge == "Kayitli";

    return Card(
      elevation: 8,
      color: const Color(0xFF102E4A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baslik + badge
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: p.onTap,
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (p.distanceBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.badgeColor ?? Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p.distanceBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Rating (sadece kayitli eczaneler)
            if (isRegistered && p.rating != null && p.reviewCount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ...List.generate(5, (i) {
                      final starVal = p.rating!;
                      if (i < starVal.floor()) {
                        return const Icon(Icons.star, size: 16, color: Colors.amber);
                      } else if (i < starVal.ceil() && starVal % 1 >= 0.5) {
                        return const Icon(Icons.star_half, size: 16, color: Colors.amber);
                      }
                      return const Icon(Icons.star_border, size: 16, color: Colors.amber);
                    }),
                    const SizedBox(width: 6),
                    Text(
                      "${p.rating!.toStringAsFixed(1)} (${p.reviewCount} yorum)",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Adres
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.address,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Telefon (tiklanabilir, koyu yeşil)
            GestureDetector(
              onTap: p.phone.isNotEmpty ? () => _callPhone(p.phone) : null,
              child: Row(
                children: [
                  Icon(Icons.phone,
                      size: 15,
                      color: p.phone.isNotEmpty
                          ? const Color(0xFF00B894)
                          : Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    p.phone.isNotEmpty ? p.phone : "Telefon yok",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.phone.isNotEmpty
                          ? const Color(0xFF00B894)
                          : Colors.white54,
                      decoration: p.phone.isNotEmpty
                          ? TextDecoration.underline
                          : null,
                      decorationColor: const Color(0xFF00B894),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Yol Tarifi (büyük buton)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => _openDirections(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "Yol Tarifi",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Detay butonu (kayitli eczaneler)
            if (isRegistered && p.onTap != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: p.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "Eczane Detaylari",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
