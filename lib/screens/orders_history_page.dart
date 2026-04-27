import 'package:flutter/material.dart';

import '../Models/order_model.dart';
import '../services/order_api_service.dart';
import 'order_detail_page.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../widgets/skeleton_shimmer.dart';
import '../theme/app_colors.dart';

class OrdersHistoryPage extends StatefulWidget {
  final String baseUrl;

  const OrdersHistoryPage({super.key, required this.baseUrl});

  @override
  State<OrdersHistoryPage> createState() => _OrdersHistoryPageState();
}

class _OrdersHistoryPageState extends State<OrdersHistoryPage> {
  late final OrderApiService _api;
  bool _loading = true;
  String? _error;
  List<OrderDto> _orders = [];

  @override
  void initState() {
    super.initState();
    _api = OrderApiService(baseUrl: widget.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getMyOrders();
      if (!mounted) return;
      setState(() => _orders = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: titleColor,
        title: const Text("Geçmiş Siparişlerim"),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? ListView(
                  padding: EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 16),
                  children: const [
                    OrderCardSkeleton(),
                    OrderCardSkeleton(),
                    OrderCardSkeleton(),
                    OrderCardSkeleton(),
                  ],
                )
              : (_error != null)
                  ? ListView(
                      children: [
                        SizedBox(height: kToolbarHeight + 40),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _load,
                                  child: const Text("Tekrar Dene"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : (_orders.isEmpty)
                      ? ListView(
                          children: [
                            SizedBox(height: kToolbarHeight + 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text("Henuz siparis yok", style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 16),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) {
                            final o = _orders[i];
                            final date = o.createdAtUtc;
                            final dateText =
                                "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} "
                                "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final cardBg = isDark
                                ? const Color(0xFF132B44).withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.55);
                            final cardBorder = isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.55);
                            final subColor = isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder, width: 0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderDetailPage(
                                        baseUrl: widget.baseUrl,
                                        order: o,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Siparis #${o.orderId}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          _statusLabel(o.status),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: subColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      o.pharmacyName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Toplam: ${o.total.toStringAsFixed(2)} TL",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: subColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return 'Beklemede';
      case 'preparing': return 'Hazirlaniyor';
      case 'ready': return 'Hazir';
      case 'dispatched': return 'Yolda';
      case 'delivered': return 'Teslim Edildi';
      case 'cancelled':
      case 'canceled': return 'Iptal Edildi';
      default: return s;
    }
  }
}

