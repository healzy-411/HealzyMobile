import 'dart:async';
import 'package:flutter/material.dart';
import '../Models/medicine_search_model.dart';
import '../services/api_service.dart';
import 'products_page.dart';

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key});

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<MedicineSearchResult> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _api.searchOtcMedicines(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ilac Ara"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Ilac adi yazin (en az 2 karakter)...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00A79D)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _searched = false;
                          });
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
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00A79D))),
            )
          else if (!_searched)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      "Recetesiz ilac arayin\nve fiyatlari karsilastirin",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      "Sonuc bulunamadi",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final med = _results[index];
                  return _buildMedicineCard(med);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(MedicineSearchResult med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.15),
          child: const Icon(Icons.medication, color: Color(0xFF00A79D)),
        ),
        title: Text(
          med.medicineName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              med.categoryName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "${med.pharmacies.length} eczanede mevcut",
              style: const TextStyle(fontSize: 12, color: Color(0xFF00A79D)),
            ),
            if (med.pharmacies.isNotEmpty)
              Text(
                "${med.pharmacies.first.unitPrice.toStringAsFixed(2)} TL'den baslayan",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
          ],
        ),
        children: med.pharmacies
            .map((p) => _buildPharmacyRow(p, med.categoryName))
            .toList(),
      ),
    );
  }

  Widget _buildPharmacyRow(PharmacyPrice pharmacy, String categoryName) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductsPage(
              pharmacyId: pharmacy.pharmacyId,
              categoryName: categoryName,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.local_pharmacy, size: 18, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pharmacy.pharmacyName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    pharmacy.pharmacyDistrict,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${pharmacy.unitPrice.toStringAsFixed(2)} TL",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF00A79D),
                  ),
                ),
                Text(
                  "Stok: ${pharmacy.quantity}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
