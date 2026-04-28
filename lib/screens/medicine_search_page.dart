import 'package:flutter/material.dart';
import '../Models/otcmedicine_model.dart';
import '../Models/medicine_search_model.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/cart_helper.dart';
import '../services/token_store.dart';
import 'cart_page.dart';
import 'categories_page.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key});

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  late final CartApiService _cartApi = CartApiService(
    baseUrl: ApiConfig.baseUrl,
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
      // Aynı isimli ilaçlar farklı eczanelerde farklı id ile kayıtlı olabiliyor.
      // Listede her isim için tek satır göster (temsilci olarak en küçük id'liyi seç).
      final byName = <String, OtcMedicine>{};
      for (final m in medicines) {
        final key = m.name.trim().toLowerCase();
        final existing = byName[key];
        if (existing == null || m.id < existing.id) {
          byName[key] = m;
        }
      }
      final unique = byName.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _allMedicines = unique;
        _filteredMedicines = unique;
        _loadingMedicines = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMedicines = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
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
    final wasCompared = _compared;
    setState(() {
      if (_selectedIds.contains(medicineId)) {
        _selectedIds.remove(medicineId);
      } else {
        _selectedIds.add(medicineId);
      }
    });
    // Hiç seçim kalmadıysa listeyi temizle
    if (_selectedIds.isEmpty) {
      setState(() {
        _compareResults = [];
        _compared = false;
      });
      return;
    }
    // Daha önce karşılaştırma yapılmışsa kalan seçimle otomatik yenile
    if (wasCompared) {
      _compare();
    }
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
          content: Text(friendlyError(e)),
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
          content: Text("${pharmacy.lines.length} ürün sepete eklendi"),
          backgroundColor: const Color(0xFF102E4A),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: const Text("Ürün Ara"),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loadingMedicines
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF102E4A)))
          : Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onFilterChanged,
                    decoration: InputDecoration(
                      hintText: "Ürün adı yazın...",
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF102E4A)),
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
                        borderSide: const BorderSide(color: Color(0xFF102E4A), width: 2),
                      ),
                    ),
                  ),
                ),

                // Medicine checkbox list (compared sonrası daralsın)
                SizedBox(
                  height: _compared ? 120 : 240,
                  child: _filteredMedicines.isEmpty
                      ? const Center(
                          child: Text("Ürün bulunamadı", style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          primary: false,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredMedicines.length,
                          itemBuilder: (context, index) {
                            final med = _filteredMedicines[index];
                            final selected = _selectedIds.contains(med.id);
                            final isDark = Theme.of(context).brightness ==
                                Brightness.dark;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: selected
                                    ? (isDark ? AppColors.darkSurface : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: CheckboxListTile(
                                value: selected,
                                onChanged: (_) => _toggleSelection(med.id),
                                title: Text(med.name, style: TextStyle(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.midnight,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                )),
                                secondary: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: med.imageUrl != null && med.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          med.imageUrl!.startsWith('http')
                                              ? med.imageUrl!
                                              : '${ApiConfig.baseUrl}${med.imageUrl}',
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.medication,
                                            size: 32,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.medication,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                ),
                                activeColor:
                                    isDark ? Colors.white : AppColors.midnight,
                                checkColor:
                                    isDark ? AppColors.midnight : Colors.white,
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppColors.midnight.withValues(alpha: 0.6),
                                  width: 1.4,
                                ),
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
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
                          "Seçilenler:",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedIds.map((id) {
                            final isDark = Theme.of(context).brightness ==
                                Brightness.dark;
                            final chipColor = isDark
                                ? Colors.white
                                : const Color(0xFF102E4A);
                            return Chip(
                              label: Text(_medicineName(id)),
                              deleteIcon: Icon(Icons.close,
                                  size: 18, color: chipColor),
                              onDeleted: () => _toggleSelection(id),
                              backgroundColor:
                                  chipColor.withValues(alpha: 0.15),
                              labelStyle: TextStyle(color: chipColor),
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
                      label: Text(_comparing ? "Aranıyor..." : "Eczaneleri Karşılaştır"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF102E4A),
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
                                  "Bu ürünleri birlikte bulunduran\neczane bulunamadı",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            primary: false,
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
                            "Ürün seçip fiyatları\nkarşılaştırın",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _buildPharmacyCard(PharmacyCompareResult pharmacy) {
    final isClosed = !pharmacy.isOpen;
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
                Expanded(
                  child: Text(
                    pharmacy.pharmacyName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (isClosed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Kapalı",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
                    color: Color(0xFF102E4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isClosed ? null : () => _goToPharmacy(pharmacy),
                    icon: const Icon(Icons.storefront, size: 18),
                    label: Text(isClosed ? "Kapalı" : "Eczaneye Git"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF102E4A),
                      side: BorderSide(color: isClosed ? Colors.grey : const Color(0xFF102E4A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isClosed ? null : () => _addToCartAndGo(pharmacy),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(isClosed ? "Kapalı" : "Sepete Ekle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF102E4A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white,
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
