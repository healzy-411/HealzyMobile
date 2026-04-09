import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/token_store.dart';
import 'products_page.dart';
import 'cart_page.dart';

class CategoriesPage extends StatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const CategoriesPage({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final ApiService apiService = ApiService();
  late final CartApiService cartApi = CartApiService(
    baseUrl: 'http://localhost:5009',
    getToken: () async => TokenStore.get(),
  );

  int cartCount = 0;

  final List<IconData> categoryIcons = [
    Icons.medication_liquid,
    Icons.face_retouching_natural,
    Icons.healing,
    Icons.clean_hands,
    Icons.child_care,
    Icons.pets,
  ];

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  Future<void> _refreshCartCount() async {
    try {
      final c = await cartApi.getMyCart();
      if (!mounted) return;
      setState(() => cartCount = c.items.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ================= UST BASLIK =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              color: Colors.grey[300],
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
                    widget.pharmacyName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================= KATEGORILER =================
            Expanded(
              child: FutureBuilder<List<String>>(
                future: apiService.getPharmacyCategories(widget.pharmacyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Hata: ${snapshot.error}"),
                    );
                  }

                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return const Center(
                      child: Text("Bu eczanede kategori bulunamadi"),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final categoryName = categories[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductsPage(
                                pharmacyId: widget.pharmacyId,
                                pharmacyName: widget.pharmacyName,
                                categoryName: categoryName,
                              ),
                            ),
                          ).then((_) => _refreshCartCount());
                        },
                        child: _buildCategoryCard(
                          categoryName,
                          categoryIcons[index % categoryIcons.length],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ================= SEPET BUTONU =================
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
              ),
          ],
        ),
      ),
    );
  }

  // ================= KATEGORI KARTI =================
  Widget _buildCategoryCard(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.black87),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
