import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/home_care_panel_api_service.dart';
import '../services/token_store.dart';
import '../theme/app_colors.dart';
import '../services/notification_api_service.dart';
import '../services/local_notification_service.dart';
import 'home_care_provider_requests_page.dart';
import 'home_care_provider_profile_page.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'auth_page.dart';
import '../services/auth_service.dart';
import 'package:healzy_app/config/api_config.dart';
import '../theme/theme_controller.dart';
import '../widgets/accept_with_employee_dialog.dart';

class HomeCareProviderPanelHomePage extends StatefulWidget {
  const HomeCareProviderPanelHomePage({super.key});

  @override
  State<HomeCareProviderPanelHomePage> createState() => _HomeCareProviderPanelHomePageState();
}

class _HomeCareProviderPanelHomePageState extends State<HomeCareProviderPanelHomePage> {
  final _api = HomeCarePanelApiService(baseUrl: ApiConfig.baseUrl);
  final _notifApi = NotificationApiService(baseUrl: ApiConfig.baseUrl);

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _recentRequests = [];
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  int _lastPushedNotifId = 0;
  bool _notifBaselineSet = false;
  Timer? _notifTimer;
  Timer? _heartbeatTimer;

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
    _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadUnreadCount());
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sendHeartbeat());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _heartbeatTimer?.cancel();
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
        Uri.parse("${ApiConfig.baseUrl}/api/home-care-panel/rejection-status"),
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
        Uri.parse("${ApiConfig.baseUrl}/api/home-care-panel/feedback"),
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
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      final recent = await _notifApi.getMyNotifications(page: 1, pageSize: 10);
      if (!mounted) return;

      if (!_notifBaselineSet) {
        _lastPushedNotifId = recent.isNotEmpty
            ? recent.map((n) => n.id).reduce((a, b) => a > b ? a : b)
            : 0;
        _notifBaselineSet = true;
      } else {
        final newOnes = recent.where((n) => n.id > _lastPushedNotifId).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        for (final n in newOnes) {
          await LocalNotificationService.I.showNow(
            id: n.id,
            title: n.title,
            body: n.body,
          );
          _lastPushedNotifId = n.id;
        }
      }

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
        _api.getRequests().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        final allRequests = results[2] as List<Map<String, dynamic>>;
        // Pending ve accepted olanları üstte tut, son 3 göster
        final sorted = List<Map<String, dynamic>>.from(allRequests);
        sorted.sort((a, b) {
          final aStatus = (a['status'] ?? '').toString().toLowerCase();
          final bStatus = (b['status'] ?? '').toString().toLowerCase();
          final aOrder = aStatus == 'pending' ? 0 : (aStatus == 'accepted' ? 1 : 2);
          final bOrder = bStatus == 'pending' ? 0 : (bStatus == 'accepted' ? 1 : 2);
          return aOrder.compareTo(bOrder);
        });
        _recentRequests = sorted.take(3).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  Future<void> _acceptRequest(int id) async {
    final ok = await showAcceptWithEmployeeDialog(
      context: context,
      api: _api,
      requestId: id,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talep onaylandi ve calisan atandi')),
      );
      _loadData();
    }
  }

  Future<void> _rejectRequest(int id) async {
    try {
      await _api.updateRequestStatus(id, 'rejected');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talep reddedildi')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
    final name = (_profile?["name"] as String?) ?? "Sağlayıcı";
    final district = (_profile?["district"] as String?) ?? "";
    final isActive = (_profile?["isActive"] ?? true) as bool;
    final isApproved = (_profile?["isApproved"] ?? false) as bool;

    final pendingRequests = (_summary?["pendingRequestCount"] ?? 0) as int;
    final todayRequests = (_summary?["todayRequestCount"] ?? 0) as int;
    final acceptedRequests = (_summary?["acceptedRequestCount"] ?? 0) as int;
    // todayEarnings API'de yoksa accepted * 350 gibi fallback kullanma, 0 göster
    final todayEarnings = ((_summary?["todayEarnings"] ?? 0) as num).toDouble();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          _buildHeader(isDark, name, district, isActive),
          if (_isRejected)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _buildRejectionBanner(),
            ),
          _buildEarningsHero(todayEarnings, acceptedRequests, pendingRequests, todayRequests),
          if (!isApproved && !_isRejected) _buildApprovalBanner(),
          _buildBentoTiles(isDark, pendingRequests, isApproved),
          if (_recentRequests.isNotEmpty) _buildPendingRequests(isDark),
        ],
      ),
    );
  }

  // ─────────────── HEADER ───────────────

  Widget _buildHeader(bool isDark, String name, String district, bool isActive) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.midnight.withValues(alpha: 0.06);

    final initials = _getInitials(name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hoş geldin",
                  style: TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w500),
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
                if (district.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '● Sağlayıcı · $district',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? const Color(0xFF10B981) : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _headerIconButton(
            icon: Icons.notifications_outlined,
            bg: iconBg,
            fg: titleC,
            badge: _unreadCount > 0,
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
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _headerIconButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    bool badge = false,
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
              if (badge)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── EARNINGS HERO ───────────────

  Widget _buildEarningsHero(double earnings, int accepted, int pending, int todayCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF1B4965)],
              stops: [0.0, 0.6, 1.4],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Radial highlight
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BUGÜNKÜ KAZANÇ',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    earnings > 0 ? '₺${earnings.toStringAsFixed(0)}' : '₺0',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroStat(accepted.toString(), 'Kabul Edildi'),
                      const SizedBox(width: 20),
                      _heroStat(pending.toString(), 'Bekliyor'),
                      const SizedBox(width: 20),
                      _heroStat(todayCount.toString(), 'Bugün'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalBanner() {
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
                "Hesabınız henüz admin tarafından onaylanmamıştır. Onaylanınca talepleri yönetebileceksiniz.",
                style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── BENTO TILES ───────────────

  Widget _buildBentoTiles(bool isDark, int pendingRequests, bool isApproved) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.midnight.withValues(alpha: 0.6);

    final tiles = <_BentoTileData>[
      _BentoTileData(
        label: 'İstekler',
        icon: Icons.vaccines_outlined,
        color: const Color(0xFFEF4444),
        sub: pendingRequests > 0 ? '$pendingRequests yeni' : 'Yok',
        onTap: () async {
          if (!isApproved) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeCareProviderRequestsPage()),
          );
          _loadData();
        },
      ),
      _BentoTileData(
        label: 'Profil',
        icon: Icons.person_outline,
        color: const Color(0xFF3B82F6),
        sub: 'Düzenle',
        onTap: () {
          if (_profile == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HomeCareProviderProfilePage(profile: _profile!)),
          );
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleC),
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

  // ─────────────── PENDING REQUESTS ───────────────

  Widget _buildPendingRequests(bool isDark) {
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
                  'Yeni Talepler',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleC),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeCareProviderRequestsPage()),
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
          ..._recentRequests.map((r) => _requestCard(r, isDark, titleC, muted)),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, bool isDark, Color titleC, Color muted) {
    final id = (r['id'] ?? 0) as int;
    final userName = (r['userName'] ?? r['customerName'] ?? 'Müşteri') as String;
    final service = (r['serviceType'] ?? r['service'] ?? 'Serum hizmeti') as String;
    final addr = (r['addressSnapshot'] ?? r['address'] ?? '') as String;
    final amount = r['earningAmount'];
    final amountStr = amount != null ? '₺${(amount as num).toStringAsFixed(0)}' : '';
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final serviceDate = r['serviceDate'] ?? r['requestDate'] ?? '';
    final timeStr = _formatDate(serviceDate.toString());

    final isPending = status == 'pending';
    final gradient = isPending
        ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
        : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.vaccines_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleC),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      addr.isNotEmpty ? '$service · $addr' : service,
                      style: TextStyle(fontSize: 11, color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (amountStr.isNotEmpty)
                    Text(
                      amountStr,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleC),
                    ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(timeStr, style: TextStyle(fontSize: 10, color: muted)),
                  ],
                ],
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () => _rejectRequest(id),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                      child: const Text(
                        'Reddet',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => _acceptRequest(id),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text(
                          'Kabul Et',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'accepted') ...[
            const SizedBox(height: 10),
            const Text(
              '✓ Kabul edildi · Tamamla',
              style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final hours = dt.hour.toString().padLeft(2, '0');
      final minutes = dt.minute.toString().padLeft(2, '0');
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Bugün $hours:$minutes';
      }
      final tomorrow = now.add(const Duration(days: 1));
      if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) {
        return 'Yarın $hours:$minutes';
      }
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} $hours:$minutes';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
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

  // ─────────────── EDIT INFO DIALOG ───────────────

  Future<void> _openEditInfoDialog() async {
    try {
      final token = TokenStore.get();
      if (token == null) return;
      final resp = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/home-care-panel/registration-info"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (resp.statusCode != 200) return;
      final info = jsonDecode(resp.body) as Map<String, dynamic>;
      if (!mounted) return;

      final controllers = {
        'firstName': TextEditingController(text: info['firstName'] ?? ''),
        'lastName': TextEditingController(text: info['lastName'] ?? ''),
        'phone': TextEditingController(text: (info['phone'] ?? '').toString().length > 11 ? (info['phone'] ?? '').toString().substring(0, 11) : (info['phone'] ?? '')),
        'providerName': TextEditingController(text: info['providerName'] ?? ''),
        'providerPhone': TextEditingController(text: info['providerPhone'] ?? ''),
        'city': TextEditingController(text: info['city'] ?? ''),
        'district': TextEditingController(text: info['district'] ?? ''),
        'address': TextEditingController(text: info['address'] ?? ''),
        'licenseNumber': TextEditingController(text: info['licenseNumber'] ?? ''),
        'description': TextEditingController(text: info['description'] ?? ''),
      };
      final labels = {
        'firstName': 'Ad', 'lastName': 'Soyad', 'phone': 'Telefon',
        'providerName': 'Kurum Adı', 'providerPhone': 'Kurum Telefon',
        'city': 'İl', 'district': 'İlçe', 'address': 'Adres',
        'licenseNumber': 'Sicil Numarası', 'description': 'Açıklama',
      };
      final maxLengths = {'phone': 11, 'providerPhone': 15};

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final titleC = isDark ? Colors.white : AppColors.midnight;
      final muted = isDark
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.grey.shade700;
      final dialogBg = isDark ? const Color(0xFF132B44) : Colors.white;
      final fieldFill = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.grey.shade50;
      final borderC = isDark
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.grey.shade400;
      final dividerC = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : null;
      final accentBlue = isDark ? const Color(0xFF60A5FA) : Colors.blue;

      await showDialog(
        context: context,
        builder: (ctx) {
          bool saving = false;
          return StatefulBuilder(builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: dialogBg,
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
                          Icon(Icons.edit, color: accentBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Bilgilerimi Düzenle",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: titleC,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: muted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: dividerC),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: controllers.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: e.value,
                              maxLength: maxLengths[e.key],
                              maxLines: e.key == 'description' ? 3 : 1,
                              keyboardType: (e.key == 'phone' || e.key == 'providerPhone') ? TextInputType.phone : TextInputType.text,
                              style: TextStyle(color: titleC),
                              decoration: InputDecoration(
                                labelText: labels[e.key] ?? e.key,
                                labelStyle: TextStyle(color: muted),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: borderC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: borderC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: accentBlue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: fieldFill,
                                counterText: maxLengths.containsKey(e.key) ? null : '',
                                counterStyle: TextStyle(color: muted),
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: dividerC),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: titleC,
                                side: BorderSide(color: borderC),
                              ),
                              child: const Text("İptal"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: saving ? null : () async {
                                setDialogState(() => saving = true);
                                try {
                                  final body = {};
                                  controllers.forEach((k, v) => body[k] = v.text.trim());
                                  final resp = await http.put(
                                    Uri.parse("${ApiConfig.baseUrl}/api/home-care-panel/update-info"),
                                    headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
                                    body: jsonEncode(body),
                                  );
                                  final success = resp.statusCode == 200;
                                  final msg = success ? "Bilgileriniz kaydedildi" : ((jsonDecode(resp.body) as Map<String, dynamic>)["message"] ?? "Hata").toString();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(msg)));
                                  if (success) { _loadRejectionStatus(); _loadData(); }
                                } catch (e) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: saving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text("Kaydet"),
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
        for (final c in controllers.values) { try { c.dispose(); } catch (_) {} }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bilgiler yüklenemedi: $e")));
    }
  }
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
