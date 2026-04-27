import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_colors.dart';
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
      final msg = e.toString();
      if (msg.contains('400')) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stok yetersiz'),
            content: const Text('Bu ürün için eczanede yeterli stok bulunmuyor.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        setState(() => error = msg);
      }
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

    // Checkout'tan sipariş tamamlandıysa ana sayfaya dön
    if (result == true) {
      _orderCompleted = true;
      await _loadCart();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = totalPrice;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sepetim"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _cleanupPrescriptionItemsIfNeeded();
            if (!mounted) return;
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkPageGradient
              : AppColors.lightPageGradient,
        ),
        child: Column(
        children: [
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
                          Text("Sepetiniz boş", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (context, _) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isPrescriptionItem =
                            widget.prescriptionItemIds?.contains(item.id) ?? false;
                        return Slidable(
                          key: ValueKey(item.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.22,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _removeItem(item.id),
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                icon: Icons.delete_outline,
                                label: 'Sil',
                                borderRadius: BorderRadius.circular(14),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          child: _CartItemTile(
                            item: item,
                            loading: loading,
                            canIncrement: !loading && item.quantity < 99 && !isPrescriptionItem,
                            onDecrement: () => _setQty(item, item.quantity - 1),
                            onIncrement: () => _setQty(item, item.quantity + 1),
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
                          "${total.toStringAsFixed(2)} TL",
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
                          backgroundColor: const Color(0xFF102E4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Ödemeye Devam Et",
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

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool loading;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CartItemTile({
    required this.item,
    required this.loading,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subText = isDark ? Colors.white70 : Colors.grey.shade600;
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.12);
    final placeholderBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade200;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ürün resmi
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.medicineImageUrl != null && item.medicineImageUrl!.isNotEmpty
              ? Image.network(
                  item.medicineImageUrl!.startsWith('http')
                      ? item.medicineImageUrl!
                      : '${ApiConfig.baseUrl}${item.medicineImageUrl}',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: placeholderBg,
                    child: Icon(Icons.medication, size: 28, color: subText),
                  ),
                )
              : Container(
                  width: 64,
                  height: 64,
                  color: placeholderBg,
                  child: Icon(Icons.medication, size: 28, color: subText),
                ),
        ),
        const SizedBox(width: 14),

        // Orta: ad + eczane + miktar pili
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.medicineName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.pharmacyName,
                style: TextStyle(fontSize: 12, color: subText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: pillBorder, width: 1.4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: loading ? null : onDecrement,
                      borderRadius: BorderRadius.circular(30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Icon(Icons.remove, size: 18, color: primaryText),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: canIncrement ? onIncrement : null,
                      borderRadius: BorderRadius.circular(30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: canIncrement ? primaryText : subText.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Sağ: fiyat
        Text(
          "${item.lineTotal.toStringAsFixed(2)} TL",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ],
    );
  }
}