import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../Models/order_model.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyOrdersPage extends StatefulWidget {
  final int initialTabIndex;
  const PharmacyOrdersPage({super.key, this.initialTabIndex = 0});

  @override
  State<PharmacyOrdersPage> createState() => _PharmacyOrdersPageState();
}

class _PharmacyOrdersPageState extends State<PharmacyOrdersPage>
    with SingleTickerProviderStateMixin {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);

  late TabController _tabController;
  List<OrderDto> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _api.getOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  List<OrderDto> _filterByStatus(List<String> statuses) {
    return _orders.where((o) => statuses.contains(o.status)).toList();
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      await _api.updateOrderStatus(orderId, newStatus, note: null);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Siparis durumu guncellendi: ${_statusText(newStatus)}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.midnight;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: const Text("Siparişler"),
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.lightPageGradient,
            color: isDark ? AppColors.darkBg : null,
          ),
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: fg,
          unselectedLabelColor: fg.withValues(alpha: 0.55),
          indicatorColor: fg,
          tabs: [
            Tab(text: "Bekleyen (${_filterByStatus(["Pending"]).length})"),
            Tab(text: "Hazırlanıyor (${_filterByStatus(["Preparing"]).length})"),
            Tab(text: "Hazır (${_filterByStatus(["Ready"]).length})"),
            Tab(text: "Yolda (${_filterByStatus(["Dispatched"]).length})"),
            Tab(text: "Tamamlanan (${_filterByStatus(["Delivered"]).length})"),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text("Tekrar Dene"),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(
                        _filterByStatus(["Pending"]),
                        emptyText: "Bekleyen sipariş yok",
                      ),
                      _buildOrderList(
                        _filterByStatus(["Preparing"]),
                        emptyText: "Hazırlanan sipariş yok",
                      ),
                      _buildOrderList(
                        _filterByStatus(["Ready"]),
                        emptyText: "Hazır sipariş yok",
                      ),
                      _buildOrderList(
                        _filterByStatus(["Dispatched"]),
                        emptyText: "Yolda sipariş yok",
                      ),
                      _buildOrderList(
                        _filterByStatus(["Delivered", "Cancelled"]),
                        emptyText: "Tamamlanan sipariş yok",
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderDto> orders, {required String emptyText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey[600]!;
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: muted, fontSize: 14)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) => _orderCard(orders[index]),
      ),
    );
  }

  Widget _orderCard(OrderDto order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.midnight.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: sipariş no + durum
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sipariş #${order.orderId}",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleC),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusText(order.status),
                  style: TextStyle(
                    color: isDark ? Colors.white : statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          if (order.customerName != null && order.customerName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    order.customerName!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleC),
                  ),
                ],
              ),
            ),

          Text(
            "${order.createdAtUtc.day.toString().padLeft(2, '0')}."
            "${order.createdAtUtc.month.toString().padLeft(2, '0')}."
            "${order.createdAtUtc.year} "
            "${order.createdAtUtc.hour.toString().padLeft(2, '0')}:"
            "${order.createdAtUtc.minute.toString().padLeft(2, '0')}",
            style: TextStyle(color: muted, fontSize: 13),
          ),

          const SizedBox(height: 8),

          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${item.medicineName} x${item.quantity}",
                        style: TextStyle(color: titleC, fontSize: 14),
                      ),
                    ),
                    Text(
                      "${item.lineTotal.toStringAsFixed(2)} TL",
                      style: TextStyle(color: titleC, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),

          Divider(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),

          if (order.deliveryAddressSnapshot.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 16, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddressSnapshot,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.payment, size: 16, color: muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.paymentMethod == "CreditCard"
                        ? "Kredi Kartı${order.cardNameSnapshot != null ? ' - ${order.cardNameSnapshot} (**** ${order.maskedCardNumberSnapshot ?? ''})' : ''}"
                        : "Kapıda Ödeme",
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
              ],
            ),
          ),

          if (order.orderNote != null && order.orderNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.message, size: 16, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Sipariş Notu: ${order.orderNote!}",
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                ],
              ),
            ),

          if (order.deliveryNote != null && order.deliveryNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.doorbell, size: 16, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Teslimat: ${order.deliveryNote!}",
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Toplam:", style: TextStyle(fontWeight: FontWeight.w600, color: titleC)),
              Text(
                "${order.total.toStringAsFixed(2)} TL",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: titleC),
              ),
            ],
          ),

          if (order.statusNote != null && order.statusNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.statusNote!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_getAvailableActions(order.status).isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _getAvailableActions(order.status).map((action) {
                final style = ElevatedButton.styleFrom(
                  backgroundColor: action.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                );
                final onPressed = () => _updateStatus(order.orderId, action.status);
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: action.icon == null
                      ? ElevatedButton(
                          onPressed: onPressed,
                          style: style,
                          child: Text(action.label),
                        )
                      : ElevatedButton.icon(
                          onPressed: onPressed,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                          style: style,
                        ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<_OrderAction> _getAvailableActions(String status) {
    switch (status) {
      case "Pending":
        return [
          _OrderAction("Preparing", "Onayla", null, Colors.blue),
          _OrderAction("Cancelled", "Iptal", Icons.cancel, Colors.red),
        ];
      case "Preparing":
        return [
          _OrderAction("Ready", "Hazir", Icons.check_circle, Colors.green),
          _OrderAction("Cancelled", "Iptal", Icons.cancel, Colors.red),
        ];
      case "Ready":
        return [
          _OrderAction("Delivered", "Teslim Edildi", Icons.local_shipping, AppColors.midnight),
        ];
      default:
        return [];
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Preparing":
        return Colors.blue;
      case "Ready":
        return Colors.green;
      case "Delivered":
        return AppColors.midnight;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "Pending":
        return "Bekliyor";
      case "Preparing":
        return "Hazırlanıyor";
      case "Ready":
        return "Hazir";
      case "Delivered":
        return "Teslim Edildi";
      case "Cancelled":
        return "Iptal Edildi";
      default:
        return status;
    }
  }
}

class _OrderAction {
  final String status;
  final String label;
  final IconData? icon;
  final Color color;

  _OrderAction(this.status, this.label, this.icon, this.color);
}
