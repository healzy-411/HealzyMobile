import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../services/upload_api_service.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';
import '../utils/error_messages.dart';

// Web tarafindaki utils/ankara.js ile birebir ayni
class _AnkaraBounds {
  static const double minLat = 39.0;
  static const double maxLat = 41.0;
  static const double minLon = 31.3;
  static const double maxLon = 34.2;
  static const LatLng center = LatLng(39.9208, 32.8541);

  static bool isInvalid(double? lat, double? lon) {
    if (lat == null || lon == null) return true;
    if (!lat.isFinite || !lon.isFinite) return true;
    if (lat == 0 && lon == 0) return true;
    return lat < minLat || lat > maxLat || lon < minLon || lon > maxLon;
  }
}

enum _CoordStatusType { neutral, loading, success, error }

class _CoordStatus {
  final _CoordStatusType type;
  final String text;
  const _CoordStatus(this.type, this.text);
}

class PharmacyProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const PharmacyProfilePage({super.key, required this.profile});

  @override
  State<PharmacyProfilePage> createState() => _PharmacyProfilePageState();
}

class _PharmacyProfilePageState extends State<PharmacyProfilePage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);
  final _uploadApi = UploadApiService(baseUrl: ApiConfig.baseUrl);
  final _mapController = MapController();

  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;
  bool _geocoding = false;
  String? _geocodeError;
  String? _err;
  String? _imageUrl;
  String? _licenseNumber;
  File? _pickedImage;

  late final TextEditingController _name;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _workingHours;

  double _latitude = 0;
  double _longitude = 0;

  _CoordStatus _coordStatus = const _CoordStatus(
    _CoordStatusType.neutral,
    'Henüz konum yok. Adresinizi girip "Konumu Bul" butonuna basın.',
  );
  Map<String, dynamic>? _locationInfo;
  Timer? _reverseTimer;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile['name'] ?? '');
    _district = TextEditingController(text: widget.profile['district'] ?? '');
    _address = TextEditingController(text: widget.profile['address'] ?? '');
    _phone = TextEditingController(text: widget.profile['phone'] ?? '');
    _workingHours = TextEditingController(text: widget.profile['workingHours'] ?? '');
    _imageUrl = widget.profile['imageUrl'];
    _licenseNumber = widget.profile['licenseNumber'] as String?;
    _latitude = (widget.profile['latitude'] as num?)?.toDouble() ?? 0;
    _longitude = (widget.profile['longitude'] as num?)?.toDouble() ?? 0;
    if (_latitude != 0 || _longitude != 0) {
      _refreshCoordStatus();
    }
    if (_licenseNumber == null) _loadRegistrationInfo();
  }

  Future<void> _loadRegistrationInfo() async {
    try {
      final info = await _api.getRegistrationInfo();
      if (!mounted) return;
      setState(() => _licenseNumber = info['licenseNumber'] as String?);
    } catch (_) {}
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _name.dispose();
    _district.dispose();
    _address.dispose();
    _phone.dispose();
    _workingHours.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  bool get _canSave => _coordStatus.type != _CoordStatusType.error && !_saving;

  void _setCoords(double lat, double lng, {bool moveMap = true}) {
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });
    if (moveMap) {
      try {
        _mapController.move(LatLng(lat, lng), 15);
      } catch (_) {}
    }
    _refreshCoordStatus();
  }

  void _refreshCoordStatus() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == 0 && lng == 0) {
      setState(() {
        _coordStatus = const _CoordStatus(_CoordStatusType.neutral, 'Henüz konum yok.');
        _locationInfo = null;
      });
      return;
    }
    final fastInvalid = _AnkaraBounds.isInvalid(lat, lng);
    if (fastInvalid) {
      setState(() {
        _coordStatus = _CoordStatus(
          _CoordStatusType.error,
          '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} — Ankara dışında. Kaydet devre dışı.',
        );
      });
    } else {
      setState(() {
        _coordStatus = _CoordStatus(
          _CoordStatusType.loading,
          '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} — Doğrulanıyor...',
        );
      });
    }

    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await _api.reverseGeocode(lat, lng);
        if (!mounted) return;
        final found = res['found'] == true;
        if (!found) {
          setState(() {
            _coordStatus = const _CoordStatus(_CoordStatusType.error, 'Konum doğrulanamadı.');
            _locationInfo = null;
          });
          return;
        }
        final isAnkara = res['isAnkara'] == true;
        setState(() {
          _locationInfo = res;
          if (isAnkara) {
            final district = (res['district'] ?? '').toString();
            final extra = district.isNotEmpty ? ' • $district' : '';
            _coordStatus = _CoordStatus(
              _CoordStatusType.success,
              'Konum: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} (Ankara$extra)',
            );
          } else {
            final province = (res['province'] ?? 'Bilinmeyen il').toString();
            _coordStatus = _CoordStatus(
              _CoordStatusType.error,
              '$province içinde, Ankara dışı.',
            );
          }
        });
      } catch (_) {
        if (!mounted) return;
        if (!fastInvalid) {
          setState(() {
            _coordStatus = _CoordStatus(
              _CoordStatusType.success,
              'Konum: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            );
            _locationInfo = null;
          });
        }
      }
    });
  }

  Future<void> _handleGeocode() async {
    if (_district.text.trim().isEmpty) {
      setState(() => _geocodeError = 'İlçe boş bırakılamaz.');
      return;
    }
    setState(() {
      _geocoding = true;
      _geocodeError = null;
    });
    try {
      final res = await _api.geocodeAddress(_district.text.trim(), _address.text.trim());
      final found = res['found'] == true;
      if (!found) {
        setState(() => _geocodeError =
            'Bu adresten konum bulunamadı. Daha detaylı adres girin veya haritadan marker\'ı sürükleyin.');
        return;
      }
      _setCoords(
        (res['latitude'] as num).toDouble(),
        (res['longitude'] as num).toDouble(),
      );
    } catch (e) {
      setState(() => _geocodeError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _applyLocationInfo() {
    final info = _locationInfo;
    if (info == null) return;
    final parts = <String>[];
    final street = (info['street'] ?? '').toString();
    final houseNumber = (info['houseNumber'] ?? '').toString();
    if (street.isNotEmpty) {
      parts.add(houseNumber.isNotEmpty ? '$street No:$houseNumber' : street);
    }
    final neighborhood = (info['neighborhood'] ?? '').toString();
    if (neighborhood.isNotEmpty) parts.add(neighborhood);
    final newAddress = parts.isNotEmpty
        ? parts.join(', ')
        : (info['formattedAddress'] ?? _address.text).toString();
    final district = (info['district'] ?? '').toString();
    final province = (info['province'] ?? '').toString();
    setState(() {
      _address.text = newAddress;
      if (district.isNotEmpty && district != province) {
        _district.text = district;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      String? uploadedUrl;
      if (_pickedImage != null) {
        setState(() => _uploading = true);
        uploadedUrl = await _uploadApi.uploadImage(_pickedImage!);
        setState(() => _uploading = false);
      }

      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'workingHours': _workingHours.text.trim(),
        'imageUrl': uploadedUrl ?? _imageUrl,
      };

      final updated = await _api.updateProfile(data);
      if (!mounted) return;
      _imageUrl = (updated['imageUrl'] as String?) ?? uploadedUrl ?? _imageUrl;
      _pickedImage = null;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgileriniz kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploading = false;
        _err = friendlyError(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err!), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAvatar(bool isDark) {
    final baseUrl = ApiConfig.baseUrl;
    final accent = isDark ? Colors.white : AppColors.midnight;
    if (_pickedImage != null) {
      return CircleAvatar(radius: 48, backgroundImage: FileImage(_pickedImage!));
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      final src = _imageUrl!.startsWith('http') ? _imageUrl! : '$baseUrl$_imageUrl';
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(src),
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: accent.withValues(alpha: isDark ? 0.12 : 0.15),
      child: Icon(Icons.local_pharmacy, size: 48, color: accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.profile['isApproved'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.midnight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: Text(_editing ? 'Eczane Bilgilerini Düzenle' : 'Eczane Bilgileri'),
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
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Düzenle',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: _buildAvatar(isDark)),
            if (_editing) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: _uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.photo_camera, color: isDark ? Colors.white : AppColors.midnight),
                  label: Text(
                    _uploading ? 'Yükleniyor...' : 'Fotoğraf Seç',
                    style: TextStyle(color: isDark ? Colors.white : AppColors.midnight),
                  ),
                ),
              ),
              if (_pickedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _pickedImage = null;
                      _imageUrl = '';
                    }),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Fotoğrafı Kaldır', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isApproved ? '● Onaylı' : '● Onay Bekliyor',
                  style: TextStyle(
                    color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_editing) ..._buildEditForm(isDark) else ..._buildReadOnlyView(isDark),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEditForm(bool isDark) {
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey.shade700;
    return [
      _editField('Eczane Adı', _name, Icons.local_pharmacy, isDark: isDark),
      _editField(
        'Sicil Numarası (değiştirilemez)',
        TextEditingController(text: _licenseNumber ?? '-'),
        Icons.badge_outlined,
        isDark: isDark,
        enabled: false,
      ),
      Row(
        children: [
          Expanded(child: _editField('İlçe', _district, Icons.location_city, isDark: isDark)),
          const SizedBox(width: 12),
          Expanded(
            child: _editField(
              'Telefon',
              _phone,
              Icons.phone,
              isDark: isDark,
              keyboardType: TextInputType.phone,
              maxLength: 11,
            ),
          ),
        ],
      ),
      _editField('Adres', _address, Icons.home, maxLines: 2, isDark: isDark),
      _editField('Çalışma Saatleri', _workingHours, Icons.access_time, isDark: isDark, hint: '08:00 - 22:00'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.midnight.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: muted),
                const SizedBox(width: 6),
                Text(
                  'Konum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _geocoding ? null : _handleGeocode,
                icon: _geocoding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 16),
                label: Text(_geocoding ? 'Aranıyor...' : 'Konumu Bul (Adrese Git)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnight.withValues(alpha: isDark ? 0.5 : 0.1),
                  foregroundColor: isDark ? Colors.white : AppColors.midnight,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_geocodeError != null) ...[
              const SizedBox(height: 8),
              _statusBadge(_CoordStatusType.error, _geocodeError!),
            ],
            const SizedBox(height: 8),
            _statusBadge(_coordStatus.type, _coordStatus.text),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: (_latitude == 0 && _longitude == 0)
                        ? _AnkaraBounds.center
                        : LatLng(_latitude, _longitude),
                    initialZoom: (_latitude == 0 && _longitude == 0) ? 11 : 15,
                    onTap: (tapPos, latLng) {
                      _setCoords(latLng.latitude, latLng.longitude, moveMap: false);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.furkandemirci.healzy',
                    ),
                    if (_latitude != 0 || _longitude != 0)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_latitude, _longitude),
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.location_pin,
                              size: 36,
                              color: _coordStatus.type == _CoordStatusType.error
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Haritaya basarak veya "Konumu Bul" kullanarak konumu seçebilirsiniz.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            if (_locationInfo != null && (_locationInfo!['formattedAddress'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Marker konumu',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (_locationInfo!['formattedAddress'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : AppColors.midnight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _coordStatus.type == _CoordStatusType.success
                            ? _applyLocationInfo
                            : null,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Bu Adresi Kullan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF10B981),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      if (_err != null) ...[
        const SizedBox(height: 12),
        _statusBadge(_CoordStatusType.error, _err!),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.midnight,
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.midnight.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: _coordStatus.type == _CoordStatusType.error
                  ? 'Konum Ankara dışında, kaydet engellendi'
                  : '',
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildReadOnlyView(bool isDark) {
    return [
      _infoTile(Icons.local_pharmacy, 'Eczane Adı', _name.text, isDark: isDark),
      _infoTile(Icons.badge_outlined, 'Sicil Numarası', _licenseNumber ?? '-', isDark: isDark),
      _infoTile(Icons.location_city, 'İlçe', _district.text, isDark: isDark),
      _infoTile(Icons.phone, 'Telefon', _phone.text, isDark: isDark),
      _infoTile(Icons.home, 'Adres', _address.text, isDark: isDark),
      _infoTile(Icons.access_time, 'Çalışma Saatleri', _workingHours.text, isDark: isDark),
      _infoTile(
        Icons.location_on,
        'Konum',
        (_latitude == 0 && _longitude == 0)
            ? '-'
            : '${_latitude.toStringAsFixed(5)}, ${_longitude.toStringAsFixed(5)}',
        isDark: isDark,
      ),
    ];
  }

  Widget _statusBadge(_CoordStatusType type, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    IconData icon;
    switch (type) {
      case _CoordStatusType.success:
        bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        icon = Icons.check_circle_outline;
        break;
      case _CoordStatusType.error:
        bg = Colors.red.withValues(alpha: isDark ? 0.18 : 0.12);
        fg = isDark ? Colors.red.shade300 : Colors.red.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case _CoordStatusType.loading:
        bg = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.18 : 0.12);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        icon = Icons.refresh;
        break;
      case _CoordStatusType.neutral:
        bg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100;
        fg = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade700;
        icon = Icons.location_on_outlined;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? hint,
    bool enabled = true,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(
          color: enabled
              ? (isDark ? Colors.white : AppColors.midnight)
              : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade600),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: maxLength != null ? null : '',
          labelStyle: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : AppColors.midnight.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(icon,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : AppColors.midnight),
          filled: true,
          fillColor: enabled
              ? (isDark
                  ? const Color(0xFF132B44).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.7))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade100),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.midnight.withValues(alpha: 0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.midnight.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.midnight, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.midnight.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, {required bool isDark}) {
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.midnight.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: titleC, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '-' : value,
                    style: TextStyle(fontSize: 15, color: titleC, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
