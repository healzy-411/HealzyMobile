import 'package:flutter/material.dart';

import '../Models/cart_model.dart';
import '../services/cart_api_service.dart';
import '../services/token_store.dart';
import 'checkout_page.dart';
import 'package:healzy_app/config/api_config.dart';

class CartPage extends StatefulWidget {
  final List<int>? prescriptionItemIds;
  final String? prescriptionNumber;

  const CartPage({
    super.key,
    this.prescriptionItemIds,
    this.prescriptionNumber,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Flutter Web
  final String baseUrl = ApiConfig.baseUrl;

  late final CartApiService cartApi = CartApiService(
    baseUrl: baseUrl,
    getToken: () async => TokenStore.get(),
  );

  CartResponse? cart;
  bool loading = false;
  String? error;

  bool _orderCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await cartApi.getMyCart();
      if (!mounted) return;
      setState(() => cart = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  double get totalPrice => cart?.total ?? 0;
  List<CartItem> get items => cart?.items ?? [];

  Future<void> _cleanupPrescriptionItemsIfNeeded() async {
    // Sadece reçete akışından geldiysek ve sipariş tamamlanmadıysa temizle
    if (_orderCompleted) return;
    final ids = widget.prescriptionItemIds;
    if (ids == null || ids.isEmpty) return;

    for (final id in ids) {
      try {
        await cartApi.removeItem(id);
      } catch (_) {
        // tek tek hata verse de devam et
      }
    }

    try {
      final updated = await cartApi.getMyCart();
      if (!mounted) return;
      setState(() => cart = updated);
    } catch (_) {}
  }

  Future<void> _removeItem(int itemId) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final updated = await cartApi.removeItem(itemId);
      if (!mounted) return;
      setState(() => cart = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _setQty(CartItem item, int newQty) async {
    if (newQty <= 0) {
      await _removeItem(item.id);
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final updated = await cartApi.updateItemQty(
        itemId: item.id,
        quantity: newQty,
      );
      if (!mounted) return;
      setState(() => cart = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _goToCheckout() async {
    if (items.isEmpty || cart == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          cart: cart!,
          prescriptionItemIds: widget.prescriptionItemIds,
          prescriptionNumber: widget.prescriptionNumber,
        ),
      ),
    );

    // Checkout'tan sipariş tamamlandıysa
    if (result == true) {
      _orderCompleted = true;
      await _loadCart();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = totalPrice;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.grey,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    child: GestureDetector(
                      onTap: () async {
                        await _cleanupPrescriptionItemsIfNeeded();
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Siparişlerim",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (loading) const LinearProgressIndicator(),

            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // ================= ÜRÜNLER =================
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text("Sepetiniz bos", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Sol: Ürün adı + eczane
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.medicineName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.pharmacyName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Sağ: quantity + fiyat + delete
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: loading
                                        ? null
                                        : () => _setQty(item, item.quantity - 1),
                                  ),
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: (loading || item.quantity >= 99)
                                        ? null
                                        : () => _setQty(item, item.quantity + 1),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${item.lineTotal.toStringAsFixed(0)} TL",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: loading ? null : () => _removeItem(item.id),
                                  )
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ================= FOOTER =================
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Toplam Fiyat",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${total.toStringAsFixed(0)} TL",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: loading ? null : _goToCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Odemeye Devam Et",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}