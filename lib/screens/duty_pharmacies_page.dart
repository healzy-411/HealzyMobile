import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../Models/duty_pharmacy_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../widgets/pharmacy_map_view.dart';
import 'pharmacy_detail_page.dart';

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
  final ScrollController _listScrollController = ScrollController();

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

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konum güncellendi"), duration: Duration(seconds: 1)),
      );
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
    list.sort((a, b) {
      // Kayitli eczaneler her zaman en ustte
      if (a.isRegistered && !b.isRegistered) return -1;
      if (!a.isRegistered && b.isRegistered) return 1;

      // Sonra mesafeye gore
      if (_currentPos == null) return 0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? AppColors.darkGradient
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.pearlWarm, AppColors.pearl],
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Nöbetçi Eczaneler"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? "Liste görünümü" : "Harita görünümü",
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
                : const Icon(Icons.my_location),
            onPressed: _locLoading ? null : _initLocationFlow,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return SafeArea(
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
                            final pharmacyIndex = filteredPharmacies.indexOf(p);
                            return PharmacyMarkerData(
                              name: p.pharmacyName,
                              address: "${p.district} / ${p.address}",
                              phone: p.phone,
                              latitude: p.latitude!,
                              longitude: p.longitude!,
                              distanceBadge: badge,
                              badgeColor: badgeColor,
                              markerColor: p.isRegistered ? Colors.purple : Colors.red,
                              onTap: () {
                                setState(() => _showMap = false);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_listScrollController.hasClients) {
                                    _listScrollController.animateTo(
                                      pharmacyIndex * 140.0,
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                          userLat: _currentPos?.latitude,
                          userLng: _currentPos?.longitude,
                        )
                      : ListView.builder(
                          controller: _listScrollController,
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
    );
  }

  // ================= CARD =================
  Widget _buildDutyCard(DutyPharmacyModel p) {
    final distKm = _distanceKm(p);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bodyColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pearl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: AppShadows.soft(isDark),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (distKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _distanceBadgeColor(distKm),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        distKm < 1
                            ? "${(distKm * 1000).toInt()} m"
                            : "${distKm.toStringAsFixed(1)} km",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
            style: TextStyle(color: subColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            p.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: bodyColor),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () => launchUrl(Uri.parse('tel:${p.phone}')),
            child: Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  p.phone,
                  style: TextStyle(
                      fontSize: 14,
                      color: bodyColor,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline),
                ),
              ],
            ),
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

          // Kayitli Eczane badge + Eczaneye Git button
          if (p.isRegistered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Kayitli Eczane",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (p.registeredPharmacyId != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PharmacyDetailPage(
                              pharmacyId: p.registeredPharmacyId!,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.store, size: 16),
                      label: const Text("Eczaneye Git"),
                    ),
                  ),
              ],
            ),
          ],
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