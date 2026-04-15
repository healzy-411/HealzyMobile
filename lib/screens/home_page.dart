import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/theme_controller.dart';
import '../widgets/ui/bento_tile.dart';
import '../widgets/ui/eczane_icon.dart';
import '../widgets/ui/nobetci_icon.dart';
import '../widgets/ui/modern_icon.dart';
import '../widgets/ui/glass_card.dart';
import '../services/token_store.dart';
import '../services/api_service.dart';
import '../Models/address_model.dart';
import '../Models/pharmacy_model.dart';
import '../Models/duty_pharmacy_model.dart';
import '../widgets/pharmacy_map_view.dart';
import '../services/prescription_api_service.dart';
import 'pharmacies_page.dart';
import 'duty_pharmacies_page.dart';
import 'add_address_page.dart';
import 'edit_address_page.dart';
import '../services/address_api_service.dart';
import 'profile_page.dart';
import 'pharmacy_detail_page.dart';
import 'prescription_page.dart';
import 'medicine_reminder_page.dart';
import 'cart_page.dart';
import 'home_care_page.dart';
import 'medicine_search_page.dart';
import 'notifications_page.dart';
import 'home_map_fullscreen_page.dart';
import '../services/notification_api_service.dart';
import 'dart:async';
import '../services/local_notification_service.dart';
import '../services/order_api_service.dart';
import '../Models/order_model.dart';
import '../widgets/active_order_tracker.dart';
import '../widgets/healzy_bottom_nav.dart';
import 'package:healzy_app/config/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Flutter Web
  final String baseUrl = ApiConfig.baseUrl;

  bool _addrLoading = false;
  String? _addrError;

  // Bildirim
  final _notifApi = NotificationApiService(baseUrl: ApiConfig.baseUrl);
  int _unreadCount = 0;
  Timer? _notifTimer;

  // Aktif siparis
  final _orderApi = OrderApiService(baseUrl: ApiConfig.baseUrl);
  List<OrderDto> _activeOrders = [];
  Timer? _activeOrderTimer;
  bool _trackerDismissed = false;
  Timer? _autoHideTimer;

  // Harita stili
  bool _mapSimpleStyle = true;

  // Harita
  final _apiService = ApiService();
  List<PharmacyMarkerData> _registeredMarkers = [];
  List<PharmacyMarkerData> _dutyMarkers = [];
  double? _userLat;
  double? _userLng;

  List<AddressDto> _addresses = [];
  AddressDto? _selectedAddress;

  final TextEditingController _prescriptionController = TextEditingController();

  late final PrescriptionApiService _prescriptionApi =
      PrescriptionApiService(baseUrl: baseUrl);

  // ✅ BottomSheet içini anlık refreshlemek için
  void Function(VoidCallback fn)? _sheetSetState;
  void _refreshSheet() {
    final s = _sheetSetState;
    if (s != null) s(() {});
  }

  Future<void> _openPrescriptionSearch() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF102E4A).withValues(alpha: 0.05);

    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.pearl,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Reçete Numarası",
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: _prescriptionController,
            style: TextStyle(color: fg),
            decoration: InputDecoration(
              hintText: "Örn: RCT-777-12345",
              hintStyle: TextStyle(color: fg.withValues(alpha: 0.5)),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: fg.withValues(alpha: 0.2), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: fg.withValues(alpha: 0.2), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: fg, width: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: fg),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, _prescriptionController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102E4A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Ara"),
            ),
          ],
        );
      },
    );

    if (text == null || text.trim().isEmpty) return;

    try {
      final detail = await _prescriptionApi.loadPrescription(text);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionPage(
            detail: detail,
            api: _prescriptionApi,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reçete yüklenemedi: $msg")),
      );
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _activeOrderTimer?.cancel();
    _autoHideTimer?.cancel();
    _heartbeatTimer?.cancel();
    _prescriptionController.dispose();
    super.dispose();
  }

  // Heartbeat
  Timer? _heartbeatTimer;

  Future<void> _sendHeartbeat() async {
    try {
      final token = TokenStore.get();
      if (token == null) return;
      await http.post(
        Uri.parse("$baseUrl/api/auth/heartbeat"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadUnreadCount();
    _loadMapData();
    _loadActiveOrders();
    _sendHeartbeat();
    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
    _activeOrderTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadActiveOrders());
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sendHeartbeat());
  }

  ActiveOrderRoute? _buildActiveRoute() {
    if (_activeOrders.isEmpty || _trackerDismissed) return null;
    final order = _activeOrders.first;
    if (order.pharmacyLatitude == null || order.pharmacyLongitude == null) return null;

    // Teslimat noktasi: GPS konumu veya adres koordinatlari
    final destLat = _userLat ?? order.deliveryLatitude;
    final destLng = _userLng ?? order.deliveryLongitude;
    if (destLat == null || destLng == null) return null;

    return ActiveOrderRoute(
      pharmacyLat: order.pharmacyLatitude!,
      pharmacyLng: order.pharmacyLongitude!,
      deliveryLat: destLat,
      deliveryLng: destLng,
      status: order.status,
    );
  }

  void _dismissTracker() {
    _autoHideTimer?.cancel();
    setState(() => _trackerDismissed = true);
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await _orderApi.getActiveOrders();
      if (!mounted) return;

      // Yeni aktif (non-delivered) siparis gelirse dismiss sifirla
      final hasActive = orders.any((o) => o.status != "Delivered");
      if (hasActive && _trackerDismissed) {
        _trackerDismissed = false;
        _autoHideTimer?.cancel();
      }

      // Delivered olunca 3 dk auto-hide timer baslat
      final allDelivered = orders.isNotEmpty && orders.every((o) => o.status == "Delivered");
      if (allDelivered && _autoHideTimer == null && !_trackerDismissed) {
        _autoHideTimer = Timer(const Duration(minutes: 3), () {
          if (!mounted) return;
          _dismissTracker();
        });
      }

      // Siparis kalmadiysa temizle
      if (orders.isEmpty) {
        _trackerDismissed = false;
        _autoHideTimer?.cancel();
        _autoHideTimer = null;
      }

      setState(() => _activeOrders = orders);
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      if (!mounted) return;

      // Yeni bildirim varsa local push notification göster
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

  Future<void> _loadMapData() async {
    try {
      // Konum al (opsiyonel)
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 5)),
        );
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      } catch (_) {}

      final results = await Future.wait([
        _apiService.getPharmacies(),
        _apiService.getDutyPharmacies(),
      ]);

      final pharmacies = results[0] as List<Pharmacy>;
      final dutyPharmacies = results[1] as List<DutyPharmacyModel>;

      if (!mounted) return;

      // Kayitli eczane isimlerini set'e al (nobetci filtrelemesi icin)
      final registeredNames = pharmacies
          .map((p) => p.name.trim().toLowerCase())
          .toSet();

      setState(() {
        _registeredMarkers = pharmacies
            .where((p) => p.latitude != 0 || p.longitude != 0)
            .map((p) {
              final isBoth = p.isOnDuty;
              return PharmacyMarkerData(
                  name: p.name,
                  address: "${p.district} / ${p.address}",
                  phone: p.phone,
                  latitude: p.latitude,
                  longitude: p.longitude,
                  distanceBadge: isBoth ? "Kayitli + Nobetci" : "Kayitli",
                  badgeColor: isBoth ? Colors.purple : const Color(0xFF00B894),
                  markerColor: isBoth ? Colors.purple : const Color(0xFF00B894),
                  rating: p.averageRating > 0 ? p.averageRating : null,
                  reviewCount: p.reviewCount > 0 ? p.reviewCount : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PharmacyDetailPage(pharmacyId: p.id),
                      ),
                    );
                  },
                );
            })
            .toList();

        // Nobetci markerlar: sadece kayitli olmayanlari goster (cift marker onleme)
        _dutyMarkers = dutyPharmacies
            .where((d) => d.latitude != null && d.longitude != null && (d.latitude != 0 || d.longitude != 0))
            .where((d) => !registeredNames.contains(d.pharmacyName.trim().toLowerCase()))
            .map((d) => PharmacyMarkerData(
                  name: d.pharmacyName,
                  address: "${d.district} / ${d.address}",
                  phone: d.phone ?? "",
                  latitude: d.latitude!,
                  longitude: d.longitude!,
                  distanceBadge: "Nobetci",
                  badgeColor: Colors.red,
                  markerColor: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DutyPharmaciesPage(),
                      ),
                    );
                  },
                ))
            .toList();
      });
    } catch (_) {}
  }

  List<PharmacyMarkerData> get _filteredMarkers {
    return [..._dutyMarkers, ..._registeredMarkers];
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeMapFullscreenPage(
          registeredMarkers: _registeredMarkers,
          dutyMarkers: _dutyMarkers,
          userLat: _userLat,
          userLng: _userLng,
          activeRoute: _buildActiveRoute(),
          simpleStyle: _mapSimpleStyle,
          onStyleChanged: (val) {
            setState(() => _mapSimpleStyle = val);
          },
        ),
      ),
    );
  }

  String _headerText() {
    if (_addrLoading) return "Adres yükleniyor...";
    if (_selectedAddress == null) return "Teslimat Adresi Seçin";
    return _selectedAddress!.shortLine();
  }

  Future<Map<String, String>> _headers() async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lütfen tekrar giriş yap.");
    }
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  int _score(AddressDto a) => (a.isDefault ? 2 : 0) + (a.isSelected ? 1 : 0);

  List<AddressDto> _sortedAddresses(List<AddressDto> list) {
    final copy = [...list];
    copy.sort((p, q) => _score(q).compareTo(_score(p)));
    return copy;
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _addrLoading = true;
      _addrError = null;
    });
    _refreshSheet();

    try {
      final uri = Uri.parse("$baseUrl/api/addresses/my");
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);

        final list = (decoded is List ? decoded : <dynamic>[])
            .map((x) => AddressDto.fromJson(x as Map<String, dynamic>))
            .toList();

        final sorted = _sortedAddresses(list);
        final selected = sorted.where((a) => a.isSelected).toList();

        if (!mounted) return;
        setState(() {
          _addresses = sorted;
          _selectedAddress = selected.isNotEmpty ? selected.first : null;
        });
        _refreshSheet();
        return;
      }

      throw Exception("Adresler alınamadı (${res.statusCode})");
    } catch (e) {
      if (!mounted) return;
      setState(() => _addrError = e.toString().replaceFirst("Exception: ", ""));
      _refreshSheet();
    } finally {
      if (!mounted) return;
      setState(() => _addrLoading = false);
      _refreshSheet();
    }
  }

  // ✅ Seçilen adresi aynı zamanda default yap (⭐) + anlık refresh
  Future<void> _setDefaultAddress(AddressDto a) async {
    // ✅ 1) UI anında güncellensin (optimistic)
    setState(() {
      _addrError = null;
      _selectedAddress = a;

      _addresses = _addresses.map((x) {
        if (x.id == a.id) {
          return x.copyWith(isSelected: true, isDefault: true);
        }
        return x.copyWith(isSelected: false, isDefault: false);
      }).toList();

      _addresses = _sortedAddresses(_addresses);
    });
    _refreshSheet();

    // ✅ 2) API (truth)
    try {
      setState(() => _addrLoading = true);
      _refreshSheet();

      final uri = Uri.parse("$baseUrl/api/addresses/${a.id}/default");
      final res = await http.post(uri, headers: await _headers());

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // server truth ile doğrula (garanti)
        await _loadAddresses();
        _refreshSheet();
        return;
      }

      throw Exception("Varsayılan adres ayarlanamadı (${res.statusCode})");
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst("Exception: ", "");
      setState(() => _addrError = msg);
      _refreshSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      await _loadAddresses(); // rollback
      _refreshSheet();
    } finally {
      if (!mounted) return;
      setState(() => _addrLoading = false);
      _refreshSheet();
    }
  }

  // ✅ Delete: anında kaldır + server doğrula
  Future<void> _deleteAddress(AddressDto a) async {
    // optimistic
    setState(() {
      _addrError = null;
      _addresses = _addresses.where((x) => x.id != a.id).toList();

      if (_selectedAddress?.id == a.id) {
        _selectedAddress = null;
      }

      _addresses = _sortedAddresses(_addresses);
    });
    _refreshSheet();

    try {
      setState(() => _addrLoading = true);
      _refreshSheet();

      final api = AddressApiService(baseUrl: baseUrl);
      await api.deleteAddress(a.id);

      await _loadAddresses();
      _refreshSheet();
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst("Exception: ", "");
      setState(() => _addrError = msg);
      _refreshSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      await _loadAddresses(); // rollback
      _refreshSheet();
    } finally {
      if (!mounted) return;
      setState(() => _addrLoading = false);
      _refreshSheet();
    }
  }

  Future<void> _openAddressPicker() async {
    if (_addresses.isEmpty && !_addrLoading) {
      await _loadAddresses();
    }
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.pearl,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // ✅ sheet setState yakala
            _sheetSetState = setModalState;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Teslimat Adresi Seç",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (_addrLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    else if (_addresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text("Kayıtlı adres yok. Önce adres ekleyin."),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final a = _addresses[i];
                            final selected = _selectedAddress?.id == a.id;

                            return ListTile(
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                              ),
                              title: Text(a.title.isNotEmpty ? a.title : "Adres"),
                              subtitle: Text(
                                a.fullLine(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ⭐ default
                                  IconButton(
                                    tooltip: "Varsayılan yap",
                                    icon: Icon(
                                      Icons.star,
                                      size: 20,
                                      color: a.isDefault ? Colors.amber : Colors.grey,
                                    ),
                                    onPressed: _addrLoading ? null : () async {
                                      await _setDefaultAddress(a);
                                    },
                                  ),

                                  // ✏️ edit
                                  IconButton(
                                    tooltip: "Düzenle",
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: _addrLoading ? null : () async {
                                      final rootContext = context;

                                      Navigator.pop(rootContext);
                                      await Future.delayed(
                                        const Duration(milliseconds: 200),
                                      );

                                      if (!mounted) return;

                                      final updated = await Navigator.push<AddressDto?>(
                                        rootContext,
                                        MaterialPageRoute(
                                          builder: (_) => EditAddressPage(
                                            baseUrl: baseUrl,
                                            address: a,
                                          ),
                                        ),
                                      );

                                      await _loadAddresses();
                                      _refreshSheet();

                                      if (updated != null &&
                                          _selectedAddress?.id == updated.id) {
                                        setState(() => _selectedAddress = updated);
                                        _refreshSheet();
                                      }
                                    },
                                  ),

                                  // 🗑️ delete
                                  IconButton(
                                    tooltip: "Sil",
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: _addrLoading ? null : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (dlgCtx) => AlertDialog(
                                          title: const Text("Adresi Sil"),
                                          content: const Text("Bu adres silinsin mi?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dlgCtx, false),
                                              child: const Text("İptal"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(dlgCtx, true),
                                              child: const Text("Sil"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (ok != true) return;
                                      await _deleteAddress(a);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await _setDefaultAddress(a);
                                if (!mounted) return;
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ➕ Add address
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF102E4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text(
                          "Adres Ekle",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final rootContext = context;

                          Navigator.pop(rootContext);
                          await Future.delayed(const Duration(milliseconds: 200));
                          if (!mounted) return;

                          final created = await Navigator.push<AddressDto?>(
                            rootContext,
                            MaterialPageRoute(
                              builder: (_) => AddAddressPage(baseUrl: baseUrl),
                            ),
                          );

                          await _loadAddresses();
                          _refreshSheet();

                          if (created != null) {
                            await _setDefaultAddress(created);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // ✅ sheet kapandı
      _sheetSetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.pearlWarm;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 12),
                  _buildAddressCard(isDark),
                  const SizedBox(height: 20),
                  Expanded(child: _buildBentoGrid()),
                  const SizedBox(height: 100),
                ],
              ),
              if (_activeOrders.isNotEmpty && !_trackerDismissed)
                ActiveOrderTracker(
                  activeOrders: _activeOrders,
                  userLat: _userLat,
                  userLng: _userLng,
                  onRefresh: _loadActiveOrders,
                  onDismiss: _dismissTracker,
                ),
            ],
          ),
        ),
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.home),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader(bool isDark) {
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merhaba 👋",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Healzy",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(
            isDark: isDark,
            icon: Icons.shopping_basket_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
          const SizedBox(width: 10),
          _iconButton(
            isDark: isDark,
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onTap: () => ThemeController.I.toggle(),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.pearl;
    final iconColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: bg,
          elevation: 0,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.border.withValues(alpha: 0.6),
                ),
                boxShadow: AppShadows.soft(isDark),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bg, width: 2),
              ),
              child: Text(
                badge > 9 ? "9+" : "$badge",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ================= ADDRESS =================
  Widget _buildAddressCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: AppRadius.lg,
        onTap: _openAddressPicker,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.pearlGradient
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: isDark ? AppColors.midnight : AppColors.pearl,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Teslimat adresi",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _headerText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.midnight,
                    ),
                  ),
                ],
              ),
            ),
            if (_addrLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  // ================= BENTO GRID =================
  Widget _buildBentoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: BentoTile(
                  icon: Icons.storefront_rounded,
                  customIcon: const EczaneIcon(size: 64),
                  title: "Eczaneler",
                  height: 160,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PharmaciesPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoTile(
                  icon: Icons.local_pharmacy_rounded,
                  customIcon: const NobetciIcon(size: 64),
                  title: "Nöbetçi Eczaneler",
                  height: 160,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DutyPharmaciesPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BentoTile(
                  icon: Icons.vaccines_rounded,
                  customIcon: const ModernIcon(
                    icon: Icons.vaccines_rounded,
                    size: 56,
                  ),
                  title: "Serum",
                  height: 128,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeCarePage(baseUrl: baseUrl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoTile(
                  icon: Icons.qr_code_rounded,
                  customIcon: const ModernIcon(
                    icon: Icons.qr_code_rounded,
                    size: 56,
                  ),
                  title: "Reçete Gir",
                  height: 128,
                  onTap: _openPrescriptionSearch,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoTile(
                  icon: Icons.medication_rounded,
                  customIcon: const ModernIcon(
                    icon: Icons.medication_rounded,
                    size: 56,
                  ),
                  title: "İlaç Ara",
                  height: 128,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicineSearchPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PRESCRIPTION BAR =================
  Widget _buildPrescriptionBar(bool isDark) {
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.pearl;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final hintColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: _openPrescriptionSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.border.withValues(alpha: 0.6),
                    ),
                    boxShadow: AppShadows.soft(isDark),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          color: hintColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Reçete numarası gir",
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.search_rounded, color: textColor, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.pearlGradient
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.glow(
                isDark ? AppColors.pearl : AppColors.midnight,
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark ? AppColors.midnight : AppColors.pearl,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ================= MAP =================
  Widget _buildMapSection(bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -5) _openFullScreenMap();
      },
      child: Container(
        height: MediaQuery.of(context).size.height *
            (_activeOrders.isNotEmpty && !_trackerDismissed ? 0.28 : 0.15),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppShadows.elevated(isDark),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _filteredMarkers.isEmpty && _activeOrders.isEmpty
                    ? const SizedBox()
                    : PharmacyMapView(
                        key: ValueKey('map_${_userLat}_${_userLng}'),
                        pharmacies: _filteredMarkers,
                        userLat: _userLat,
                        userLng: _userLng,
                        activeRoute: _buildActiveRoute(),
                        showControls: false,
                        simpleStyle: _mapSimpleStyle,
                      ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openFullScreenMap,
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? AppColors.darkSurface : AppColors.pearl)
                          .withValues(alpha: 0.9),
                      (isDark ? AppColors.darkSurface : AppColors.pearl)
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary)
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Haritayı aç",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_activeOrders.isNotEmpty && !_trackerDismissed)
              ActiveOrderTracker(
                activeOrders: _activeOrders,
                userLat: _userLat,
                userLng: _userLng,
                onRefresh: _loadActiveOrders,
                onDismiss: _dismissTracker,
              ),
          ],
        ),
      ),
    );
  }
}

