import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../Models/duty_pharmacy_model.dart';
import '../widgets/pharmacy_map_view.dart';

class DutyPharmaciesPage extends StatefulWidget {
  const DutyPharmaciesPage({super.key});

  @override
  State<DutyPharmaciesPage> createState() => _DutyPharmaciesPageState();
}

class _DutyPharmaciesPageState extends State<DutyPharmaciesPage> {
  final ApiService apiService = ApiService();

  late Future<List<DutyPharmacyModel>> futureDuty;

  List<DutyPharmacyModel> allPharmacies = [];
  List<DutyPharmacyModel> filteredPharmacies = [];

  String? selectedDistrict;

  // ===== View Mode =====
  bool _showMap = false;

  // ===== Location State =====
  bool _locLoading = false;
  String? _locError;
  Position? _currentPos;

  @override
  void initState() {
    super.initState();
    futureDuty = apiService.getDutyPharmacies();

    // Sayfa açılınca izin + konum al
    _initLocationFlow();
  }

  Future<void> _initLocationFlow() async {
    setState(() {
      _locLoading = true;
      _locError = null;
    });

    try {
      final permResult = await _ensureLocationPermission();
      if (!permResult.ok) {
        if (!mounted) return;
        setState(() {
          _currentPos = null;
          _locLoading = false;
          _locError = permResult.message; // ✅ UI’da göster
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPos = pos;
        _locLoading = false;
        _locError = null;
        // Konum alındıysa listeyi mesafeye göre sırala
        _sortByDistance(filteredPharmacies);
        _sortByDistance(allPharmacies);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locError = e.toString().replaceFirst('Exception: ', '');
        _locLoading = false;
        _currentPos = null;
      });
    }
  }

  // küçük helper result modeli
  _PermResult _permFail(String msg) => _PermResult(false, msg);
  _PermResult _permOk() => const _PermResult(true, null);

  Future<_PermResult> _ensureLocationPermission() async {
    // Konum servisi açık mı?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _permFail(
        "Konum servisleri kapalı. Simulator'da Features > Location'dan aç.",
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return _permFail("Konum izni reddedildi.");
    }

    if (permission == LocationPermission.deniedForever) {
      return _permFail(
        "Konum izni kalıcı reddedildi. Ayarlar > Privacy > Location’dan açmalısın.",
      );
    }

    return _permOk();
  }

  // ================= DISTRICT LIST =================
  List<String> _getDistricts() {
    return allPharmacies.map((e) => e.district).toSet().toList()..sort();
  }

  // ================= MESAFE HESAPLAMA =================
  double? _distanceKm(DutyPharmacyModel p) {
    if (_currentPos == null || p.latitude == null || p.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      _currentPos!.latitude,
      _currentPos!.longitude,
      p.latitude!,
      p.longitude!,
    );
    return meters / 1000.0;
  }

  void _sortByDistance(List<DutyPharmacyModel> list) {
    if (_currentPos == null) return;
    list.sort((a, b) {
      final da = _distanceKm(a);
      final db = _distanceKm(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
  }

  // ================= APPLY FILTER =================
  void _applyDistrictFilter() {
    if (selectedDistrict == null) {
      filteredPharmacies = List.from(allPharmacies);
    } else {
      filteredPharmacies =
          allPharmacies.where((p) => p.district == selectedDistrict).toList();
    }
    _sortByDistance(filteredPharmacies);
  }
  Color _distanceBadgeColor(double km) {
    if (km < 2) return const Color(0xFF00A79D);   // yakin - yesil
    if (km < 5) return Colors.orange;              // orta
    return Colors.redAccent;                       // uzak
  }

  Future<void> _openAppleMapsDirections(DutyPharmacyModel p) async {
  final fullAddress =
      "${p.pharmacyName}, ${p.address}";

  final encoded = Uri.encodeComponent(fullAddress);

  final uri = Uri.parse("http://maps.apple.com/?q=$encoded");

  debugPrint("APPLE_MAPS_URI => $uri");

  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!ok) {
    throw Exception("Apple Maps açılamadı.");
  }
}
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 🔥 GERİ BUTONLU APPBAR
      appBar: AppBar(
        backgroundColor: Colors.grey[400],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // 👈 ANA EKRANA DÖNER
          },
        ),
        title: const Text(
          "Nöbetçi Eczaneler",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showMap ? Icons.list : Icons.map,
              color: Colors.white,
            ),
            tooltip: _showMap ? "Liste gorunumu" : "Harita gorunumu",
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: "Konumu yenile",
            icon: _locLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: Colors.white),
            onPressed: _locLoading ? null : _initLocationFlow,
          ),
        ],
      ),

      body: SafeArea(
        child: FutureBuilder<List<DutyPharmacyModel>>(
          future: futureDuty,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            }

            allPharmacies = snapshot.data ?? [];

            if (filteredPharmacies.isEmpty) {
              filteredPharmacies = List.from(allPharmacies);
              _sortByDistance(filteredPharmacies);
            }

            return Column(
              children: [
                // Konum uyarısı (theme bozmadan küçük bilgi)
                if (_locError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      _locError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                // ✅ FILTER (DATA GELDİKTEN SONRA)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDistrict,
                          hint: const Text("İlçe seç"),
                          items: _getDistricts()
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedDistrict = val;
                              _applyDistrictFilter();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            selectedDistrict = null;
                            filteredPharmacies = allPharmacies;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // ===== HARITA / LISTE =====
                Expanded(
                  child: _showMap
                      ? PharmacyMapView(
                          pharmacies: filteredPharmacies
                              .where((p) =>
                                  p.latitude != null && p.longitude != null)
                              .map((p) {
                            final distKm = _distanceKm(p);
                            String? badge;
                            Color? badgeColor;
                            if (distKm != null) {
                              badge = distKm < 1
                                  ? "${(distKm * 1000).toInt()} m"
                                  : "${distKm.toStringAsFixed(1)} km";
                              badgeColor = _distanceBadgeColor(distKm);
                            }
                            return PharmacyMarkerData(
                              name: p.pharmacyName,
                              address: "${p.district} / ${p.address}",
                              phone: p.phone,
                              latitude: p.latitude!,
                              longitude: p.longitude!,
                              distanceBadge: badge,
                              badgeColor: badgeColor,
                            );
                          }).toList(),
                          userLat: _currentPos?.latitude,
                          userLng: _currentPos?.longitude,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPharmacies.length,
                          itemBuilder: (context, index) {
                            return _buildDutyCard(filteredPharmacies[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= CARD =================
  Widget _buildDutyCard(DutyPharmacyModel p) {
    final distKm = _distanceKm(p);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.pharmacyName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (distKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _distanceBadgeColor(distKm),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 12, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        distKm < 1
                            ? "${(distKm * 1000).toInt()} m"
                            : "${distKm.toStringAsFixed(1)} km",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${p.district} / ${p.city}",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                p.phone,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Yol tarifi al butonu
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _openAppleMapsDirections(p);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text("Yol tarifi al"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// helper result
class _PermResult {
  final bool ok;
  final String? message;
  const _PermResult(this.ok, this.message);
}