import 'package:flutter/material.dart';

import '../Models/prescription_models.dart';
import '../services/prescription_api_service.dart';
import 'cart_page.dart';
import '../widgets/healzy_bottom_nav.dart';

class PrescriptionPage extends StatefulWidget {
  final PrescriptionDetailDto detail;
  final PrescriptionApiService api;

  const PrescriptionPage({
    super.key,
    required this.detail,
    required this.api,
  });

  @override
  State<PrescriptionPage> createState() => _PrescriptionPageState();
}

class _PrescriptionPageState extends State<PrescriptionPage> {
  late Set<int> _selectedItemIds;
  late Map<int, int> _quantities; // itemId -> current qty
  late Map<int, int> _maxQuantities; // itemId -> prescribed max qty
  bool _loading = false;
  String? _error;

  PrescriptionPriceResultDto? _result;

  @override
  void initState() {
    super.initState();
    _selectedItemIds = widget.detail.items.map((e) => e.itemId).toSet();
    _quantities = {for (final it in widget.detail.items) it.itemId: it.quantity};
    _maxQuantities = {for (final it in widget.detail.items) it.itemId: it.quantity};
  }

  void _decrease(PrescriptionItemDto it) {
    final current = _quantities[it.itemId] ?? 0;
    if (current <= 0) return;
    setState(() {
      final next = current - 1;
      _quantities[it.itemId] = next;
      if (next == 0) {
        _selectedItemIds.remove(it.itemId);
      }
      _result = null;
    });
  }

  void _increase(PrescriptionItemDto it) {
    final current = _quantities[it.itemId] ?? 0;
    final max = _maxQuantities[it.itemId] ?? it.quantity;
    if (current >= max) return;
    setState(() {
      final next = current + 1;
      _quantities[it.itemId] = next;
      if (next > 0) {
        _selectedItemIds.add(it.itemId);
      }
      _result = null;
    });
  }

  Future<void> _simulate() async {
    if (_selectedItemIds.isEmpty) {
      setState(() => _error = "En az bir ilaç seçmelisiniz.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.api.simulate(
        prescriptionNumber: widget.detail.prescriptionNumber,
        selectedItemIds: _selectedItemIds.toList(),
        district: null,
        insuranceCompanyIds: null,
        itemQuantities: {
          for (final id in _selectedItemIds)
            if ((_quantities[id] ?? 0) > 0) id: _quantities[id]!
        },
      );

      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.detail.items;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: Text("Reçete ${widget.detail.prescriptionNumber}"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            "Sigorta indirimi: ${(widget.detail.insuranceDiscountRate * 100).toStringAsFixed(0)}%",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildItemTile(items[i]),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _simulate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102E4A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        "Devam Et",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          if (_result != null) _buildResultSection(_result!),
        ],
      ),
    );
  }

  Widget _buildItemTile(PrescriptionItemDto it) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final sub = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    final qty = _quantities[it.itemId] ?? 0;
    final maxQty = _maxQuantities[it.itemId] ?? it.quantity;
    final lineTotal = it.unitPrice * qty;
    final canDecrease = qty > 0;
    final canIncrease = qty < maxQty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.medicineName,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Birim: ${it.unitPrice.toStringAsFixed(2)} ₺  •  Reçete: $maxQty adet",
                  style: TextStyle(color: sub, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  "Satır: ${lineTotal.toStringAsFixed(2)} ₺",
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFF102E4A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFF102E4A).withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Azalt",
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed: canDecrease ? () => _decrease(it) : null,
                  icon: Icon(
                    Icons.remove,
                    color: canDecrease ? fg : fg.withValues(alpha: 0.3),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    "$qty",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: canIncrease ? "Arttır" : "Reçete üstü ekleme yapılamaz",
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed: canIncrease ? () => _increase(it) : null,
                  icon: Icon(
                    Icons.add,
                    color: canIncrease ? fg : fg.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(PrescriptionPriceResultDto r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.55),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Toplam: ${r.totalBeforeDiscount.toStringAsFixed(2)} ₺",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text("İndirim: ${r.discountAmount.toStringAsFixed(2)} ₺"),
          Text("Net: ${r.netTotal.toStringAsFixed(2)} ₺"),
          const SizedBox(height: 8),
          const Text(
            "İlaçları sağlayan eczaneler:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (r.pharmacies.isEmpty)
            const Text("Uygun eczane bulunamadı.")
          else
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: r.pharmacies.length,
                itemBuilder: (_, i) {
                  final p = r.pharmacies[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text("${p.district} • ${p.address}"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      if (_selectedItemIds.isEmpty) {
                        setState(() => _error = "En az bir ilaç seçmelisiniz.");
                        return;
                      }

                      setState(() {
                        _loading = true;
                        _error = null;
                      });

                      try {
                        // Backend sepeti temizleyip reçete ilaçlarını ekler
                        final afterCart = await widget.api.addPrescriptionToCart(
                          prescriptionNumber: widget.detail.prescriptionNumber,
                          pharmacyId: p.id,
                          selectedItemIds: _selectedItemIds.toList(),
                          itemQuantities: {
                            for (final id in _selectedItemIds)
                              if ((_quantities[id] ?? 0) > 0) id: _quantities[id]!
                          },
                        );

                        if (!mounted) return;

                        // Tüm cart item'lar reçeteden geldi (sepet temizlendi)
                        final allIds =
                            afterCart.items.map((e) => e.id).toList();

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CartPage(
                              prescriptionItemIds: allIds,
                              prescriptionNumber:
                                  widget.detail.prescriptionNumber,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _error =
                            e.toString().replaceFirst("Exception: ", ""));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_error!),
                          ),
                        );
                      } finally {
                        if (!mounted) return;
                        setState(() => _loading = false);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

