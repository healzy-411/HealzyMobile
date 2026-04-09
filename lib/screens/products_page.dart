import 'package:flutter/material.dart';

import '../Models/otcmedicine_model.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/cart_helper.dart';
import '../services/token_store.dart';
import 'cart_page.dart';

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
    baseUrl: 'http://localhost:5009', // Flutter Web
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.grey,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    widget.categoryName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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
                                  Center(child: Text("Bu kategoride urun yok")),
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

      // CART BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          ).then((_) => _refreshCartCount());
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_basket_outlined,
                color: Colors.black, size: 30),
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

  Widget _buildProductCard(OtcMedicine product) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            _getCategoryIcon(widget.categoryName),
            size: 60,
            color: Colors.black87,
          ),
          Text(
            product.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            "${product.price.toStringAsFixed(0)} TL",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
      ),
    );
  }
}
