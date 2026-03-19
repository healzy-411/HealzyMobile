import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/home_care_panel_api_service.dart';
import '../services/upload_api_service.dart';

class HomeCareProviderProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const HomeCareProviderProfilePage({super.key, required this.profile});

  @override
  State<HomeCareProviderProfilePage> createState() => _HomeCareProviderProfilePageState();
}

class _HomeCareProviderProfilePageState extends State<HomeCareProviderProfilePage> {
  final _api = HomeCarePanelApiService(baseUrl: "http://localhost:5009");
  final _uploadApi = UploadApiService(baseUrl: "http://localhost:5009");
  bool _editing = false;
  bool _saving = false;
  String? _imageUrl;
  File? _pickedImage;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile["name"] ?? "");
    _phone = TextEditingController(text: widget.profile["phone"] ?? "");
    _city = TextEditingController(text: widget.profile["city"] ?? "");
    _district = TextEditingController(text: widget.profile["district"] ?? "");
    _address = TextEditingController(text: widget.profile["address"] ?? "");
    _description = TextEditingController(text: widget.profile["description"] ?? "");
    _imageUrl = widget.profile["imageUrl"];
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _description.dispose();
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
        "phone": _phone.text.trim(),
        "city": _city.text.trim(),
        "district": _district.text.trim(),
        "address": _address.text.trim(),
        "description": _description.text.trim().isEmpty ? null : _description.text.trim(),
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
    const baseUrl = "http://localhost:5009";
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
      backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.15),
      child: const Icon(Icons.medical_services, size: 48, color: Color(0xFF00A79D)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.profile["isActive"] ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saglayici Bilgileri"),
        backgroundColor: const Color(0xFF00A79D),
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
                icon: const Icon(Icons.photo_camera, color: Color(0xFF00A79D)),
                label: const Text("Resim Sec", style: TextStyle(color: Color(0xFF00A79D))),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? "Aktif" : "Pasif",
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_editing) ...[
            _editField("Saglayici Adi", _name, Icons.medical_services),
            _editField("Telefon", _phone, Icons.phone),
            _editField("Il", _city, Icons.location_city),
            _editField("Ilce", _district, Icons.location_city),
            _editField("Adres", _address, Icons.home, maxLines: 2),
            _editField("Aciklama", _description, Icons.description, maxLines: 3),
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
                      backgroundColor: const Color(0xFF00A79D),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Kaydediliyor..." : "Kaydet"),
                  ),
                ),
              ],
            ),
          ] else ...[
            _infoTile(Icons.medical_services, "Saglayici Adi", _name.text),
            _infoTile(Icons.phone, "Telefon", _phone.text),
            _infoTile(Icons.location_city, "Il", _city.text),
            _infoTile(Icons.location_city, "Ilce", _district.text),
            _infoTile(Icons.home, "Adres", _address.text),
            _infoTile(Icons.description, "Aciklama", _description.text),
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
          prefixIcon: Icon(icon, color: const Color(0xFF00A79D)),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00A79D)),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value.isEmpty ? "-" : value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
