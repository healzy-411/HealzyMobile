import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/pharmacy_map_view.dart';
import '../services/api_service.dart';
import '../Models/pharmacy_model.dart';
import '../Models/duty_pharmacy_model.dart';
import 'pharmacy_detail_page.dart';
import 'duty_pharmacies_page.dart';
import '../widgets/healzy_bottom_nav.dart';

class HomeMapFullscreenPage extends StatefulWidget {
  final List<PharmacyMarkerData>? registeredMarkers;
  final List<PharmacyMarkerData>? dutyMarkers;
  final double? userLat;
  final double? userLng;
  final ActiveOrderRoute? activeRoute;
  final bool simpleStyle;
  final ValueChanged<bool>? onStyleChanged;

  const HomeMapFullscreenPage({
    super.key,
    this.registeredMarkers,
    this.dutyMarkers,
    this.userLat,
    this.userLng,
    this.activeRoute,
    this.simpleStyle = true,
    this.onStyleChanged,
  });

  @override
  State<HomeMapFullscreenPage> createState() => _HomeMapFullscreenPageState();
}

class _HomeMapFullscreenPageState extends State<HomeMapFullscreenPage> {
  int _filter = 0; // 0=Tumu, 1=Nobetci, 2=Kayitli

  final _apiService = ApiService();
  List<PharmacyMarkerData> _registered = [];
  List<PharmacyMarkerData> _duty = [];
  double? _userLat;
  double? _userLng;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _registered = widget.registeredMarkers ?? const [];
    _duty = widget.dutyMarkers ?? const [];
    _userLat = widget.userLat;
    _userLng = widget.userLng;

    if (widget.registeredMarkers == null && widget.dutyMarkers == null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(timeLimit: Duration(seconds: 5)),
        );
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      } catch (_) {}

      final results = await Future.wait([
        _apiService.getPharmacies(),
        _apiService.getDutyPharmacies(),
      ]);

      final pharmacies = results[0] as List<Pharmacy>;
      final dutyPharmacies = results[1] as List<DutyPharmacyModel>;

      if (!mounted) return;

      final registeredNames =
          pharmacies.map((p) => p.name.trim().toLowerCase()).toSet();

      setState(() {
        _registered = pharmacies
            .where((p) => p.latitude != 0 || p.longitude != 0)
            .map((p) {
              final isBoth = p.isOnDuty;
              return PharmacyMarkerData(
                name: p.name,
                address: "${p.district} / ${p.address}",
                phone: p.phone,
                latitude: p.latitude,
                longitude: p.longitude,
                distanceBadge: isBoth ? "Kayitli + Nobetci" : "Kayitli",
                badgeColor: isBoth ? Colors.purple : const Color(0xFF00B894),
                markerColor: isBoth ? Colors.purple : const Color(0xFF00B894),
                rating: p.averageRating > 0 ? p.averageRating : null,
                reviewCount: p.reviewCount > 0 ? p.reviewCount : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PharmacyDetailPage(pharmacyId: p.id),
                    ),
                  );
                },
              );
            })
            .toList();

        _duty = dutyPharmacies
            .where((d) =>
                d.latitude != null &&
                d.longitude != null &&
                (d.latitude != 0 || d.longitude != 0))
            .where((d) => !registeredNames
                .contains(d.pharmacyName.trim().toLowerCase()))
            .map((d) => PharmacyMarkerData(
                  name: d.pharmacyName,
                  address: "${d.district} / ${d.address}",
                  phone: d.phone ?? "",
                  latitude: d.latitude!,
                  longitude: d.longitude!,
                  distanceBadge: "Nobetci",
                  badgeColor: Colors.red,
                  markerColor: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DutyPharmaciesPage(),
                      ),
                    );
                  },
                ))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PharmacyMarkerData> get _filtered {
    switch (_filter) {
      case 1:
        final both = _registered
            .where((m) => m.distanceBadge?.contains("Nobetci") == true)
            .toList();
        return [..._duty, ...both];
      case 2:
        return _registered;
      default:
        return [..._duty, ..._registered];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.map),
      appBar: AppBar(
        title: const Text("Harita"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Row(
              children: [
                _chip("Tumu", 0),
                const SizedBox(width: 8),
                _chip("Nobetci", 1),
                const SizedBox(width: 8),
                _chip("Kayitli", 2),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("Nobetci", style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 10),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00B894), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("Kayitli", style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading && _filtered.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("Gosterilecek eczane yok", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : PharmacyMapView(
                  pharmacies: _filtered,
                  userLat: _userLat,
                  userLng: _userLng,
                  activeRoute: widget.activeRoute,
                  simpleStyle: widget.simpleStyle,
                  onStyleChanged: widget.onStyleChanged,
                ),
    );
  }

  Widget _chip(String label, int value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white70),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF102E4A) : Colors.white,
          ),
        ),
      ),
    );
  }
}
