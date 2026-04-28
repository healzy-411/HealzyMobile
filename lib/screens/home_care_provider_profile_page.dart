import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/home_care_panel_api_service.dart';
import '../services/upload_api_service.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';
import '../utils/error_messages.dart';

class HomeCareProviderProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const HomeCareProviderProfilePage({super.key, required this.profile});

  @override
  State<HomeCareProviderProfilePage> createState() => _HomeCareProviderProfilePageState();
}

class _HomeCareProviderProfilePageState extends State<HomeCareProviderProfilePage> {
  final _api = HomeCarePanelApiService(baseUrl: ApiConfig.baseUrl);
  final _uploadApi = UploadApiService(baseUrl: ApiConfig.baseUrl);

  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  // Read-only
  String? _licenseNumber;

  String? _imageUrl;
  File? _pickedImage;

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _providerName;
  late final TextEditingController _providerPhone;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _phone = TextEditingController();
    _providerName = TextEditingController(text: widget.profile['name'] ?? '');
    _providerPhone = TextEditingController(text: widget.profile['phone'] ?? '');
    _city = TextEditingController(text: widget.profile['city'] ?? '');
    _district = TextEditingController(text: widget.profile['district'] ?? '');
    _address = TextEditingController(text: widget.profile['address'] ?? '');
    _description = TextEditingController(text: widget.profile['description'] ?? '');
    _imageUrl = widget.profile['imageUrl'];
    _loadInfo();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _providerName.dispose();
    _providerPhone.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _api.getRegistrationInfo();
      if (!mounted) return;
      setState(() {
        _firstName.text = (info['firstName'] ?? '').toString();
        _lastName.text = (info['lastName'] ?? '').toString();
        _phone.text = (info['phone'] ?? '').toString();
        _providerName.text = (info['providerName'] ?? _providerName.text).toString();
        _providerPhone.text = (info['providerPhone'] ?? _providerPhone.text).toString();
        _city.text = (info['city'] ?? _city.text).toString();
        _district.text = (info['district'] ?? _district.text).toString();
        _address.text = (info['address'] ?? _address.text).toString();
        _description.text = (info['description'] ?? _description.text).toString();
        _licenseNumber = (info['licenseNumber'] as String?);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? uploadedUrl;
      if (_pickedImage != null) {
        setState(() => _uploading = true);
        uploadedUrl = await _uploadApi.uploadImage(_pickedImage!);
        setState(() => _uploading = false);
      }

      final body = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'providerName': _providerName.text.trim(),
        'providerPhone': _providerPhone.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'description': _description.text.trim(),
      };
      if (uploadedUrl != null) body['imageUrl'] = uploadedUrl;

      await _api.updateProviderInfo(body);

      // Web'le aynı: kaydettikten sonra fresh profil çek
      try {
        final fresh = await _api.getProfile();
        if (mounted) {
          _imageUrl = (fresh['imageUrl'] as String?) ?? uploadedUrl ?? _imageUrl;
        }
      } catch (_) {
        if (uploadedUrl != null) _imageUrl = uploadedUrl;
      }

      if (!mounted) return;
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvatar(bool isDark) {
    final baseUrl = ApiConfig.baseUrl;
    final accent = isDark ? Colors.white : AppColors.midnight;
    if (_pickedImage != null) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(_pickedImage!),
      );
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
      child: Icon(Icons.medical_services, size: 48, color: accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = widget.profile['isActive'] ?? true;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final appBarBg = isDark ? AppColors.darkBg : Colors.white;
    final appBarFg = isDark ? Colors.white : AppColors.midnight;
    final accent = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: const Text('Sağlayıcı Bilgileri'),
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarFg),
        actions: [
          if (!_editing && !_loading && _error == null)
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
        child: _loading
            ? Center(child: CircularProgressIndicator(color: titleC))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadInfo,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                : ListView(
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
                                : Icon(Icons.photo_camera, color: accent),
                            label: Text(
                              _uploading ? 'Yükleniyor...' : 'Fotoğraf Seç',
                              style: TextStyle(color: accent),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark
                                    ? const Color(0xFF10B981).withValues(alpha: 0.22)
                                    : Colors.green.shade50)
                                : (isDark
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.22)
                                    : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                              color: isActive
                                  ? (isDark ? const Color(0xFF34D399) : Colors.green)
                                  : (isDark ? const Color(0xFFF87171) : Colors.red),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_editing)
                        ..._buildEditForm(isDark, titleC, muted, accent)
                      else
                        ..._buildReadOnlyView(isDark),
                      if (!_editing) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleDeleteAccount,
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            label: const Text(
                              'Hesabımı Sil',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF132B44) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sağlayıcı Hesabını Sil',
          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sağlayıcınızı ve hesabınızı kalıcı olarak silmek istiyorsanız aşağıya "onaylıyorum" yazın.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu işlem geri alınamaz. Çalışan atamaları, geçmiş talepler ve tüm veriler silinecektir.',
              style: TextStyle(color: Colors.red.shade400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                hintText: 'onaylıyorum',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hesabımı Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final confirmation = confirmController.text.trim();
    if (confirmation != 'onaylıyorum') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Onay metni hatalı. 'onaylıyorum' yazmalısınız.")),
      );
      return;
    }

    try {
      await _api.deleteAccount(confirmation);
      if (!mounted) return;
      Navigator.of(context).pop({'deleted': true});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  List<Widget> _buildEditForm(bool isDark, Color titleC, Color muted, Color accent) {
    return [
      Row(
        children: [
          Expanded(child: _editField('Ad', _firstName, Icons.person, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _editField('Soyad', _lastName, Icons.person_outline, isDark)),
        ],
      ),
      _editField('Telefon Numarası', _phone, Icons.phone, isDark, keyboardType: TextInputType.phone, maxLength: 11),
      _editField('Sicil Numarası (değiştirilemez)', TextEditingController(text: _licenseNumber ?? '-'),
          Icons.badge_outlined, isDark, enabled: false),
      Row(
        children: [
          Expanded(child: _editField('Sağlayıcı Adı', _providerName, Icons.medical_services, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _editField('Sağlayıcı Telefonu', _providerPhone, Icons.call, isDark, keyboardType: TextInputType.phone, maxLength: 11)),
        ],
      ),
      Row(
        children: [
          Expanded(child: _editField('Şehir', _city, Icons.location_city, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _editField('İlçe', _district, Icons.location_on, isDark)),
        ],
      ),
      _editField('Adres', _address, Icons.home, isDark, maxLines: 2),
      _editField('Açıklama', _description, Icons.description, isDark, maxLines: 3),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _editing = false;
                        _pickedImage = null;
                        // Form values will refresh via _loadInfo on next entry; here we keep them
                      }),
              style: OutlinedButton.styleFrom(
                foregroundColor: titleC,
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.midnight.withValues(alpha: 0.3),
                ),
              ),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1B4965) : AppColors.midnight,
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildReadOnlyView(bool isDark) {
    final fullName = [_firstName.text, _lastName.text].where((s) => s.isNotEmpty).join(' ');
    return [
      _infoTile(Icons.person, 'Ad Soyad', fullName, isDark),
      _infoTile(Icons.phone, 'Telefon Numarası', _phone.text, isDark),
      _infoTile(Icons.badge_outlined, 'Sicil Numarasi', _licenseNumber ?? '-', isDark),
      _infoTile(Icons.medical_services, 'Sağlayıcı Adı', _providerName.text, isDark),
      _infoTile(Icons.call, 'Sağlayıcı Telefon Numarası', _providerPhone.text, isDark),
      _infoTile(Icons.location_city, 'Şehir', _city.text, isDark),
      _infoTile(Icons.location_on, 'İlçe', _district.text, isDark),
      _infoTile(Icons.home, 'Adres', _address.text, isDark),
      _infoTile(Icons.description, 'Açıklama', _description.text, isDark),
    ];
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    final accent = isDark ? Colors.white : AppColors.midnight;
    final labelC = isDark ? Colors.white.withValues(alpha: 0.7) : null;
    final textC = isDark ? Colors.white : null;
    final fillC = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.6)
        : (enabled ? null : Colors.grey.shade100);
    final borderC = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade400;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(color: enabled ? textC : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade600)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelC),
          prefixIcon: Icon(icon, color: accent),
          filled: isDark || !enabled,
          fillColor: fillC,
          counterText: maxLength != null ? null : '',
          border: OutlineInputBorder(borderSide: BorderSide(color: borderC)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderC)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent)),
          disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderC)),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark) {
    final accent = isDark ? Colors.white : AppColors.midnight;
    final labelC = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey;
    final valueC = isDark ? Colors.white : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF132B44).withValues(alpha: 0.9) : null,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.08)) : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: accent),
        title: Text(label, style: TextStyle(fontSize: 14, color: labelC)),
        subtitle: Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(fontSize: 15, color: valueC),
        ),
      ),
    );
  }
}
