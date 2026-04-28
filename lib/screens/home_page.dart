import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../utils/error_messages.dart';

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
import 'pharmacy_detail_page.dart';
import 'prescription_page.dart';
import 'cart_page.dart';
import 'home_care_page.dart';
import 'medicine_search_page.dart';
import 'home_map_fullscreen_page.dart';
import '../services/notification_api_service.dart';
import '../services/cart_api_service.dart';
import '../services/auth_service.dart';
import 'dart:async';
import '../services/local_notification_service.dart';
import '../services/order_api_service.dart';
import '../Models/order_model.dart';
import '../widgets/active_order_tracker.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../widgets/ai_assistant_fab.dart';
import 'package:healzy_app/config/api_config.dart';
import 'chatbot_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Flutter Web
  final String baseUrl = ApiConfig.baseUrl;

  String _userName = '';

  bool _addrLoading = false;
  String? _addrError;

  // Bildirim
  final _notifApi = NotificationApiService(baseUrl: ApiConfig.baseUrl);
  int _unreadCount = 0;
  // ID bazlı push tracker: bu değerden büyük ID'li bildirimler push olarak gösterilir.
  // İlk yüklemede en son bildirimin ID'sine set edilir ki eskiler tekrar pushlamasın.
  int _lastPushedNotifId = 0;
  bool _notifBaselineSet = false;
  Timer? _notifTimer;

  // Sepet
  late final CartApiService _cartApi = CartApiService(
    baseUrl: ApiConfig.baseUrl,
    getToken: () async => TokenStore.get(),
  );
  int _cartCount = 0;

  // Aktif siparis
  final _orderApi = OrderApiService(baseUrl: ApiConfig.baseUrl);
  List<OrderDto> _activeOrders = [];
  Timer? _activeOrderTimer;
  // Kullanıcının gizle dediği sipariş ID'leri. Backend'den düşene kadar tracker'da görünmezler.
  final Set<int> _dismissedOrderIds = <int>{};
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
    // Her açıldığında eski yazıyı temizle
    _prescriptionController.clear();

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

    // Reçete numarası format kontrolü: RCT-777-XXXXX (son kısım tam 5 hane)
    final prescriptionRegex = RegExp(r'^RCT-777-\d{5}$');
    if (!prescriptionRegex.hasMatch(text.trim())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Geçersiz reçete formatı. Örn: RCT-777-12345 (son kısım 5 haneli olmalı)"),
        ),
      );
      return;
    }

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
      final msg = friendlyError(e);
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
    _loadUserName();
    _loadAddresses();
    _loadUnreadCount();
    _loadMapData();
    _loadActiveOrders();
    _refreshCartCount();
    _sendHeartbeat();
    _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadUnreadCount());
    _activeOrderTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadActiveOrders());
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sendHeartbeat());
  }

  ActiveOrderRoute? _buildActiveRoute() {
    if (_activeOrders.isEmpty) return null;
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

  Future<void> _refreshCartCount() async {
    try {
      final c = await _cartApi.getMyCart();
      if (!mounted) return;
      setState(() => _cartCount = c.items.length);
    } catch (_) {}
  }

  void _dismissTracker() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    setState(() {
      // Şu an görünen tüm aktif siparişler bir daha gösterilmesin.
      _dismissedOrderIds.addAll(_activeOrders.map((o) => o.orderId));
      _activeOrders = [];
    });
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await _orderApi.getActiveOrders();
      if (!mounted) return;

      // Backend'den düşen order ID'lerini dismiss set'inden de temizle
      // (aynı ID tekrar oluşmayacağı için bu set büyümez).
      final backendIds = orders.map((o) => o.orderId).toSet();
      _dismissedOrderIds.removeWhere((id) => !backendIds.contains(id));

      // Kullanıcının gizle dediklerini at
      final visible = orders.where((o) => !_dismissedOrderIds.contains(o.orderId)).toList();

      // Görünür siparişlerin hepsi Delivered ise 1 dakika sonra otomatik gizle
      final allDelivered = visible.isNotEmpty && visible.every((o) => o.status == "Delivered");
      if (allDelivered && _autoHideTimer == null) {
        _autoHideTimer = Timer(const Duration(minutes: 1), () {
          if (!mounted) return;
          _dismissTracker();
        });
      } else if (!allDelivered) {
        // Yeni bir aktif sipariş gelmişse timer'ı iptal et
        _autoHideTimer?.cancel();
        _autoHideTimer = null;
      }

      setState(() => _activeOrders = visible);
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifApi.getUnreadCount();
      // Son 10 bildirimi her seferinde çek; ID bazlı delta hesaplanacak.
      final recent = await _notifApi.getMyNotifications(page: 1, pageSize: 10);
      if (!mounted) return;

      if (!_notifBaselineSet) {
        // İlk yüklemede en yüksek ID'yi baseline olarak al, push atma.
        _lastPushedNotifId = recent.isNotEmpty
            ? recent.map((n) => n.id).reduce((a, b) => a > b ? a : b)
            : 0;
        _notifBaselineSet = true;
      } else {
        // FCM push notification zaten iOS sistemi tarafından gosteriliyor.
        // Polling sadece baseline ID'yi guncelliyor, ekrana bildirim basmiyor.
        if (recent.isNotEmpty) {
          final maxId = recent.map((n) => n.id).reduce((a, b) => a > b ? a : b);
          if (maxId > _lastPushedNotifId) _lastPushedNotifId = maxId;
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
                  distanceBadge: isBoth ? "Kayıtlı + Nöbetçi" : "Kayıtlı",
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
                  phone: d.phone,
                  latitude: d.latitude!,
                  longitude: d.longitude!,
                  distanceBadge: "Nöbetçi",
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

  Future<void> _loadUserName() async {
    try {
      final authService = AuthService(baseUrl: ApiConfig.baseUrl);
      final me = await authService.me();
      if (!mounted) return;
      setState(() => _userName = me.fullName);
    } catch (_) {}
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
      setState(() => _addrError = friendlyError(e));
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

      final msg = friendlyError(e);
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

      final msg = friendlyError(e);
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
    final screenH = MediaQuery.of(context).size.height;
    await showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.pearl,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: screenH * 0.30),
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

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.darkPageGradient
                  : AppColors.lightPageGradient,
            ),
          ),
        ),
        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        const SizedBox(height: 16),
                        _buildAddressCard(isDark),
                        const SizedBox(height: 18),
                        _buildBentoGrid(isDark),
                      ],
                    ),
                  ),
                  if (_activeOrders.isNotEmpty)
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
          bottomNavigationBar:
              const HealzyBottomNav(current: HealzyNavTab.home),
        ),
        Positioned.fill(
          child: AiAssistantFab(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotPage()),
            ),
          ),
        ),
      ],
    );
  }

  String _greetingText() {
    final h = DateTime.now().hour;
    if (h < 6) return "İyi geceler 🌙";
    if (h < 12) return "Günaydın ☀️";
    if (h < 18) return "İyi günler 🌞";
    return "İyi akşamlar 🌆";
  }

  // ================= HEADER =================
  Widget _buildHeader(bool isDark) {
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingText(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _userName.isNotEmpty ? _userName : "Healzy",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -0.4,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _iconButton(
            isDark: isDark,
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onTap: () => ThemeController.I.toggle(),
          ),
          const SizedBox(width: 10),
          _iconButton(
            isDark: isDark,
            icon: Icons.shopping_bag_outlined,
            badge: _cartCount,
            badgeColor: AppColors.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ).then((_) => _refreshCartCount()),
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
    Color? badgeColor,
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
                color: badgeColor ?? AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bg, width: 2),
              ),
              child: Text(
                badge > 9 ? "9+" : "$badge",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageButton({
    required bool isDark,
    required String assetPath,
    required VoidCallback onTap,
  }) {
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.pearl;

    return Material(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(assetPath, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  // ================= ADDRESS =================
  Widget _buildAddressCard(bool isDark) {
    final mutedColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: AppRadius.lg,
        onTap: _openAddressPicker,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TESLİMAT ADRESİ",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      letterSpacing: 0.6,
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
                      color: titleColor,
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
                Icons.expand_more_rounded,
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
  Widget _buildBentoGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Row 1: Eczaneler — büyük, full width, mavi gradient
          _buildEczanelerHeroCard(isDark),
          const SizedBox(height: 12),
          // Row 2: Nöbetçi + Evde Bakım
          Row(
            children: [
              Expanded(
                child: _buildColorBentoCard(
                  isDark: isDark,
                  baseColor: AppColors.error,
                  title: "Nöbetçi Eczaneler",
                  subtitle: _dutyMarkers.isEmpty
                      ? "7/24 açık"
                      : "7/24 açık · ${_dutyMarkers.length} eczane",
                  iconWidget: const NobetciIcon(size: 46),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DutyPharmaciesPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColorBentoCard(
                  isDark: isDark,
                  baseColor: AppColors.success,
                  title: "Eve Serum Hizmeti",
                  subtitle: "Talep oluştur",
                  iconWidget: SvgPicture.asset(
                    'assets/icons/ic_homecare.svg',
                    width: 50,
                    height: 50,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeCarePage(baseUrl: baseUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 3: Reçete + Ürün Ara
          Row(
            children: [
              Expanded(
                child: _buildColorBentoCard(
                  isDark: isDark,
                  baseColor: AppColors.info,
                  title: "Reçete",
                  subtitle: "Numara ile ara",
                  iconWidget: SvgPicture.asset(
                    'assets/icons/ic_prescription.svg',
                    width: 50,
                    height: 50,
                  ),
                  onTap: _openPrescriptionSearch,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColorBentoCard(
                  isDark: isDark,
                  baseColor: AppColors.purple,
                  title: "Ürün Ara",
                  subtitle: "Karşılaştır, sipariş ver",
                  iconWidget: SvgPicture.asset(
                    'assets/icons/ic_product_search.svg',
                    width: 50,
                    height: 50,
                  ),
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

  Widget _buildEczanelerHeroCard(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PharmaciesPage()),
      ),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF102E4A), Color(0xFF1B4965)]
                : [
                    AppColors.info.withValues(alpha: 0.18),
                    AppColors.info.withValues(alpha: 0.10),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: isDark
              ? null
              : Border.all(
                  color: AppColors.info.withValues(alpha: 0.22),
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: AppColors.midnight.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark ? Colors.white : AppColors.info)
                          .withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "YAKINDAKİ",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.midnight.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Eczaneler",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.midnight,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pharmacyHeroSubtitle(),
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.midnight.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : AppColors.info)
                          .withValues(alpha: isDark ? 0.1 : 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const EczaneIcon(size: 60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pharmacyHeroSubtitle() {
    final cnt = _registeredMarkers.length;
    final district = _selectedAddress?.district.trim();
    if (cnt == 0) {
      return district == null || district.isEmpty
          ? "Çevrendeki eczaneleri keşfet"
          : "$district çevresi";
    }
    return district == null || district.isEmpty
        ? "$cnt eczane"
        : "$district çevresi · $cnt eczane";
  }

  Widget _buildColorBentoCard({
    required bool isDark,
    required Color baseColor,
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgAlpha = isDark ? 0.18 : 0.10;
    final borderColor = baseColor.withValues(alpha: isDark ? 0.25 : 0.18);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.midnight)
                  .withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: FittedBox(
                fit: BoxFit.contain,
                child: iconWidget,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.2,
                    height: 1.15,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= CATEGORIES =================
  Widget _buildCategoriesRow(bool isDark) {
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final categories = <_CategoryChipData>[
      _CategoryChipData("Ağrı Kesici", Icons.medication_rounded, AppColors.info),
      _CategoryChipData("Vitamin", Icons.auto_awesome_rounded, AppColors.warning),
      _CategoryChipData("Soğuk Algınlığı", Icons.healing_rounded, AppColors.success),
      _CategoryChipData("Bebek", Icons.child_friendly_rounded, AppColors.pink),
      _CategoryChipData("Diyet", Icons.eco_rounded, AppColors.purple),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Kategoriler",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = categories[i];
              return _buildCategoryChip(isDark, c, titleColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(bool isDark, _CategoryChipData c, Color titleColor) {
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.85);
    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : AppColors.border.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicineSearchPage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(c.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              c.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChipData {
  final String label;
  final IconData icon;
  final Color color;
  _CategoryChipData(this.label, this.icon, this.color);
}

