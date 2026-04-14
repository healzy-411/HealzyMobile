import 'package:flutter/material.dart';

import '../Models/prescription_models.dart';
import '../services/prescription_api_service.dart';
import '../services/cart_api_service.dart';
import '../services/token_store.dart';
import 'cart_page.dart';

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
  bool _loading = false;
  String? _error;

  PrescriptionPriceResultDto? _result;

  late final CartApiService _cartApi = CartApiService(
    baseUrl: widget.api.baseUrl,
    getToken: () async => TokenStore.get(),
  );

  @override
  void initState() {
    super.initState();
    _selectedItemIds = widget.detail.items.map((e) => e.itemId).toSet();
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
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                final selected = _selectedItemIds.contains(it.itemId);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(it.itemId);
                      } else {
                        _selectedItemIds.remove(it.itemId);
                      }
                      _result = null;
                    });
                  },
                  title: Text(it.medicineName),
                  subtitle: Text(
                    "Adet: ${it.quantity} • Birim: ${it.unitPrice.toStringAsFixed(2)} ₺ • Satır: ${it.lineTotal.toStringAsFixed(2)} ₺",
                  ),
                );
              },
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

  Widget _buildResultSection(PrescriptionPriceResultDto r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(top: BorderSide(color: Colors.grey)),
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
                        // 1) Mevcut sepet snapshot'ını al
                        final beforeCart = await _cartApi.getMyCart();
                        final beforeIds =
                            beforeCart.items.map((e) => e.id).toSet();

                        // 2) Reçete ilaçlarını topluca sepete ekle
                        final afterCart = await widget.api.addPrescriptionToCart(
                          prescriptionNumber: widget.detail.prescriptionNumber,
                          pharmacyId: p.id,
                          selectedItemIds: _selectedItemIds.toList(),
                        );

                        if (!mounted) return;

                        // 3) Yeni eklenen cart item id'lerini bul
                        final afterIds =
                            afterCart.items.map((e) => e.id).toSet();
                        final newIds =
                            afterIds.difference(beforeIds).toList();

                        // 4) CartPage'e bu liste ve reçete numarası ile git
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CartPage(
                              prescriptionItemIds: newIds,
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

