import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utils/error_messages.dart';

import '../Models/address_model.dart';
import '../services/token_store.dart';
import '../theme/app_colors.dart';

import '../Models/district_model.dart';

import '../Models/neighborhood_model.dart';
import '../services/neighborhood_api_service.dart';
import '../services/api_service.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/healzy_bottom_nav.dart';

class EditAddressPage extends StatefulWidget {
  final String baseUrl; // ör: https://api.apphealzy.com
  final AddressDto address;

  const EditAddressPage({
    super.key,
    required this.baseUrl,
    required this.address,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _neighborhood;
  late final TextEditingController _addressLine;
  late final TextEditingController _postalCode;

  // ✅ yeni: Adres Tarifi
  late final TextEditingController _addressDescription;

  late bool _isDefault;

  bool _loading = false;
  String? _error;

  // ✅ Yeni state
  final _api = ApiService(); // districts buradan geliyor
  late final _neighborhoodApi = NeighborhoodApiService(baseUrl: widget.baseUrl);

  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;

  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];

  District? _selectedDistrict;
  Neighborhood? _selectedNeighborhood;

  @override
  void initState() {
    super.initState();

    final a = widget.address;
    _title = TextEditingController(text: a.title);
    _fullName = TextEditingController(text: a.fullName);
    _phone = TextEditingController(text: _normalizePhone(a.phone));

    // Ankara sabit dersen bunu kilitle:
    _city = TextEditingController(text: a.city.isNotEmpty ? a.city : "Ankara");

    _district = TextEditingController(text: a.district);
    _neighborhood = TextEditingController(text: a.neighborhood);

    _addressLine = TextEditingController(text: a.addressLine);
    _postalCode = TextEditingController(text: a.postalCode ?? "");

    // ✅ yeni alan init
    _addressDescription = TextEditingController(text: a.addressDescription ?? "");

    _isDefault = a.isDefault;

    // dropdown verilerini yükle
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadDistricts();

    // mevcut district ismine göre seçili yap
    final existingDistrictName = _district.text.trim();
    if (existingDistrictName.isNotEmpty) {
      _selectedDistrict = _districts.firstWhere(
        (d) => d.name.trim().toLowerCase() == existingDistrictName.toLowerCase(),
        orElse: () => _districts.isNotEmpty ? _districts.first : District(id: 0, name: ''),
      );
      if (_selectedDistrict != null && _selectedDistrict!.id != 0) {
        await _loadNeighborhoods(_selectedDistrict!.id);

        // mevcut neighborhood ismine göre seçili yap
        final existingNeighborhoodName = _neighborhood.text.trim();
        if (existingNeighborhoodName.isNotEmpty) {
          _selectedNeighborhood = _neighborhoods.firstWhere(
            (n) => n.name.trim().toLowerCase() == existingNeighborhoodName.toLowerCase(),
            orElse: () => _neighborhoods.isNotEmpty ? _neighborhoods.first : Neighborhood(id: 0, name: ''),
          );
          if (_selectedNeighborhood != null && _selectedNeighborhood!.id != 0) {
            _neighborhood.text = _selectedNeighborhood!.name;
          }
        }
      }
    }
    setState(() {});
  }

  Future<void> _loadDistricts() async {
    setState(() => _loadingDistricts = true);
    try {
      _districts = await _api.getDistricts();
    } catch (e) {
      _error = "İlçeler yüklenemedi: $e";
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _loadNeighborhoods(int districtId) async {
    setState(() => _loadingNeighborhoods = true);
    try {
      _neighborhoods = await _neighborhoodApi.getByDistrictId(districtId);
    } catch (e) {
      _error = "Mahalleler yüklenemedi: $e";
      _neighborhoods = [];
    } finally {
      if (mounted) setState(() => _loadingNeighborhoods = false);
    }
  }

  Future<void> _pickDistrict() async {
    if (_loadingDistricts) return;
    if (_districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İlçe listesi boş.")),
      );
      return;
    }

    final picked = await showSearchPickerSheet<District>(
      context: context,
      title: "İlçe Seç",
      items: _districts,
      label: (d) => d.name,
    );

    if (picked == null) return;

    setState(() {
      _selectedDistrict = picked;
      _district.text = picked.name;

      // ilçe değişince mahalle reset
      _selectedNeighborhood = null;
      _neighborhood.text = "";
      _neighborhoods = [];
    });

    await _loadNeighborhoods(picked.id);
  }

  Future<void> _pickNeighborhood() async {
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce ilçe seçmelisin.")),
      );
      return;
    }
    if (_loadingNeighborhoods) return;
    if (_neighborhoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu ilçe için mahalle bulunamadı.")),
      );
      return;
    }

    final picked = await showSearchPickerSheet<Neighborhood>(
      context: context,
      title: "Mahalle Seç",
      items: _neighborhoods,
      label: (n) => n.name,
    );

    if (picked == null) return;

    setState(() {
      _selectedNeighborhood = picked;
      _neighborhood.text = picked.name;
    });
  }

  Future<Map<String, String>> _headers() async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) throw Exception("Token yok.");
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<AddressDto> _updateAddress() async {
    final uri = Uri.parse("${widget.baseUrl}/api/addresses/${widget.address.id}");

    final body = {
      "title": _title.text.trim(),
      "fullName": _fullName.text.trim(),
      "phone": _phone.text.trim(),

      // Ankara sabit dersen:
      "city": _city.text.trim().isEmpty ? "Ankara" : _city.text.trim(),

      "district": _district.text.trim(),
      "neighborhood": _neighborhood.text.trim(),

      "addressLine": _addressLine.text.trim(),
      "postalCode": _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
      "latitude": null,
      "longitude": null,
      "isDefault": _isDefault,

      // ✅ yeni alan
      "addressDescription": _addressDescription.text.trim().isEmpty
          ? null
          : _addressDescription.text.trim(),
    };

    final res = await http.put(uri, headers: await _headers(), body: jsonEncode(body));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AddressDto.fromJson(decoded);
    }

    String msg = "Adres güncellenemedi (${res.statusCode})";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded["message"] != null) msg = decoded["message"].toString();
    } catch (_) {}

    throw Exception(msg);
  }

  @override
  void dispose() {
    _title.dispose();
    _fullName.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _neighborhood.dispose();
    _addressLine.dispose();
    _postalCode.dispose();

    // ✅ yeni alan dispose
    _addressDescription.dispose();

    super.dispose();
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return "Zorunlu alan";
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // district/neighborhood zorunlu kılalım
    if (_district.text.trim().isEmpty) {
      setState(() => _error = "İlçe seçmelisin.");
      return;
    }
    if (_neighborhood.text.trim().isEmpty) {
      setState(() => _error = "Mahalle seçmelisin.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final updated = await _updateAddress();
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _fieldLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(text, style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.midnight,
      )),
    );
  }

  InputDecoration _glassDecoration({String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.midnight.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.midnight.withValues(alpha: 0.15), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? AppColors.pearl : AppColors.midnight, width: 1.8),
      ),
      counterText: '',
    );
  }

  Widget _pickerField({
    required String label,
    required String valueText,
    required VoidCallback onTap,
    String? hint,
    bool disabled = false,
    bool loading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.midnight.withValues(alpha: 0.15), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueText.isNotEmpty ? valueText : (hint ?? ""),
                    style: TextStyle(
                      color: valueText.isNotEmpty
                          ? (isDark ? AppColors.darkTextPrimary : AppColors.midnight)
                          : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.arrow_drop_down, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final districtText = _district.text.trim();
    final neighborhoodText = _neighborhood.text.trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(title: const Text("Adresi Düzenle")),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkPageGradient : AppColors.lightPageGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),

                  _fieldLabel("Başlık (Ev/İş)"),
                  TextFormField(
                    controller: _title,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(hint: "Örn: Evim, İş Yerim"),
                    validator: _req,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("Ad Soyad"),
                  TextFormField(
                    controller: _fullName,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(),
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü ]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu alan";
                      if (v.trim().length < 3) return "En az 3 karakter";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("Telefon"),
                  TextFormField(
                    controller: _phone,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(hint: "0xxx xxx xx xx"),
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu alan";
                      final digits = v.trim();
                      if (!RegExp(r'^0\d{10}$').hasMatch(digits)) {
                        return "0 ile başlayan 11 haneli numara girin";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("İl"),
                  TextFormField(
                    controller: _city,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(),
                    validator: _req,
                    readOnly: true,
                  ),
                  const SizedBox(height: 14),

                  _pickerField(
                    label: "İlçe",
                    valueText: districtText,
                    hint: _loadingDistricts ? "Yükleniyor..." : "İlçe seç",
                    onTap: _pickDistrict,
                    loading: _loadingDistricts,
                  ),
                  const SizedBox(height: 14),

                  _pickerField(
                    label: "Mahalle",
                    valueText: neighborhoodText,
                    hint: _selectedDistrict == null
                        ? "Önce ilçe seç"
                        : (_loadingNeighborhoods ? "Yükleniyor..." : "Mahalle seç"),
                    onTap: _pickNeighborhood,
                    disabled: _selectedDistrict == null,
                    loading: _loadingNeighborhoods,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("Açık Adres"),
                  TextFormField(
                    controller: _addressLine,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(),
                    maxLines: 2,
                    maxLength: 500,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu alan";
                      if (v.trim().length < 10) return "En az 10 karakter";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("Adres Tarifi (opsiyonel)"),
                  TextFormField(
                    controller: _addressDescription,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(hint: "Kapıcıya bırakın vb."),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel("Posta Kodu (opsiyonel)"),
                  TextFormField(
                    controller: _postalCode,
                    style: TextStyle(color: textColor),
                    decoration: _glassDecoration(hint: "06xxx"),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!RegExp(r'^\d{5}$').hasMatch(v.trim())) return "5 haneli olmali";
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    title: Text("Varsayılan adres yap", style: TextStyle(color: textColor)),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.midnight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_loading ? "Kaydediliyor..." : "Kaydet"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _normalizePhone(String? raw) {
  if (raw == null) return '';
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10 && digits.startsWith('5')) {
    digits = '0$digits';
  }
  if (digits.length > 11) digits = digits.substring(0, 11);
  return digits;
}