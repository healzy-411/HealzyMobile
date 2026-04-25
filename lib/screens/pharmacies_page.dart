import 'dart:ui';
import 'package:flutter/material.dart';
import '../Models/pharmacy_model.dart';
import '../Models/district_model.dart';
import '../Models/insurance_model.dart';
import '../Models/otcmedicine_model.dart';
import '../services/api_service.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/pharmacy_map_view.dart';
import 'categories_page.dart';
import 'pharmacy_detail_page.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../widgets/skeleton_shimmer.dart';
import '../theme/app_colors.dart';

class PharmaciesPage extends StatefulWidget {
  const PharmaciesPage({super.key});

  @override
  State<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends State<PharmaciesPage> {
  final ApiService apiService = ApiService();

  late Future<List<Pharmacy>> futurePharmacies;
  late Future<List<District>> futureDistricts;
  late Future<List<Insurance>> futureInsurances;
  late Future<List<OtcMedicine>> futureMedicines;

  // ================= VIEW MODE =================
  bool _showMap = false;

  // ================= SEARCH =================
  String _searchText = "";

  // ================= FILTER STATES =================
  Map<String, bool> districtFilters = {};
  Map<int, bool> insuranceFilters = {};
  Map<int, bool> medicineFilters = {};

  List<Insurance> _insurances = [];

  @override
  void initState() {
    super.initState();

    futurePharmacies = apiService.getPharmacies();
    futureDistricts = apiService.getDistricts();
    futureInsurances = apiService.getInsurances();
    futureMedicines = apiService.getAllMedicines();

    futureDistricts.then((districts) {
      setState(() {
        for (var d in districts) {
          districtFilters[d.name] = false;
        }
      });
    });

    futureInsurances.then((insurances) {
      setState(() {
        _insurances = insurances;
        for (var i in insurances) {
          insuranceFilters[i.id] = false;
        }
      });
    });

    futureMedicines.then((medicines) {
      setState(() {
        for (var m in medicines) {
          medicineFilters[m.id] = false;
        }
      });
    });
  }

  // ================= APPLY FILTER =================
  void _applyFilters() {
    String? selectedDistrict;
    List<int> selectedInsuranceIds = [];
    List<int> selectedMedicineIds = [];

    districtFilters.forEach((k, v) {
      if (v) selectedDistrict = k;
    });

    insuranceFilters.forEach((k, v) {
      if (v) selectedInsuranceIds.add(k);
    });

    medicineFilters.forEach((k, v) {
      if (v) selectedMedicineIds.add(k);
    });

    setState(() {
      futurePharmacies = apiService.filterPharmacies(
        district: selectedDistrict,
        insuranceCompanyIds:
            selectedInsuranceIds.isEmpty ? null : selectedInsuranceIds,
        medicineIds:
            selectedMedicineIds.isEmpty ? null : selectedMedicineIds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.85)
        : AppColors.lightBlueSoft.withValues(alpha: 0.6);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.midnight.withValues(alpha: 0.1);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),

      // ================= FILTER DRAWER =================
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildFilterHeader(),

            Expanded(
              child: ListView(
                children: [
                  _buildDistrictFilterSection(),
                  _buildInsuranceFilterSection(),
                  _buildMedicineFilterSection(),
                ],
              ),
            ),

            _buildFilterActions(),
          ],
        ),
      ),

      // ================= APPBAR =================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Eczaneler"),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? "Liste görünümü" : "Harita görünümü",
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          )
        ],
      ),

      // ================= BODY =================
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Eczane ara...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Pharmacy>>(
              future: futurePharmacies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: const [
                      PharmacyCardSkeleton(),
                      PharmacyCardSkeleton(),
                      PharmacyCardSkeleton(),
                      PharmacyCardSkeleton(),
                      PharmacyCardSkeleton(),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }

                final pharmacies = snapshot.data!
                    .where((p) =>
                        p.name.toLowerCase().contains(_searchText))
                    .toList();

                if (pharmacies.isEmpty) {
                  return const Center(child: Text("Eczane bulunamadı"));
                }

                // ===== HARITA GORUNUMU =====
                if (_showMap) {
                  return PharmacyMapView(
                    pharmacies: pharmacies
                        .map((p) => PharmacyMarkerData(
                              name: p.name,
                              address: "${p.district} / ${p.address}",
                              phone: p.phone,
                              latitude: p.latitude,
                              longitude: p.longitude,
                              markerColor: p.isOnDuty ? Colors.purple : const Color(0xFF00B894),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PharmacyDetailPage(pharmacyId: p.id),
                                  ),
                                );
                              },
                            ))
                        .toList(),
                  );
                }

                // ===== LISTE GORUNUMU =====
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pharmacies.length,
                  itemBuilder: (context, index) {
                    final p = pharmacies[index];

                    final isClosed = !p.isOpen;

                    return Opacity(
                      opacity: isClosed ? 0.5 : 1.0,
                      child: GestureDetector(
                        onTap: isClosed ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoriesPage(
                                pharmacyId: p.id,
                                pharmacyName: p.name,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isClosed ? null : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cardBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    child: ColorFiltered(
                                      colorFilter: isClosed
                                          ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                      child: p.imageUrl.isNotEmpty
                                          ? Image.network(
                                              p.imageUrl.startsWith('http')
                                                  ? p.imageUrl
                                                  : '${ApiConfig.baseUrl}${p.imageUrl}',
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Image.asset(
                                                'assets/images/pharmacy.jpeg',
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/images/pharmacy.jpeg',
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  if (isClosed)
                                    Positioned(
                                      top: 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text("Kapalı", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (p.isOnDuty)
                                    Positioned(
                                      top: isClosed ? 45 : 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.access_time_filled, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text("Nobetci", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.info_outline,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF102E4A),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PharmacyDetailPage(pharmacyId: p.id),
                                            ),
                                          );
                                        },
                                        tooltip: "Eczane Detay",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "${p.district} / ${p.address}",
                                          style: TextStyle(color: textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 16, color: Colors.red),
                                      const SizedBox(width: 6),
                                      Text(p.workingHours, style: TextStyle(color: textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone,
                                          size: 16, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Text(p.phone, style: TextStyle(color: textPrimary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ================= FILTER UI =================

  Widget _buildFilterHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : AppColors.lightBlueSoft.withValues(alpha: 0.7),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Filtrele",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Icon(Icons.filter_alt_outlined),
        ],
      ),
    );
  }

  Widget _filterCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : AppColors.lightBlueSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        leading: Icon(icon),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  String _districtFilterQuery = '';

  Widget _buildDistrictFilterSection() {
    final sortedKeys = districtFilters.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _districtFilterQuery.isEmpty
        ? sortedKeys
        : sortedKeys.where((k) => k.toLowerCase().contains(_districtFilterQuery)).toList();

    return _filterCard(
      icon: Icons.location_on,
      title: "İlçe",
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: "İlçe ara...",
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (v) => setState(() => _districtFilterQuery = v.toLowerCase()),
          ),
        ),
        ...filtered.map((key) {
          return CheckboxListTile(
            activeColor: const Color(0xFF102E4A),
            title: Text(key),
            value: districtFilters[key],
            onChanged: (val) {
              setState(() {
                districtFilters.updateAll((k, v) => false);
                districtFilters[key] = val!;
                _applyFilters();
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildInsuranceFilterSection() {
    return _filterCard(
      icon: Icons.shield,
      title: "Sigorta",
      children: _insurances.map((insurance) {
        return CheckboxListTile(
          activeColor: const Color(0xFF102E4A),
          title: Text(insurance.name),
          value: insuranceFilters[insurance.id] ?? false,
          onChanged: (val) {
            setState(() {
              insuranceFilters[insurance.id] = val ?? false;
              _applyFilters();
            });
          },
        );
      }).toList(),
    );
  }

  String _medicineFilterQuery = '';

  Widget _buildMedicineFilterSection() {
    return FutureBuilder<List<OtcMedicine>>(
      future: futureMedicines,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final allMedicines = snapshot.data!;
        allMedicines.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final filtered = _medicineFilterQuery.isEmpty
            ? allMedicines
            : allMedicines.where((m) => m.name.toLowerCase().contains(_medicineFilterQuery)).toList();

        return _filterCard(
          icon: Icons.medication,
          title: "Ürün Ara",
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Ürün adı yazın...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (v) => setState(() => _medicineFilterQuery = v.toLowerCase()),
              ),
            ),
            ...filtered.map((m) {
              return CheckboxListTile(
                activeColor: const Color(0xFF102E4A),
                title: Text(m.name),
                value: medicineFilters[m.id] ?? false,
                onChanged: (val) {
                  setState(() {
                    medicineFilters[m.id] = val ?? false;
                    _applyFilters();
                  });
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFilterActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  districtFilters.updateAll((k, v) => false);
                  insuranceFilters.updateAll((k, v) => false);
                  medicineFilters.updateAll((k, v) => false);

                   futurePharmacies = apiService.getPharmacies();
                });
              },
              child: const Text("Temizle"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102E4A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _applyFilters();
                Navigator.pop(context);
              },
              child: const Text("Uygula"),
            ),
          ),
        ],
      ),
    );
  }
}
