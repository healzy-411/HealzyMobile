import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_api_service.dart';
import '../services/token_store.dart';
import 'products_page.dart';
import 'cart_page.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';

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
    baseUrl: ApiConfig.baseUrl,
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
        title: Text(widget.pharmacyName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Sepet',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ).then((_) => _refreshCartCount());
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.shopping_basket_outlined, color: fg, size: 26),
                  if (cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FutureBuilder<List<PharmacyCategoryItem>>(
          future: apiService.getPharmacyCategories(widget.pharmacyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            }
            final categories = snapshot.data ?? [];
            if (categories.isEmpty) {
              return const Center(
                  child: Text("Bu eczanede kategori bulunamadi"));
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.0,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductsPage(
                          pharmacyId: widget.pharmacyId,
                          pharmacyName: widget.pharmacyName,
                          categoryName: cat.name,
                        ),
                      ),
                    ).then((_) => _refreshCartCount());
                  },
                  child: _buildCategoryCard(
                    cat.name,
                    cat.imageUrl,
                    categoryIcons[index % categoryIcons.length],
                    cardBg,
                    cardBorder,
                    fg,
                  ),
                );
              },
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    String? imageUrl,
    IconData icon,
    Color bg,
    Color borderColor,
    Color fg,
  ) {
    final fullUrl = (imageUrl == null || imageUrl.isEmpty)
        ? null
        : (imageUrl.startsWith('http')
            ? imageUrl
            : '${ApiConfig.baseUrl}$imageUrl');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (fullUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                fullUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(icon, size: 50, color: fg),
              ),
            )
          else
            Icon(icon, size: 50, color: fg),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
