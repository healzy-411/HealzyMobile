import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Models/otcmedicine_model.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';

class ProductDetailPage extends StatelessWidget {
  final OtcMedicine product;
  final String categoryName;
  final VoidCallback? onAddToCart;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.categoryName,
    this.onAddToCart,
  });

  String? _fullUrl(String? rel) {
    if (rel == null || rel.isEmpty) return null;
    if (rel.startsWith('http')) return rel;
    return '${ApiConfig.baseUrl}$rel';
  }

  Future<void> _openProspectus(BuildContext context) async {
    final url = _fullUrl(product.prospectusUrl);
    if (url == null) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prospektüs açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _fullUrl(product.imageUrl);
    final hasProspectus =
        product.prospectusUrl != null && product.prospectusUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final sub = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, overflow: TextOverflow.ellipsis),
        elevation: 0.5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resim
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.medication,
                                size: 80, color: Colors.black54),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.medication,
                              size: 80, color: Colors.black54),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ad + kategori
            Text(
              product.name,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              categoryName,
              style: TextStyle(fontSize: 14, color: sub),
            ),
            const SizedBox(height: 16),

            // Fiyat + stok durumu
            Row(
              children: [
                Text(
                  "${product.price.toStringAsFixed(2)} TL",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                const Spacer(),
                if (product.quantity == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Stokta Yok',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  )
                else if (product.quantity > 0 && product.quantity < 5)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tükenmek Üzere',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),

            // Açıklama
            if (product.description != null &&
                product.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Açıklama',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: fg)),
              const SizedBox(height: 6),
              Text(
                product.description!,
                style: TextStyle(fontSize: 14, height: 1.5, color: fg),
              ),
            ],

            // Prospektüs
            if (hasProspectus) ...[
              const SizedBox(height: 20),
              Text('Prospektüs',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: fg)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openProspectus(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF132B44).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.55),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf,
                            color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prospektüsü Görüntüle',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: fg)),
                            const SizedBox(height: 2),
                            Text('Tarayıcıda açılır ve indirilebilir.',
                                style: TextStyle(fontSize: 14, color: sub)),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 18, color: sub),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onAddToCart != null)
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: product.quantity > 0 ? onAddToCart : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(product.quantity > 0
                      ? 'Sepete Ekle'
                      : 'Stokta Yok'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF102E4A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          const HealzyBottomNav(),
        ],
      ),
    );
  }
}
