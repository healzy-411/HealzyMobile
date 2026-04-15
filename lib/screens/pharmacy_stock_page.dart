import 'package:flutter/material.dart';
import '../services/pharmacy_panel_api_service.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyStockPage extends StatefulWidget {
  const PharmacyStockPage({super.key});

  @override
  State<PharmacyStockPage> createState() => _PharmacyStockPageState();
}

class _PharmacyStockPageState extends State<PharmacyStockPage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);

  List<Map<String, dynamic>> _stocks = [];
  bool _loading = true;
  String? _error;

  // Filtre
  String _searchQuery = "";
  String? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stocks = await _api.getStocks();
      setState(() {
        _stocks = stocks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredStocks {
    var list = _stocks;
    if (_selectedCategory != null) {
      list = list.where((s) => s["categoryName"] == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((s) =>
              (s["medicineName"] ?? "").toString().toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  List<String> get _categories {
    return _stocks
        .map((s) => (s["categoryName"] ?? "Diger").toString())
        .toSet()
        .toList()
      ..sort();
  }

  // Toplam stok özeti
  int get _totalProducts => _stocks.length;
  int get _totalQuantity =>
      _stocks.fold(0, (sum, s) => sum + ((s["quantity"] ?? 0) as int));
  int get _lowStockCount =>
      _stocks.where((s) => ((s["quantity"] ?? 0) as int) <= 5).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stok Yonetimi"),
        backgroundColor: const Color(0xFF102E4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStocks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStockDialog(),
        backgroundColor: const Color(0xFF102E4A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Urun Ekle", style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadStocks,
                          child: const Text("Tekrar Dene")),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Özet kartlar
                    _buildSummaryRow(),
                    // Arama + filtre
                    _buildSearchAndFilter(),
                    // Liste
                    Expanded(child: _buildStockList()),
                  ],
                ),
    );
  }

  // ======== ÖZET ========
  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _miniCard("Urun", "$_totalProducts", Icons.medication, Colors.blue),
          const SizedBox(width: 8),
          _miniCard(
              "Toplam Stok", "$_totalQuantity", Icons.inventory, const Color(0xFF102E4A)),
          const SizedBox(width: 8),
          _miniCard("Dusuk Stok", "$_lowStockCount", Icons.warning_amber,
              Colors.orange),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ======== ARAMA + FİLTRE ========
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Urun ara...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            icon: Badge(
              isLabelVisible: _selectedCategory != null,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (val) => setState(() => _selectedCategory = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text("Tumu")),
              ..._categories.map(
                  (c) => PopupMenuItem(value: c, child: Text(c))),
            ],
          ),
        ],
      ),
    );
  }

  // ======== STOK LİSTESİ ========
  Widget _buildStockList() {
    final items = _filteredStocks;

    if (items.isEmpty) {
      return const Center(
        child: Text("Stok bulunamadi.", style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStocks,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: items.length,
        itemBuilder: (context, i) => _stockCard(items[i]),
      ),
    );
  }

  Widget _stockCard(Map<String, dynamic> s) {
    final name = s["medicineName"] ?? "";
    final category = s["categoryName"] ?? "Diger";
    final qty = (s["quantity"] ?? 0) as int;
    final unitPrice = (s["unitPrice"] ?? 0).toDouble();
    final listPrice = (s["listPrice"] ?? 0).toDouble();
    final isPrescription = (s["isPrescriptionRequired"] ?? false) as bool;
    final medicineId = (s["medicineId"] ?? 0) as int;
    final isLowStock = qty <= 5;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: isim + kategori
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          if (isPrescription)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text("Receteli",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(category,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
                // Stok badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? Colors.red.shade50
                        : const Color(0xFF102E4A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text("$qty",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isLowStock
                                  ? Colors.red
                                  : const Color(0xFF102E4A))),
                      Text("adet",
                          style: TextStyle(
                              fontSize: 14,
                              color: isLowStock
                                  ? Colors.red
                                  : const Color(0xFF102E4A))),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Fiyat satırı
            Row(
              children: [
                Text("Satis: ${unitPrice.toStringAsFixed(2)} TL",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 12),
                Text("Liste: ${listPrice.toStringAsFixed(2)} TL",
                    style:
                        const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),

            if (isLowStock)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text("Dusuk stok!",
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Aksiyon butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _showEditStockDialog(medicineId, name, qty, unitPrice),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Duzenle"),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF102E4A)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmRemoveStock(medicineId, name),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text("Kaldir"),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ======== STOK EKLEME DİALOG ========
  Future<void> _showAddStockDialog() async {
    List<Map<String, dynamic>>? medicines;
    String? addError;

    try {
      medicines = await _api.getAllMedicines();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ilaclar yuklenemedi: $e")),
      );
      return;
    }

    // Zaten stokta olanları çıkar
    final stockMedIds =
        _stocks.map((s) => (s["medicineId"] ?? 0) as int).toSet();
    medicines =
        medicines.where((m) => !stockMedIds.contains(m["id"] ?? 0)).toList();

    if (medicines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eklenecek yeni urun bulunamadi.")),
      );
      return;
    }

    Map<String, dynamic>? selectedMedicine;
    final qtyController = TextEditingController(text: "1");
    final priceController = TextEditingController();
    String searchText = "";

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = searchText.isEmpty
                ? medicines!
                : medicines!
                    .where((m) => (m["name"] ?? "")
                        .toString()
                        .toLowerCase()
                        .contains(searchText.toLowerCase()))
                    .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Urun Ekle",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Arama
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Ilac ara...",
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setSheetState(() => searchText = v),
                  ),
                  const SizedBox(height: 8),

                  // İlaç listesi
                  if (selectedMedicine == null)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final m = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Text(m["name"] ?? ""),
                            subtitle: Text(
                                "${(m["price"] ?? 0).toDouble().toStringAsFixed(2)} TL"),
                            onTap: () {
                              setSheetState(() {
                                selectedMedicine = m;
                                priceController.text =
                                    (m["price"] ?? 0).toDouble().toStringAsFixed(2);
                              });
                            },
                          );
                        },
                      ),
                    ),

                  // Seçildiyse form
                  if (selectedMedicine != null) ...[
                    Card(
                      child: ListTile(
                        title: Text(selectedMedicine!["name"] ?? ""),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setSheetState(() => selectedMedicine = null),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            decoration: const InputDecoration(
                              labelText: "Adet",
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration: const InputDecoration(
                              labelText: "Birim Fiyat (TL)",
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (addError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(addError!,
                            style: const TextStyle(color: Colors.red, fontSize: 14)),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final medId = (selectedMedicine!["id"] ?? 0) as int;
                          final qty = int.tryParse(qtyController.text) ?? 0;
                          final price =
                              double.tryParse(priceController.text) ?? 0;

                          if (qty <= 0 || price <= 0) {
                            setSheetState(
                                () => addError = "Adet ve fiyat 0'dan buyuk olmali.");
                            return;
                          }

                          try {
                            await _api.addStock(
                              medicineId: medId,
                              quantity: qty,
                              unitPrice: price,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadStocks();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Urun eklendi.")),
                            );
                          } catch (e) {
                            setSheetState(() => addError =
                                e.toString().replaceFirst("Exception: ", ""));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF102E4A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Stoga Ekle"),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======== STOK DÜZENLEME DİALOG ========
  Future<void> _showEditStockDialog(
      int medicineId, String name, int currentQty, double currentPrice) async {
    final qtyController = TextEditingController(text: "$currentQty");
    final priceController =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(name, style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                    labelText: "Adet", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                    labelText: "Birim Fiyat (TL)",
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Iptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0;

                if (qty < 0 || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Gecersiz deger."),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  await _api.updateStock(
                    medicineId: medicineId,
                    quantity: qty,
                    unitPrice: price,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadStocks();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Stok guncellendi.")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            e.toString().replaceFirst("Exception: ", "")),
                        backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102E4A),
                foregroundColor: Colors.white,
              ),
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  // ======== STOK KALDIR ONAY ========
  Future<void> _confirmRemoveStock(int medicineId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Urunu Kaldir"),
        content: Text("\"$name\" stoktan kaldirilacak. Emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Iptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text("Kaldir", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.removeStock(medicineId);
        _loadStocks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Urun stoktan kaldirildi.")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst("Exception: ", "")),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
