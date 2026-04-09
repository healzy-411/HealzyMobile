import 'package:flutter/material.dart';
import '../Models/otcmedicine_model.dart';
import '../Models/medicine_search_model.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/cart_helper.dart';
import '../services/token_store.dart';
import 'categories_page.dart';

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key});

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  late final CartApiService _cartApi = CartApiService(
    baseUrl: 'http://localhost:5009',
    getToken: () async => TokenStore.get(),
  );

  List<OtcMedicine> _allMedicines = [];
  List<OtcMedicine> _filteredMedicines = [];
  final Set<int> _selectedIds = {};
  List<PharmacyCompareResult> _compareResults = [];

  bool _loadingMedicines = true;
  bool _comparing = false;
  bool _compared = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await _api.getAllMedicines();
      if (!mounted) return;
      setState(() {
        _allMedicines = medicines;
        _filteredMedicines = medicines;
        _loadingMedicines = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMedicines = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onFilterChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredMedicines = _allMedicines;
      } else {
        _filteredMedicines = _allMedicines
            .where((m) => m.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _toggleSelection(int medicineId) {
    setState(() {
      if (_selectedIds.contains(medicineId)) {
        _selectedIds.remove(medicineId);
      } else {
        _selectedIds.add(medicineId);
      }
    });
  }

  Future<void> _compare() async {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _comparing = true;
      _compared = false;
      _compareResults = [];
    });
    try {
      final results = await _api.compareMedicines(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _compareResults = results;
        _comparing = false;
        _compared = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comparing = false;
        _compared = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToPharmacy(PharmacyCompareResult pharmacy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesPage(
          pharmacyId: pharmacy.pharmacyId,
          pharmacyName: pharmacy.pharmacyName,
        ),
      ),
    );
  }

  Future<void> _addToCartAndGo(PharmacyCompareResult pharmacy) async {
    try {
      final canAdd = await checkCartPharmacyConflict(
        context: context,
        cartApi: _cartApi,
        pharmacyId: pharmacy.pharmacyId,
        pharmacyName: pharmacy.pharmacyName,
      );
      if (!canAdd || !mounted) return;

      for (final line in pharmacy.lines) {
        await _cartApi.addToCart(
          pharmacyId: pharmacy.pharmacyId,
          medicineId: line.medicineId,
          quantity: 1,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${pharmacy.lines.length} ilac sepete eklendi"),
          backgroundColor: const Color(0xFF00A79D),
        ),
      );
      _goToPharmacy(pharmacy);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _medicineName(int id) {
    return _allMedicines
        .firstWhere((m) => m.id == id, orElse: () => OtcMedicine(id: id, name: '?', price: 0))
        .name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ilac Ara"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
      ),
      body: _loadingMedicines
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A79D)))
          : Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onFilterChanged,
                    decoration: InputDecoration(
                      hintText: "Ilac adi yazin...",
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00A79D)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onFilterChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00A79D), width: 2),
                      ),
                    ),
                  ),
                ),

                // Medicine checkbox list
                SizedBox(
                  height: 200,
                  child: _filteredMedicines.isEmpty
                      ? const Center(
                          child: Text("Ilac bulunamadi", style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredMedicines.length,
                          itemBuilder: (context, index) {
                            final med = _filteredMedicines[index];
                            final selected = _selectedIds.contains(med.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (_) => _toggleSelection(med.id),
                              title: Text(med.name),
                              subtitle: Text("${med.price.toStringAsFixed(2)} TL"),
                              activeColor: const Color(0xFF00A79D),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                ),

                // Selected chips
                if (_selectedIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Secilenler:",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedIds.map((id) {
                            return Chip(
                              label: Text(_medicineName(id)),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _toggleSelection(id),
                              backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.12),
                              labelStyle: const TextStyle(color: Color(0xFF00A79D)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                // Compare button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedIds.isEmpty || _comparing ? null : _compare,
                      icon: _comparing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_comparing ? "Aranıyor..." : "Eczaneleri Karsilastir"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A79D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                // Results
                if (_compared)
                  Expanded(
                    child: _compareResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  "Bu ilaclari birlikte bulunduran\neczane bulunamadi",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _compareResults.length,
                            itemBuilder: (context, index) {
                              return _buildPharmacyCard(_compareResults[index]);
                            },
                          ),
                  )
                else if (!_compared)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            "Ilac secip fiyatlari\nkarsilastirin",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPharmacyCard(PharmacyCompareResult pharmacy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.15),
                  child: const Icon(Icons.local_pharmacy, color: Color(0xFF00A79D)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacy.pharmacyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        pharmacy.district,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...pharmacy.lines.map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(line.medicineName),
                      ),
                      Text(
                        "${line.unitPrice.toStringAsFixed(2)} TL",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOPLAM",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "${pharmacy.totalPrice.toStringAsFixed(2)} TL",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF00A79D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _goToPharmacy(pharmacy),
                    icon: const Icon(Icons.storefront, size: 18),
                    label: const Text("Eczaneye Git"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00A79D),
                      side: const BorderSide(color: Color(0xFF00A79D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addToCartAndGo(pharmacy),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Sepete Ekle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A79D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
