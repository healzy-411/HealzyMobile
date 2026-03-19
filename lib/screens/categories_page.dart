import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'products_page.dart';

class CategoriesPage extends StatelessWidget {
  final int pharmacyId;
  final String pharmacyName;

  CategoriesPage({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  final ApiService apiService = ApiService();

  // 🎯 Sabit ikon listesi (UI bozulmasın diye)
  final List<IconData> categoryIcons = [
    Icons.medication_liquid,
    Icons.face_retouching_natural,
    Icons.healing,
    Icons.clean_hands,
    Icons.child_care,
    Icons.pets,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ================= ÜST BAŞLIK =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              color: Colors.grey[300],
              child: Text(
                pharmacyName,
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
            ),

            // ================= KATEGORİLER =================
            Expanded(
              child: FutureBuilder<List<String>>(
                future: apiService.getPharmacyCategories(pharmacyId),
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
                      child: Text("Bu eczanede kategori bulunamadı"),
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
                                pharmacyId: pharmacyId,
                                categoryName: categoryName,
                              ),
                            ),
                          );
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

      // ================= GERİ BUTONU =================
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: FloatingActionButton.small(
          backgroundColor: Colors.white,
          elevation: 2,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
    );
  }

  // ================= KATEGORİ KARTI =================
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
