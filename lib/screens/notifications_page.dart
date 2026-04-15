import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../Models/notification_model.dart';
import '../services/notification_api_service.dart';
import '../services/order_api_service.dart';
import '../services/token_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import 'order_detail_page.dart';
import 'pharmacy_orders_page.dart';
import 'home_care_provider_requests_page.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = NotificationApiService(baseUrl: ApiConfig.baseUrl);
  final _orderApi = OrderApiService(baseUrl: ApiConfig.baseUrl);

  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _detectRole();
    _load();
  }

  void _detectRole() {
    final token = TokenStore.get();
    if (token != null && token.isNotEmpty) {
      try {
        final decoded = JwtDecoder.decode(token);
        _userRole = (decoded["role"] ??
                decoded["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])
            ?.toString();
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getMyNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllAsRead();
      await _load();
    } catch (_) {}
  }

  Future<void> _onTapNotification(NotificationModel n) async {
    if (!n.isRead) {
      await _api.markAsRead(n.id);
    }

    if (!mounted) return;

    // ====== SİPARİŞ BİLDİRİMLERİ ======
    if (n.type == 'NewOrder' && n.referenceId != null) {
      // Bu bildirim eczaciya gelir -> eczane siparis sayfasina yonlendir
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PharmacyOrdersPage()),
      );
      _load();
      return;
    }

    if (n.type == 'OrderStatusChanged' && n.referenceId != null) {
      // Bu bildirim musteriye gelir -> siparis detayina yonlendir
      try {
        final orders = await _orderApi.getMyOrders();
        final order = orders.firstWhere(
          (o) => o.orderId == n.referenceId,
          orElse: () => throw Exception("not found"),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Siparis bulunamadi.")),
        );
      }
      _load();
      return;
    }

    // ====== EVDE BAKIM BİLDİRİMLERİ ======
    if (n.type == 'NewHomeCareRequest' && n.referenceId != null) {
      // Bu bildirim saglayiciya gelir -> talepler sayfasina yonlendir
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HomeCareProviderRequestsPage()),
      );
      _load();
      return;
    }

    if (n.type == 'HomeCareRequestStatusChanged') {
      // Bu bildirim musteriye gelir -> sadece okundu isaretle
      // (home_care_page icine yonlendirme icin baseUrl lazim, simdilik snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n.body)),
      );
      _load();
      return;
    }

    _load();
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'OrderStatusChanged':
        return Icons.local_shipping;
      case 'NewOrder':
        return Icons.shopping_bag;
      case 'HomeCareRequestStatusChanged':
        return Icons.medical_services;
      case 'NewHomeCareRequest':
        return Icons.home_repair_service;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'OrderStatusChanged':
        return Colors.blue;
      case 'NewOrder':
        return Colors.green;
      case 'HomeCareRequestStatusChanged':
        return Colors.orange;
      case 'NewHomeCareRequest':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return "Az once";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk once";
    if (diff.inHours < 24) return "${diff.inHours} saat once";
    if (diff.inDays < 7) return "${diff.inDays} gun once";
    return DateFormat('dd.MM.yyyy HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? AppColors.darkGradient
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.pearlWarm, AppColors.pearl],
          );
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pearl;
    final unreadBg = isDark
        ? AppColors.midnightSoft.withValues(alpha: 0.35)
        : AppColors.pearlWarm;

    return Scaffold(
      bottomNavigationBar:
          const HealzyBottomNav(current: HealzyNavTab.notifications),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Bildirimler"),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                "Tümünü Oku",
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: titleColor),
              )
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: subColor),
                        const SizedBox(height: 12),
                        Text(
                          "Henüz bildiriminiz yok",
                          style: TextStyle(color: subColor, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                        left: 16,
                        right: 16,
                        bottom: 24,
                      ),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final iconColor = _getIconColor(n.type);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            onTap: () => _onTapNotification(n),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: n.isRead ? cardBg : unreadBg,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border
                                          .withValues(alpha: 0.6),
                                ),
                                boxShadow: AppShadows.soft(isDark),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(
                                          alpha: isDark ? 0.22 : 0.14),
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.sm),
                                    ),
                                    child: Icon(_getIcon(n.type),
                                        color: iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: TextStyle(
                                            fontWeight: n.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w700,
                                            fontSize: 14,
                                            color: titleColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: subColor,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatTime(n.createdAtUtc),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? AppColors.darkTextTertiary
                                                : AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin:
                                          const EdgeInsets.only(left: 6, top: 4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
