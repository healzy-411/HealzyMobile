import 'package:flutter/material.dart';

import '../Models/otcmedicine_model.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/cart_helper.dart';
import '../services/token_store.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';

class ProductsPage extends StatefulWidget {
  final int pharmacyId;
  final String pharmacyName;
  final String categoryName;

  const ProductsPage({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.categoryName,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ApiService apiService = ApiService();
  List<OtcMedicine> _products = [];
  bool _loadingProducts = true;
  String? _productError;

  late final CartApiService cartApi = CartApiService(
    baseUrl: ApiConfig.baseUrl, // Flutter Web
    getToken: () async => TokenStore.get(),
  );

  int cartCount = 0;
  bool adding = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _refreshCartCount();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productError = null;
    });
    try {
      final list = await apiService.getMedicinesByCategory(
        widget.pharmacyId,
        widget.categoryName,
      );
      if (!mounted) return;
      setState(() => _products = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _productError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _refreshCartCount() async {
    try {
      final c = await cartApi.getMyCart();
      if (!mounted) return;
      setState(() => cartCount = c.items.length);
    } catch (_) {
      // token yoksa sessiz geç
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "ağrı kesici":
        return Icons.medication;
      case "vitaminler":
        return Icons.local_florist;
      case "soğuk algınlığı":
        return Icons.healing;
      case "cilt bakımı":
        return Icons.face_retouching_natural;
      case "bebek ürünleri":
        return Icons.child_care;
      case "medikal ürünler":
        return Icons.medical_services;
      default:
        return Icons.medication_outlined;
    }
  }

  Future<void> _addToCart(OtcMedicine product) async {
    if (adding) return;

    setState(() => adding = true);

    try {
      final canAdd = await checkCartPharmacyConflict(
        context: context,
        cartApi: cartApi,
        pharmacyId: widget.pharmacyId,
        pharmacyName: widget.pharmacyName,
      );
      if (!canAdd) {
        if (mounted) setState(() => adding = false);
        return;
      }

      final updated = await cartApi.addToCart(
        pharmacyId: widget.pharmacyId,
        medicineId: product.id,
        quantity: 1,
      );

      debugPrint(
          "ADD SUCCESS -> cartId=${updated.cartId} items=${updated.items.length}");

      if (!mounted) return;
      setState(() => cartCount = updated.items.length);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product.name} sepete eklendi ✅"),
          duration: const Duration(milliseconds: 700),
        ),
      );
    } catch (e) {
      debugPrint("ADD FAILED -> $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sepete eklenemedi: $e"),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.55);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.55);
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            // PRODUCTS
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                child: _loadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : _productError != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 40),
                              Center(
                                child: Column(
                                  children: [
                                    Text("Hata: $_productError", style: const TextStyle(color: Colors.red)),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: _loadProducts,
                                      child: const Text("Tekrar Dene"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _products.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 40),
                                  Center(child: Text("Bu kategoride ürün yok")),
                                ],
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 0.65,
                                ),
                                itemCount: _products.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(_products[index]);
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
      ),

      // CART BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: cardBg,
        foregroundColor: fg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cardBorder, width: 0.8),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          ).then((_) => _refreshCartCount());
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.shopping_basket_outlined, color: fg, size: 28),
            if (cartCount > 0)
              Positioned(
                right: -8,
                top: -8,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    '$cartCount',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(OtcMedicine product) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) {
      return Icon(
        _getCategoryIcon(widget.categoryName),
        size: 60,
        color: Colors.black87,
      );
    }
    final full = url.startsWith('http')
        ? url
        : '${ApiConfig.baseUrl}$url';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        full,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          _getCategoryIcon(widget.categoryName),
          size: 60,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProductCard(OtcMedicine product) {
    final isOutOfStock = product.quantity == 0;
    final isLowStock = product.quantity > 0 && product.quantity < 5;

    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(
                  product: product,
                  categoryName: widget.categoryName,
                  onAddToCart: adding ? null : () => _addToCart(product),
                ),
              ),
            ),
      child: Builder(builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.55);
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.55);
        final fg = isDark ? Colors.white : const Color(0xFF102E4A);
        return Opacity(
        opacity: isOutOfStock ? 0.5 : 1.0,
        child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProductImage(product),
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: fg,
              ),
            ),
            Text(
              "${product.price.toStringAsFixed(2)} TL",
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 14),
            ),
            if (isOutOfStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Stokta Yok",
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              )
            else if (isLowStock)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Tükenmek Üzere",
                      style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  GestureDetector(
                    onTap: adding ? null : () => _addToCart(product),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: adding ? Colors.grey.shade400 : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: adding ? null : () => _addToCart(product),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: adding ? Colors.grey.shade400 : Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
          ],
        ),
        ),
        );
      }),
    );
  }
}
