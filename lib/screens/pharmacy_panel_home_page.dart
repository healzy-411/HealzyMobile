import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/pharmacy_panel_api_service.dart';
import '../services/token_store.dart';
import '../services/notification_api_service.dart';
import '../Models/order_model.dart';
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
import '../theme/theme_controller.dart';
import '../utils/error_messages.dart';

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
  List<OrderDto> _recentOrders = [];
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
    _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadUnreadCount();
      // Onaylanmamis eczane icin: admin tarafindaki onay/red durumu
      // ve yeni feedback turu degisirse mobilde otomatik yansisin.
      final isApproved = (_profile?["isApproved"] ?? false) as bool;
      if (!isApproved || _isRejected) {
        _loadRejectionStatus();
        _refreshProfileSilently();
      }
    });
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
          const SnackBar(content: Text("Geri bildirim gönderildi")),
        );
        _loadRejectionStatus();
      } else {
        final body = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body["message"] ?? "Geri bildirim gönderilemedi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      if (!mounted) return;
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
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  // Loading spinner'i tetiklemeden profile'i yeniler — onay/red status otomatik yansisin diye.
  Future<void> _refreshProfileSilently() async {
    try {
      final profile = await _api.getProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
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
        _api.getOrders().catchError((_) => <OrderDto>[]),
      ]);
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        final orders = results[2] as List<OrderDto>;
        // Son 3 siparişi al (tarihe göre desc sıralı)
        _recentOrders = orders.take(3).toList();
        _loading = false;
      });
      _autoSyncOpenStatus();
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  bool _computeShouldBeOpen({bool isOnDuty = false}) {
    if (isOnDuty) return true;
    final now = DateTime.now();
    final weekday = now.weekday;
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
    await AuthService(baseUrl: ApiConfig.baseUrl).logout();
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

  // ─────────────── BUILD ───────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : _buildContent(isDark),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: const Text("Tekrar Dene")),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final name = (_profile?["name"] as String?) ?? "Eczane";
    final isApproved = (_profile?["isApproved"] ?? false) as bool;
    final isOpen = (_profile?["isOpen"] ?? true) as bool;
    final isOnDuty = (_profile?["isOnDuty"] ?? false) as bool;
    final workingHours = (_profile?["workingHours"] as String?) ?? "";

    final todayOrders = (_summary?["todayOrderCount"] ?? 0) as int;
    final pendingOrders = (_summary?["pendingOrderCount"] ?? 0) as int;
    final todayRevenue = ((_summary?["todayRevenue"] ?? 0) as num).toDouble();
    final lowStock = (_summary?["lowStockCount"] ?? 0) as int;
    final totalProducts = (_summary?["totalProducts"] ?? 0) as int;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          _buildHeader(isDark, name),
          if (_isRejected)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _buildRejectionBanner(),
            ),
          // Acma/kapama toggle'i sadece onaylanmis + red durumunda olmayan eczanelere gosterilir.
          if (isApproved && !_isRejected)
            _buildStatusToggleCard(isDark, isOpen, isOnDuty, workingHours),
          if (!isApproved && !_isRejected) _buildApprovalBanner(isDark),
          _buildKpiGrid(isDark, todayOrders, pendingOrders, todayRevenue, totalProducts),
          _buildBentoTiles(isDark, pendingOrders, lowStock, isApproved),
          if (_recentOrders.isNotEmpty) _buildRecentOrders(isDark),
        ],
      ),
    );
  }

  // ─────────────── HEADER ───────────────

  Widget _buildHeader(bool isDark, String name) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.midnight.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hoş geldin",
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: titleC,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _headerIconButton(
            icon: Icons.notifications_outlined,
            bg: iconBg,
            fg: titleC,
            badgeCount: _unreadCount,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
              _loadUnreadCount();
            },
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            bg: iconBg,
            fg: titleC,
            onTap: () => ThemeController.I.toggle(),
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            icon: Icons.logout_rounded,
            bg: iconBg,
            fg: titleC,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: fg, size: 20),
              if (badgeCount > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── STATUS TOGGLE ───────────────

  Widget _buildStatusToggleCard(bool isDark, bool open, bool isOnDuty, String workingHours) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final statusColor = open ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final gradient = open
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          );

    final statusLabel = open ? '● AÇIK · SİPARİŞ ALINIYOR' : '● KAPALI';
    final subtitle = open
        ? (workingHours.isNotEmpty ? 'Bugün $workingHours' : 'Bugün 19:00\'a kadar')
        : 'Kapalı modda bekleniyor';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF132B44).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.power_settings_new, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnDuty ? '● NÖBETÇİ · AÇIK' : statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isOnDuty ? const Color(0xFFF59E0B) : statusColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: titleC,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Custom pill switch
            GestureDetector(
              onTap: isOnDuty ? null : _toggleOpenStatus,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  color: open
                      ? const Color(0xFF10B981)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.midnight.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      top: 2,
                      left: open ? 24 : 2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Eczaneniz henüz admin tarafından onaylanmamıştır. Onaylanınca tüm özellikler aktif olacaktır.",
                style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── KPI GRID ───────────────

  Widget _buildKpiGrid(bool isDark, int todayOrders, int pending, double revenue, int totalProducts) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);

    final kpis = [
      _Kpi(
        value: todayOrders.toString(),
        label: 'Bugünkü Sipariş',
        isHero: true,
      ),
      _Kpi(
        value: pending.toString(),
        label: 'Bekliyor',
        color: const Color(0xFFF59E0B),
      ),
      _Kpi(
        value: '₺${revenue.toStringAsFixed(0)}',
        label: 'Bugünkü Ciro',
        color: const Color(0xFF3B82F6),
      ),
      _Kpi(
        value: totalProducts.toString(),
        label: 'Ürün',
        color: const Color(0xFF10B981),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: kpis.map((k) => _kpiCard(k, isDark, titleC, muted)).toList(),
      ),
    );
  }

  Widget _kpiCard(_Kpi k, bool isDark, Color titleC, Color muted) {
    if (k.isHero) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102E4A), Color(0xFF1B4965)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              k.value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              k.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final bgAlpha = isDark ? 0.2 : 0.12;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: k.color!.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            k.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: k.color,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            k.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── BENTO TILES ───────────────

  Widget _buildBentoTiles(bool isDark, int pendingOrders, int lowStock, bool isApproved) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);

    final tiles = <_BentoTileData>[
      _BentoTileData(
        label: 'Siparişler',
        icon: Icons.inbox_outlined,
        color: const Color(0xFF3B82F6),
        sub: pendingOrders > 0 ? '$pendingOrders yeni' : 'Yok',
        onTap: () async {
          if (!isApproved) return;
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PharmacyOrdersPage()));
          _loadData();
        },
      ),
      _BentoTileData(
        label: 'Stok',
        icon: Icons.medication_outlined,
        color: const Color(0xFF10B981),
        sub: lowStock > 0 ? '$lowStock kritik' : 'Yeterli',
        onTap: () async {
          if (!isApproved) return;
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PharmacyStockPage()));
          _loadData();
        },
      ),
      _BentoTileData(
        label: 'Sigorta',
        icon: Icons.shield_outlined,
        color: const Color(0xFF8B5CF6),
        sub: 'Anlaşmalar',
        onTap: () {
          if (!isApproved) return;
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PharmacyInsurancePage()));
        },
      ),
      _BentoTileData(
        label: 'Profil',
        icon: Icons.person_outline,
        color: const Color(0xFFF59E0B),
        sub: 'Düzenle',
        onTap: () {
          if (_profile == null) return;
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => PharmacyProfilePage(profile: _profile!)));
        },
      ),
      _BentoTileData(
        label: 'Dashboard',
        icon: Icons.insights_outlined,
        color: const Color(0xFF6366F1),
        sub: 'Raporlar',
        onTap: () {
          if (!isApproved) return;
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PharmacyDashboardPage()));
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Opacity(
        opacity: isApproved ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !isApproved,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: tiles.map((t) => _bentoTile(t, isDark, titleC, muted)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _bentoTile(_BentoTileData t, bool isDark, Color titleC, Color muted) {
    return Material(
      color: isDark
          ? const Color(0xFF132B44).withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: t.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.midnight.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleC,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                t.sub,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── RECENT ORDERS ───────────────

  Widget _buildRecentOrders(bool isDark) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Son Siparişler',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleC,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PharmacyOrdersPage()),
                  );
                  _loadData();
                },
                child: Text(
                  'Tümü →',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._recentOrders.map((o) => _recentOrderCard(o, isDark, titleC, muted)),
        ],
      ),
    );
  }

  Widget _recentOrderCard(OrderDto o, bool isDark, Color titleC, Color muted) {
    final customerName = o.customerName ?? 'Müşteri';
    final firstLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : '?';
    final itemCount = o.items.length;
    final total = o.total.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.midnight.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        customerName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: titleC,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${o.orderId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '$itemCount ürün · ₺$total',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          _statusPill(o.status, isDark),
        ],
      ),
    );
  }

  Widget _statusPill(String status, bool isDark) {
    final info = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? info.darkBg : info.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: info.fg,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : info.fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'Preparing':
        return _StatusInfo('Hazırlanıyor', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8), const Color(0xFF3B82F6).withValues(alpha: 0.22));
      case 'ReadyForDelivery':
        return _StatusInfo('Teslime Hazır', const Color(0xFFE0E7FF), const Color(0xFF4338CA), const Color(0xFF6366F1).withValues(alpha: 0.22));
      case 'OutForDelivery':
        return _StatusInfo('Yolda', const Color(0xFFFFEDD5), const Color(0xFFC2410C), const Color(0xFFF59E0B).withValues(alpha: 0.24));
      case 'Delivered':
        return _StatusInfo('Teslim Edildi', const Color(0xFFD1FAE5), const Color(0xFF047857), const Color(0xFF10B981).withValues(alpha: 0.2));
      case 'Cancelled':
        return _StatusInfo('İptal', const Color(0xFFFEE2E2), const Color(0xFFB91C1C), const Color(0xFFEF4444).withValues(alpha: 0.22));
      case 'Pending':
      default:
        return _StatusInfo('Bekliyor', const Color(0xFFFEF3C7), const Color(0xFFB45309), const Color(0xFFF59E0B).withValues(alpha: 0.2));
    }
  }

  // ─────────────── REJECTION BANNER ───────────────

  Widget _buildRejectionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
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
                  "Başvurunuz reddedildi",
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
                hintText: "Geri bildiriminizi yazın...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    label: Text(_sendingFeedback ? "Gönderiliyor..." : "Gönder"),
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
                    label: const Text("Bilgileri Düzenle"),
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
                    "Hesabınız kalıcı olarak reddedilmiştir",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Bir sonraki oturum açılımınızda sisteme giriş yapamayacaksınız. Lütfen yönetici ile iletişime geçin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────── EDIT INFO DIALOG (preserved) ───────────────

  Future<void> _openEditInfoDialog() async {
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
        'pharmacyName': 'Eczane Adı', 'pharmacyDistrict': 'İlçe',
        'pharmacyAddress': 'Adres', 'pharmacyPhone': 'Eczane Telefon',
        'licenseNumber': 'Sicil Numarası', 'workingHours': 'Çalışma Saatleri',
      };

      final maxLengths = {'phone': 11, 'pharmacyPhone': 15};

      await showDialog(
        context: context,
        builder: (ctx) {
          bool saving = false;
          return StatefulBuilder(builder: (ctx, setDialogState) {
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
                          const Expanded(child: Text("Bilgilerimi Düzenle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal"))),
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
                                      : ((jsonDecode(resp.body) as Map<String, dynamic>)["message"] ?? "Hata oluştu").toString();

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
          });
        },
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        for (final c in controllers.values) {
          try { c.dispose(); } catch (_) {}
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bilgiler yüklenemedi: $e")));
    }
  }
}

class _Kpi {
  final String value;
  final String label;
  final bool isHero;
  final Color? color;

  _Kpi({required this.value, required this.label, this.isHero = false, this.color});
}

class _BentoTileData {
  final String label;
  final IconData icon;
  final Color color;
  final String sub;
  final VoidCallback onTap;

  _BentoTileData({
    required this.label,
    required this.icon,
    required this.color,
    required this.sub,
    required this.onTap,
  });
}

class _StatusInfo {
  final String label;
  final Color bg;
  final Color fg;
  final Color darkBg;

  _StatusInfo(this.label, this.bg, this.fg, this.darkBg);
}
