import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/pharmacy_panel_api_service.dart';
import '../services/token_store.dart';
import '../services/notification_api_service.dart';
import '../services/local_notification_service.dart';
import 'pharmacy_dashboard_page.dart';
import 'pharmacy_orders_page.dart';
import 'pharmacy_profile_page.dart';
import 'pharmacy_stock_page.dart';
import 'pharmacy_insurance_page.dart';
import 'notifications_page.dart';
import 'auth_page.dart';
import 'home_page.dart';
import '../services/auth_service.dart';
import 'package:healzy_app/config/api_config.dart';
import '../theme/app_colors.dart';

class PharmacyPanelHomePage extends StatefulWidget {
  const PharmacyPanelHomePage({super.key});

  @override
  State<PharmacyPanelHomePage> createState() => _PharmacyPanelHomePageState();
}

class _PharmacyPanelHomePageState extends State<PharmacyPanelHomePage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);
  final _notifApi = NotificationApiService(baseUrl: ApiConfig.baseUrl);

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  Timer? _notifTimer;
  Timer? _heartbeatTimer;
  Timer? _openCloseTimer;

  // Rejection state
  bool _isRejected = false;
  String? _rejectionNote;
  int _rejectionCount = 0;
  bool _canSubmitFeedback = false;
  final _feedbackController = TextEditingController();
  bool _sendingFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _loadRejectionStatus();
    _sendHeartbeat();
    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sendHeartbeat());
    _openCloseTimer = Timer.periodic(const Duration(minutes: 1), (_) => _autoSyncOpenStatus());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _heartbeatTimer?.cancel();
    _openCloseTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendHeartbeat() async {
    try {
      final token = TokenStore.get();
      if (token == null) return;
      await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/auth/heartbeat"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (_) {}
  }

  Future<void> _loadRejectionStatus() async {
    try {
      final token = TokenStore.get();
      if (token == null) return;
      final resp = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/pharmacy-panel/rejection-status"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _isRejected = data["isRejected"] ?? false;
          _rejectionNote = data["rejectionNote"] as String?;
          _rejectionCount = (data["rejectionCount"] ?? 0) as int;
          _canSubmitFeedback = data["canSubmitFeedback"] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sendingFeedback = true);
    try {
      final token = TokenStore.get();
      final resp = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/pharmacy-panel/feedback"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"message": message}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _feedbackController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geri bildirim gonderildi")),
        );
        _loadRejectionStatus();
      } else {
        final body = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body["message"] ?? "Geri bildirim gonderilemedi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      if (!mounted) return;

      if (count > _unreadCount && _unreadCount >= 0) {
        final notifications = await _notifApi.getMyNotifications(page: 1, pageSize: count - _unreadCount);
        for (final n in notifications.where((n) => !n.isRead)) {
          await LocalNotificationService.I.showNow(
            id: n.id,
            title: n.title,
            body: n.body,
          );
        }
      }

      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _toggleOpenStatus() async {
    try {
      final result = await _api.toggleStatus();
      if (!mounted) return;
      setState(() {
        _profile = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
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
      _autoSyncOpenStatus();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  bool _computeShouldBeOpen({bool isOnDuty = false}) {
    if (isOnDuty) return true;
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon .. 7=Sun
    if (weekday == DateTime.sunday) return false;
    final mins = now.hour * 60 + now.minute;
    const openAt = 8 * 60 + 30;
    const closeAt = 19 * 60;
    return mins >= openAt && mins < closeAt;
  }

  Future<void> _autoSyncOpenStatus() async {
    if (_profile == null) return;
    final isOnDuty = (_profile!['isOnDuty'] ?? false) as bool;
    final isOpen = (_profile!['isOpen'] ?? true) as bool;
    final shouldOpen = _computeShouldBeOpen(isOnDuty: isOnDuty);
    if (isOpen == shouldOpen) return;
    try {
      final result = await _api.toggleStatus();
      if (!mounted) return;
      setState(() => _profile = result);
    } catch (_) {}
  }

  Future<void> _logout() async {
    try {
      final token = TokenStore.get();
      if (token != null) {
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/api/auth/logout"),
          headers: {"Authorization": "Bearer $token"},
        );
      }
    } catch (_) {}
    await TokenStore.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthPage(
          authService: AuthService(baseUrl: ApiConfig.baseUrl),
          customerHome: const HomePage(),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.midnight,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : Colors.white,
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
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark ? null : AppColors.lightPageGradient,
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBg : null,
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
                      ElevatedButton(onPressed: _loadData, child: const Text("Tekrar Dene")),
                    ],
                  ),
                )
              : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final name = _profile?["name"] ?? "Eczane";
    final isApproved = _profile?["isApproved"] ?? false;
    final isOpen = _profile?["isOpen"] ?? true;
    final isOnDuty = (_profile?["isOnDuty"] ?? false) as bool;

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
          // Rejection banner
          if (_isRejected) _buildRejectionBanner(),

          // Eczane adı + onay + acik/kapali toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isOpen ? AppColors.midnight : Colors.grey,
                        child: const Icon(Icons.local_pharmacy, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                if (isOnDuty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Text("NÖBETÇİ",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  isApproved ? Icons.check_circle : Icons.hourglass_top,
                                  size: 14,
                                  color: isApproved ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isApproved ? "Onaylı" : "Onay Bekliyor",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isApproved ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOpen ? Icons.store : Icons.store_outlined,
                          size: 20,
                          color: isOpen ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOpen ? "Eczane Açık" : "Eczane Kapalı",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isOpen ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: isOpen,
                          activeColor: Colors.green,
                          onChanged: isOnDuty ? null : (_) => _toggleOpenStatus(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isApproved && !_isRejected)
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
                  Icon(Icons.hourglass_top, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Eczaneniz henuz admin tarafindan onaylanmamistir. Onaylaninca tum ozellikler aktif olacaktir.",
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          _buildFeatures(pendingOrders, todayRevenue, todayOrders, lowStock, totalProducts, isApproved),
        ],
      ),
    );
  }

  Widget _buildFeatures(int pendingOrders, double todayRevenue, int todayOrders, int lowStock, int totalProducts, bool isApproved) {
    final menuGrid = GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _menuCard(icon: Icons.dashboard, label: "Dashboard", color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyDashboardPage()))),
            _menuCard(icon: Icons.receipt_long, label: "Siparisler", color: AppColors.midnight,
              badge: pendingOrders > 0 ? "$pendingOrders" : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyOrdersPage()))),
            _menuCard(icon: Icons.inventory_2, label: "Stok Yonetimi", color: Colors.purple,
              badge: lowStock > 0 ? "$lowStock" : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyStockPage()))),
            _menuCard(icon: Icons.health_and_safety, label: "Sigortalar", color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyInsurancePage()))),
            _menuCard(icon: Icons.store, label: "Eczane Bilgileri", color: const Color(0xFF004D40),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacyProfilePage(profile: _profile!)))),
          ],
        );

    return Column(
      children: [
        Row(
          children: [
            _summaryBadge("$pendingOrders", "Bekleyen", Icons.hourglass_top, pendingOrders > 0 ? Colors.orange : Colors.grey),
            const SizedBox(width: 8),
            _summaryBadge("${todayRevenue.toStringAsFixed(0)} TL", "Bugun", Icons.currency_lira, AppColors.midnight),
            const SizedBox(width: 8),
            _summaryBadge("$todayOrders", "Sipariş", Icons.receipt, Colors.blue),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _summaryBadge("$totalProducts", "Ürün", Icons.medication, Colors.purple),
            const SizedBox(width: 8),
            _summaryBadge("$lowStock", "Dusuk Stok", Icons.warning_amber, lowStock > 0 ? Colors.red : Colors.grey),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 20),
        if (isApproved)
          menuGrid
        else
          IgnorePointer(
            child: Opacity(
              opacity: 0.5,
              child: menuGrid,
            ),
          ),
      ],
    );
  }

  Widget _buildRejectionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Basvurunuz reddedildi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${_rejectionCount > 3 ? 3 : _rejectionCount}/3",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (_rejectionNote != null && _rejectionNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rejectionNote!,
                style: TextStyle(fontSize: 14, color: Colors.red.shade900),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_canSubmitFeedback) ...[
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Geri bildiriminizi yazin...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendingFeedback ? null : _submitFeedback,
                    icon: _sendingFeedback
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, size: 18),
                    label: Text(_sendingFeedback ? "Gonderiliyor..." : "Gonder", style: const TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openEditInfoDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Bilgilerimi Duzenle", style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_rejectionCount >= 3) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 24),
                  SizedBox(height: 6),
                  Text(
                    "Hesabiniz kalici olarak reddedilmistir",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Bir sonraki oturum aciliminizda sisteme giris yapamayacaksiniz. Lutfen yonetici ile iletisime gecin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditInfoDialog() async {
    // Kayit bilgilerini cek
    try {
      final token = TokenStore.get();
      if (token == null) return;
      final resp = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/pharmacy-panel/registration-info"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (resp.statusCode != 200) return;
      final info = jsonDecode(resp.body) as Map<String, dynamic>;

      if (!mounted) return;

      final controllers = {
        'firstName': TextEditingController(text: info['firstName'] ?? ''),
        'lastName': TextEditingController(text: info['lastName'] ?? ''),
        'phone': TextEditingController(text: (info['phone'] ?? '').toString().length > 11 ? (info['phone'] ?? '').toString().substring(0, 11) : (info['phone'] ?? '')),
        'pharmacyName': TextEditingController(text: info['pharmacyName'] ?? ''),
        'pharmacyDistrict': TextEditingController(text: info['pharmacyDistrict'] ?? ''),
        'pharmacyAddress': TextEditingController(text: info['pharmacyAddress'] ?? ''),
        'pharmacyPhone': TextEditingController(text: info['pharmacyPhone'] ?? ''),
        'licenseNumber': TextEditingController(text: info['licenseNumber'] ?? ''),
        'workingHours': TextEditingController(text: info['workingHours'] ?? ''),
      };

      final labels = {
        'firstName': 'Ad', 'lastName': 'Soyad', 'phone': 'Telefon',
        'pharmacyName': 'Eczane Adi', 'pharmacyDistrict': 'Ilce',
        'pharmacyAddress': 'Adres', 'pharmacyPhone': 'Eczane Telefon',
        'licenseNumber': 'Sicil Numarasi', 'workingHours': 'Calisma Saatleri',
      };

      final maxLengths = { 'phone': 11, 'pharmacyPhone': 15 };

      await showDialog(
        context: context,
        builder: (ctx) {
          bool saving = false;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Expanded(child: Text("Bilgilerimi Duzenle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: controllers.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: e.value,
                                  maxLength: maxLengths[e.key],
                                  keyboardType: (e.key == 'phone' || e.key == 'pharmacyPhone') ? TextInputType.phone : TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: labels[e.key] ?? e.key,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    counterText: maxLengths.containsKey(e.key) ? null : '',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Iptal"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: saving ? null : () async {
                                  setDialogState(() => saving = true);
                                  try {
                                    final body = {
                                      'firstName': controllers['firstName']!.text.trim(),
                                      'lastName': controllers['lastName']!.text.trim(),
                                      'phone': controllers['phone']!.text.trim(),
                                      'pharmacyName': controllers['pharmacyName']!.text.trim(),
                                      'pharmacyDistrict': controllers['pharmacyDistrict']!.text.trim(),
                                      'pharmacyAddress': controllers['pharmacyAddress']!.text.trim(),
                                      'pharmacyPhone': controllers['pharmacyPhone']!.text.trim(),
                                      'licenseNumber': controllers['licenseNumber']!.text.trim(),
                                      'workingHours': controllers['workingHours']!.text.trim(),
                                    };
                                    final resp = await http.put(
                                      Uri.parse("${ApiConfig.baseUrl}/api/pharmacy-panel/update-info"),
                                      headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
                                      body: jsonEncode(body),
                                    );
                                    final success = resp.statusCode == 200;
                                    final msg = success
                                        ? "Bilgileriniz kaydedildi"
                                        : ((jsonDecode(resp.body) as Map<String, dynamic>)["message"] ?? "Hata olustu").toString();

                                    if (ctx.mounted) Navigator.pop(ctx);

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(msg)));
                                    if (success) {
                                      _loadRejectionStatus();
                                      _loadData();
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(e.toString())));
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                child: saving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text("Kaydet", style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      // Controllers dispose - dialog kapandiktan sonra guvenli
      Future.delayed(const Duration(milliseconds: 100), () {
        for (final c in controllers.values) {
          try { c.dispose(); } catch (_) {}
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bilgiler yuklenemedi: $e")),
      );
    }
  }
}
