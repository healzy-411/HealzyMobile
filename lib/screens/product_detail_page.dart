import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Models/otcmedicine_model.dart';
import 'package:healzy_app/config/api_config.dart';

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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(product.name, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              categoryName,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Fiyat + stok
            Row(
              children: [
                Text(
                  "${product.price.toStringAsFixed(2)} TL",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A79D),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: product.quantity > 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    product.quantity > 0
                        ? 'Stokta: ${product.quantity}'
                        : 'Stokta yok',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: product.quantity > 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (product.barcode != null && product.barcode!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Barkod: ${product.barcode}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace')),
            ],

            // Açıklama
            if (product.description != null &&
                product.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Açıklama',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                product.description!,
                style:
                    const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
              ),
            ],

            // Prospektüs
            if (hasProspectus) ...[
              const SizedBox(height: 20),
              const Text('Prospektüs',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openProspectus(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf,
                            color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prospektüsü Görüntüle',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text('Tarayıcıda açılır ve indirilebilir.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: onAddToCart == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: product.quantity > 0 ? onAddToCart : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(product.quantity > 0
                      ? 'Sepete Ekle'
                      : 'Stokta Yok'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A79D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
    );
  }
}
