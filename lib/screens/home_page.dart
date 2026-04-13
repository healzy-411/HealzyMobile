import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Flutter Web
  final String baseUrl = "http://localhost:5009";

  bool _addrLoading = false;
  String? _addrError;

  // Bildirim
  final _notifApi = NotificationApiService(baseUrl: "http://localhost:5009");
  int _unreadCount = 0;
  Timer? _notifTimer;

  // Aktif siparis
  final _orderApi = OrderApiService(baseUrl: "http://localhost:5009");
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
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Reçete Numarası"),
          content: TextField(
            controller: _prescriptionController,
            decoration: const InputDecoration(
              hintText: "Örn: RCP-666-001",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, _prescriptionController.text);
              },
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
                  badgeColor: isBoth ? Colors.purple : const Color(0xFF00A79D),
                  markerColor: isBoth ? Colors.purple : const Color(0xFF00A79D),
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

    await showModalBottomSheet(
      context: context,
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
                          backgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
                        label: const Text(
                          "Adres Ekle",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                size: 30,
                                color: Colors.black87,
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                                _loadUnreadCount();
                              },
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _unreadCount > 9 ? "9+" : "$_unreadCount",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.account_circle_outlined,
                            size: 32,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(baseUrl: baseUrl),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),

                  // ✅ adres bar'ı dinamik + tıklanabilir (UI aynı)
                  GestureDetector(
                    onTap: _openAddressPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _headerText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_addrLoading) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_addrError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _addrError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ================= GRID MENU =================
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.1,
                children: [
                  _buildMenuCard(
                    icon: Icons.store_mall_directory_outlined,
                    title: "Eczaneler",
                    color: Colors.pink[50]!,
                    iconColor: Colors.pink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PharmaciesPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.access_alarm,
                    title: "İlaç Hatırlatıcı",
                    color: Colors.orange[50]!,
                    iconColor: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicineReminderPage(
                            baseUrl: baseUrl,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.medical_services_outlined,
                    title: "Eve Serum\nServisi",
                    color: Colors.blue[50]!,
                    iconColor: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomeCarePage(baseUrl: baseUrl),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.local_pharmacy_outlined,
                    title: "Nöbetçi Eczaneler",
                    color: Colors.teal[50]!,
                    iconColor: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DutyPharmaciesPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.search,
                    title: "Ilac Ara",
                    color: Colors.green[50]!,
                    iconColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MedicineSearchPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ================= SEARCH BAR =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openPrescriptionSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("Reçete Numarası Gir",
                                style: TextStyle(color: Colors.grey)),
                            Icon(Icons.search, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.smart_toy_outlined,
                        color: Colors.black87),
                  )
                ],
              ),
            ),

            // ================= MAP =================
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -5) {
                  _openFullScreenMap();
                }
              },
              child: Container(
                height: MediaQuery.of(context).size.height *
                    (_activeOrders.isNotEmpty && !_trackerDismissed ? 0.28 : 0.15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Harita (dokunma devre disi - sadece gorsel)
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
                    // Tam dokunulabilir overlay
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openFullScreenMap,
                          child: Container(),
                        ),
                      ),
                    ),
                    // Ust bar: cekme gostergesi
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.0)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text("Haritayi ac", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                    // Aktif siparis tracker
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
            ),
          ],
        ),
      ),
    );
  }

  // ================= MENU CARD =================
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}