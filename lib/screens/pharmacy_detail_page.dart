import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Models/review_model.dart';
import '../services/review_api_service.dart';
import 'categories_page.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';

class PharmacyDetailPage extends StatefulWidget {
  final int pharmacyId;

  const PharmacyDetailPage({super.key, required this.pharmacyId});

  @override
  State<PharmacyDetailPage> createState() => _PharmacyDetailPageState();
}

class _PharmacyDetailPageState extends State<PharmacyDetailPage> {
  final _api = ReviewApiService(baseUrl: ApiConfig.baseUrl);

  PharmacyDetailModel? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getPharmacyDetail(widget.pharmacyId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  Widget _buildStars(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (i < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return Scaffold(
        bottomNavigationBar: const HealzyBottomNav(),
        appBar: AppBar(
          title: const Text("Eczane Detay"),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.lightPageGradient,
            color: isDark ? AppColors.darkBg : null,
          ),
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF102E4A))),
        ),
      );
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        bottomNavigationBar: const HealzyBottomNav(),
        appBar: AppBar(
          title: const Text("Eczane Detay"),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.lightPageGradient,
            color: isDark ? AppColors.darkBg : null,
          ),
          child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? "Bir hata olustu", style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Tekrar Dene")),
            ],
          ),
        ),
        ),
      );
    }

    final d = _detail!;
    final baseUrl = ApiConfig.baseUrl;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: Text(d.name),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // Eczane Gorseli
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: d.imageUrl != null && d.imageUrl!.isNotEmpty
                  ? Image.network(
                      d.imageUrl!.startsWith('http') ? d.imageUrl! : '$baseUrl${d.imageUrl}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.local_pharmacy, size: 80, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.local_pharmacy, size: 80, color: Colors.grey),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eczane Adi
                  Text(
                    d.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: [
                      _buildStars(d.averageRating, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        d.averageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "(${d.reviewCount} değerlendirme)",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bilgiler
                  _infoRow(Icons.location_on, "${d.district}, ${d.address}"),
                  _infoRow(Icons.phone, d.phone, onTap: () {
                    launchUrl(Uri.parse('tel:${d.phone}'));
                  }),
                  _infoRow(Icons.access_time, d.workingHours),
                  const SizedBox(height: 16),

                  // Kapalı eczane badge
                  if (!d.isOpen)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_clock, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "Bu eczane şu an kapalı",
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // Mağazaya Git Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: d.isOpen
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CategoriesPage(
                                    pharmacyId: d.pharmacyId,
                                    pharmacyName: d.name,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(d.isOpen ? "Mağazaya Git" : "Eczane Kapalı"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF102E4A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Degerlendirmeler
                  const Text(
                    "Değerlendirmeler",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (d.recentReviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          "Henüz değerlendirme yok",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...d.recentReviews.map((r) => _buildReviewCard(r)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewDto review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? null : AppColors.lightBlueSoft.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF102E4A).withValues(alpha: 0.15),
                  child: Text(
                    review.userFirstName.isNotEmpty ? review.userFirstName[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: Color(0xFF102E4A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  review.userFirstName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.yyyy').format(review.createdAtUtc.toLocal()),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildStars(review.rating.toDouble(), size: 16),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.comment!, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
