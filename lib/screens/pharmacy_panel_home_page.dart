import 'dart:async';
import 'package:flutter/material.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../services/token_store.dart';
import '../services/notification_api_service.dart';
import 'pharmacy_dashboard_page.dart';
import 'pharmacy_orders_page.dart';
import 'pharmacy_profile_page.dart';
import 'pharmacy_stock_page.dart';
import 'pharmacy_insurance_page.dart';
import 'notifications_page.dart';
import 'auth_page.dart';
import '../services/auth_service.dart';

class PharmacyPanelHomePage extends StatefulWidget {
  const PharmacyPanelHomePage({super.key});

  @override
  State<PharmacyPanelHomePage> createState() => _PharmacyPanelHomePageState();
}

class _PharmacyPanelHomePageState extends State<PharmacyPanelHomePage> {
  final _api = PharmacyPanelApiService(baseUrl: "http://localhost:5009");
  final _notifApi = NotificationApiService(baseUrl: "http://localhost:5009");

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getProfile(),
        _api.getSummary(),
      ]);
      setState(() {
        _profile = results[0];
        _summary = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  void _logout() {
    TokenStore.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthPage(
          authService: AuthService(baseUrl: "http://localhost:5009"),
          customerHome: const SizedBox(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Eczane Paneli"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  );
                  _loadUnreadCount();
                },
                tooltip: "Bildirimler",
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      _unreadCount > 9 ? "9+" : "$_unreadCount",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Yenile",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Cikis Yap",
          ),
        ],
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
                      ElevatedButton(onPressed: _loadData, child: const Text("Tekrar Dene")),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final name = _profile?["name"] ?? "Eczane";
    final isApproved = _profile?["isApproved"] ?? false;

    final pendingOrders = (_summary?["pendingOrderCount"] ?? 0) as int;
    final todayRevenue = (_summary?["todayRevenue"] ?? 0).toDouble();
    final todayOrders = (_summary?["todayOrderCount"] ?? 0) as int;
    final lowStock = (_summary?["lowStockCount"] ?? 0) as int;
    final totalProducts = (_summary?["totalProducts"] ?? 0) as int;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Eczane adı + onay
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF00A79D),
                child: Icon(Icons.local_pharmacy, color: Colors.white),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Row(
                children: [
                  Icon(
                    isApproved ? Icons.check_circle : Icons.hourglass_top,
                    size: 16,
                    color: isApproved ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isApproved ? "Onayli" : "Onay Bekliyor",
                    style: TextStyle(
                      color: isApproved ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isApproved)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Eczaneniz henuz admin tarafindan onaylanmamistir.",
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Anlık özet kartları
          Row(
            children: [
              _summaryBadge(
                "$pendingOrders",
                "Bekleyen",
                Icons.hourglass_top,
                pendingOrders > 0 ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              _summaryBadge(
                "${todayRevenue.toStringAsFixed(0)} TL",
                "Bugun",
                Icons.attach_money,
                const Color(0xFF00A79D),
              ),
              const SizedBox(width: 8),
              _summaryBadge(
                "$todayOrders",
                "Siparis",
                Icons.receipt,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryBadge(
                "$totalProducts",
                "Urun",
                Icons.medication,
                Colors.purple,
              ),
              const SizedBox(width: 8),
              _summaryBadge(
                "$lowStock",
                "Dusuk Stok",
                Icons.warning_amber,
                lowStock > 0 ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 20),

          // Menü kartları
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _menuCard(
                icon: Icons.dashboard,
                label: "Dashboard",
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyDashboardPage())),
              ),
              _menuCard(
                icon: Icons.receipt_long,
                label: "Siparisler",
                color: const Color(0xFF00A79D),
                badge: pendingOrders > 0 ? "$pendingOrders" : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyOrdersPage())),
              ),
              _menuCard(
                icon: Icons.inventory_2,
                label: "Stok Yonetimi",
                color: Colors.purple,
                badge: lowStock > 0 ? "$lowStock" : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyStockPage())),
              ),
              _menuCard(
                icon: Icons.health_and_safety,
                label: "Sigortalar",
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyInsurancePage())),
              ),
              _menuCard(
                icon: Icons.store,
                label: "Eczane Bilgileri",
                color: const Color(0xFF004D40),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacyProfilePage(profile: _profile!))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: color),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
