import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../services/upload_api_service.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const PharmacyProfilePage({super.key, required this.profile});

  @override
  State<PharmacyProfilePage> createState() => _PharmacyProfilePageState();
}

class _PharmacyProfilePageState extends State<PharmacyProfilePage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);
  final _uploadApi = UploadApiService(baseUrl: ApiConfig.baseUrl);
  bool _editing = false;
  bool _saving = false;
  String? _imageUrl;
  File? _pickedImage;

  late final TextEditingController _name;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _workingHours;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile["name"] ?? "");
    _district = TextEditingController(text: widget.profile["district"] ?? "");
    _address = TextEditingController(text: widget.profile["address"] ?? "");
    _phone = TextEditingController(text: widget.profile["phone"] ?? "");
    _latitude = TextEditingController(text: "${widget.profile["latitude"] ?? 0}");
    _longitude = TextEditingController(text: "${widget.profile["longitude"] ?? 0}");
    _workingHours = TextEditingController(text: widget.profile["workingHours"] ?? "");
    _imageUrl = widget.profile["imageUrl"];
  }

  @override
  void dispose() {
    _name.dispose();
    _district.dispose();
    _address.dispose();
    _phone.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _workingHours.dispose();
    super.dispose();
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
        uploadedUrl = await _uploadApi.uploadImage(_pickedImage!);
      }

      final data = <String, dynamic>{
        "name": _name.text.trim(),
        "district": _district.text.trim(),
        "address": _address.text.trim(),
        "phone": _phone.text.trim(),
        "latitude": double.tryParse(_latitude.text) ?? 0,
        "longitude": double.tryParse(_longitude.text) ?? 0,
        "workingHours": _workingHours.text.trim(),
      };
      if (uploadedUrl != null) data["imageUrl"] = uploadedUrl;

      await _api.updateProfile(data);
      if (!mounted) return;
      if (uploadedUrl != null) _imageUrl = uploadedUrl;
      _pickedImage = null;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bilgiler guncellendi.")),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvatar() {
    final baseUrl = ApiConfig.baseUrl;
    if (_pickedImage != null) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(_pickedImage!),
      );
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage('$baseUrl$_imageUrl'),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: const Color(0xFF102E4A).withValues(alpha: 0.15),
      child: const Icon(Icons.local_pharmacy, size: 48, color: Color(0xFF102E4A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.profile["isApproved"] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Eczane Bilgileri"),
        backgroundColor: const Color(0xFF102E4A),
        foregroundColor: Colors.white,
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
              tooltip: "Duzenle",
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: _buildAvatar()),
          if (_editing) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_camera, color: Color(0xFF102E4A)),
                label: const Text("Resim Sec", style: TextStyle(color: Color(0xFF102E4A))),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isApproved ? "Onayli" : "Onay Bekliyor",
                style: TextStyle(
                  color: isApproved ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_editing) ...[
            _editField("Eczane Adi", _name, Icons.local_pharmacy),
            _editField("Ilce", _district, Icons.location_city),
            _editField("Adres", _address, Icons.home, maxLines: 2),
            _editField("Telefon", _phone, Icons.phone),
            _editField("Calisma Saatleri", _workingHours, Icons.access_time),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _editing = false),
                    child: const Text("Iptal"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF102E4A),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Kaydediliyor..." : "Kaydet"),
                  ),
                ),
              ],
            ),
          ] else ...[
            _infoTile(Icons.local_pharmacy, "Eczane Adi", _name.text),
            _infoTile(Icons.location_city, "Ilce", _district.text),
            _infoTile(Icons.home, "Adres", _address.text),
            _infoTile(Icons.phone, "Telefon", _phone.text),
            _infoTile(Icons.access_time, "Calisma Saatleri", _workingHours.text),
          ],
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF102E4A)),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF102E4A)),
        title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(value.isEmpty ? "-" : value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
