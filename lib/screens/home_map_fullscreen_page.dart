import 'package:flutter/material.dart';
import '../widgets/pharmacy_map_view.dart';

class HomeMapFullscreenPage extends StatefulWidget {
  final List<PharmacyMarkerData> registeredMarkers;
  final List<PharmacyMarkerData> dutyMarkers;
  final double? userLat;
  final double? userLng;

  const HomeMapFullscreenPage({
    super.key,
    required this.registeredMarkers,
    required this.dutyMarkers,
    this.userLat,
    this.userLng,
  });

  @override
  State<HomeMapFullscreenPage> createState() => _HomeMapFullscreenPageState();
}

class _HomeMapFullscreenPageState extends State<HomeMapFullscreenPage> {
  int _filter = 0; // 0=Tumu, 1=Nobetci, 2=Kayitli

  List<PharmacyMarkerData> get _filtered {
    switch (_filter) {
      case 1:
        return widget.dutyMarkers;
      case 2:
        return widget.registeredMarkers;
      default:
        return [...widget.dutyMarkers, ...widget.registeredMarkers];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Harita"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
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
                // Legend
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("Nobetci", style: TextStyle(color: Colors.white, fontSize: 11)),
                    const SizedBox(width: 10),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00A79D), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("Kayitli", style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
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
              userLat: widget.userLat,
              userLng: widget.userLng,
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF00A79D) : Colors.white,
          ),
        ),
      ),
    );
  }
}
