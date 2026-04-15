import 'package:flutter/material.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../Models/order_model.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyOrdersPage extends StatefulWidget {
  const PharmacyOrdersPage({super.key});

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
    _tabController = TabController(length: 4, vsync: this);
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
    // Not girişi dialog'u göster
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Durum: ${_statusText(newStatus)}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Musteriye iletilecek not ekleyebilirsiniz (opsiyonel):"),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: "Ornegin: Stokta yok, yarin hazir olacak...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Iptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _statusColor(newStatus),
              foregroundColor: Colors.white,
            ),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
      await _api.updateOrderStatus(orderId, newStatus, note: note);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Siparisler"),
        backgroundColor: const Color(0xFF102E4A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: "Bekleyen (${_filterByStatus(["Pending"]).length})"),
            Tab(text: "Hazırlanan (${_filterByStatus(["Preparing"]).length})"),
            Tab(text: "Hazır (${_filterByStatus(["Ready"]).length})"),
            Tab(text: "Tamamlanan (${_filterByStatus(["Dispatched","Delivered"]).length})"),
          ],
        ),
      ),
      body: _loading
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
                      emptyText: "Bekleyen siparis yok",
                    ),
                    _buildOrderList(
                      _filterByStatus(["Preparing"]),
                      emptyText: "Hazirlanan siparis yok",
                    ),
                    _buildOrderList(
                      _filterByStatus(["Ready"]),
                      emptyText: "Hazir siparis yok",
                    ),
                    _buildOrderList(
                      _filterByStatus(["Delivered", "Cancelled"]),
                      emptyText: "Tamamlanan siparis yok",
                    ),
                  ],
                ),
    );
  }

  Widget _buildOrderList(List<OrderDto> orders, {required String emptyText}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
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
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: sipariş no + durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Siparis #${order.orderId}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(order.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Müşteri adı
            if (order.customerName != null && order.customerName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      order.customerName!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // Tarih
            Text(
              "${order.createdAtUtc.day.toString().padLeft(2, '0')}."
              "${order.createdAtUtc.month.toString().padLeft(2, '0')}."
              "${order.createdAtUtc.year} "
              "${order.createdAtUtc.hour.toString().padLeft(2, '0')}:"
              "${order.createdAtUtc.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 8),

            // Ürünler
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text("${item.medicineName} x${item.quantity}"),
                      ),
                      Text("${item.lineTotal.toStringAsFixed(2)} TL"),
                    ],
                  ),
                )),

            const Divider(),

            // Teslimat adresi
            if (order.deliveryAddressSnapshot.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddressSnapshot,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

            // Ödeme bilgisi
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    order.paymentMethod == "CreditCard"
                        ? "Kredi Karti${order.cardNameSnapshot != null ? ' - ${order.cardNameSnapshot} (**** ${order.maskedCardNumberSnapshot ?? ''})' : ''}"
                        : "Kapida Odeme",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Sipariş notu
            if (order.orderNote != null && order.orderNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.message, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Siparis Notu: ${order.orderNote!}",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

            // Teslimat notu
            if (order.deliveryNote != null && order.deliveryNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.doorbell, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Teslimat: ${order.deliveryNote!}",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

            // Toplam
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Toplam:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "${order.total.toStringAsFixed(2)} TL",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            // Durum notu
            if (order.statusNote != null && order.statusNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.statusNote!,
                          style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Aksiyon butonları
            if (_getAvailableActions(order.status).isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _getAvailableActions(order.status).map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(order.orderId, action.status),
                      icon: Icon(action.icon, size: 18),
                      label: Text(action.label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_OrderAction> _getAvailableActions(String status) {
    switch (status) {
      case "Pending":
        return [
          _OrderAction("Preparing", "Hazirlaniyor", Icons.restaurant, Colors.blue),
          _OrderAction("Cancelled", "Iptal", Icons.cancel, Colors.red),
        ];
      case "Preparing":
        return [
          _OrderAction("Ready", "Hazir", Icons.check_circle, Colors.green),
          _OrderAction("Cancelled", "Iptal", Icons.cancel, Colors.red),
        ];
      case "Ready":
        return [
          _OrderAction("Delivered", "Teslim Edildi", Icons.local_shipping, const Color(0xFF102E4A)),
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
        return const Color(0xFF102E4A);
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
        return "Hazirlaniyor";
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
  final IconData icon;
  final Color color;

  _OrderAction(this.status, this.label, this.icon, this.color);
}
