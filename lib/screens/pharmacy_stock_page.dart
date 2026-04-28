import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';
import '../utils/error_messages.dart';

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
        _error = friendlyError(e);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.midnight;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: const Text("Stok Yönetimi"),
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.lightPageGradient,
            color: isDark ? AppColors.darkBg : null,
          ),
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStocks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStockDialog(),
        backgroundColor: AppColors.midnight,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Ürün Ekle", style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loading
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
                      _buildSummaryRow(),
                      _buildSearchAndFilter(),
                      Expanded(child: _buildStockList()),
                    ],
                  ),
      ),
    );
  }

  // ======== ÖZET ========
  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _miniCard("Ürün", "$_totalProducts", Icons.medication, Colors.blue),
          const SizedBox(width: 8),
          _miniCard(
              "Toplam Stok", "$_totalQuantity", Icons.inventory, AppColors.midnight),
          const SizedBox(width: 8),
          _miniCard("Dusuk Stok", "$_lowStockCount", Icons.warning_amber,
              Colors.orange),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
            Text(label, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ======== ARAMA + FİLTRE ========
  Widget _buildSearchAndFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);
    final fieldBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.midnight.withValues(alpha: 0.08);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.midnight;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : AppColors.midnight),
              decoration: InputDecoration(
                hintText: "Ürün ara...",
                hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.grey[600]),
                prefixIcon: Icon(Icons.search, size: 20, color: iconColor),
                isDense: true,
                filled: true,
                fillColor: fieldBg,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.midnight, width: 1.5)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fieldBorder),
            ),
            child: PopupMenuButton<String?>(
              icon: Badge(
                isLabelVisible: _selectedCategory != null,
                child: Icon(Icons.filter_list, color: iconColor),
              ),
              onSelected: (val) => setState(() => _selectedCategory = val),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text("Tümü")),
                ..._categories.map(
                    (c) => PopupMenuItem(value: c, child: Text(c))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======== STOK LİSTESİ ========
  Widget _buildStockList() {
    final items = _filteredStocks;

    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Text(
          "Stok bulunamadı.",
          style: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey[600],
              fontSize: 14),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;

    final name = s["medicineName"] ?? "";
    final category = s["categoryName"] ?? "Diğer";
    final qty = (s["quantity"] ?? 0) as int;
    final unitPrice = (s["unitPrice"] ?? 0).toDouble();
    final listPrice = (s["listPrice"] ?? 0).toDouble();
    final isPrescription = (s["isPrescriptionRequired"] ?? false) as bool;
    final medicineId = (s["medicineId"] ?? 0) as int;
    final isLowStock = qty <= 5;

    final cardBg = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.68);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.midnight.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: titleC)),
                        ),
                        if (isPrescription)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text("Reçeteli",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white : Colors.red.shade700,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(category,
                        style: TextStyle(fontSize: 12.5, color: muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? Colors.red.withValues(alpha: isDark ? 0.22 : 0.12)
                      : AppColors.midnight.withValues(alpha: isDark ? 0.35 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text("$qty",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isLowStock
                                ? (isDark ? Colors.red.shade300 : Colors.red)
                                : (isDark ? Colors.white : AppColors.midnight))),
                    Text("adet",
                        style: TextStyle(
                            fontSize: 11,
                            color: isLowStock
                                ? (isDark ? Colors.red.shade300 : Colors.red)
                                : (isDark ? Colors.white70 : AppColors.midnight))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text("Satış: ${unitPrice.toStringAsFixed(2)} TL",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: titleC)),
              const SizedBox(width: 12),
              Text("Liste: ${listPrice.toStringAsFixed(2)} TL",
                  style: TextStyle(fontSize: 13, color: muted)),
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
                  icon: Icon(Icons.edit, size: 16, color: isDark ? Colors.white : AppColors.midnight),
                  label: Text("Düzenle", style: TextStyle(color: isDark ? Colors.white : AppColors.midnight)),
                  style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppColors.midnight),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmRemoveStock(medicineId, name),
                  icon: Icon(Icons.delete_outline, size: 16, color: isDark ? Colors.red.shade300 : Colors.red),
                  label: Text("Kaldır", style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red)),
                  style: TextButton.styleFrom(foregroundColor: isDark ? Colors.red.shade300 : Colors.red),
                ),
              ],
            ),
          ],
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
                                friendlyError(e));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnight,
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
                            friendlyError(e)),
                        backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnight,
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
                  Text(friendlyError(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
