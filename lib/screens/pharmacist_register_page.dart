import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import 'pharmacy_panel_home_page.dart';

class PharmacistRegisterPage extends StatefulWidget {
  final AuthService authService;

  const PharmacistRegisterPage({super.key, required this.authService});

  @override
  State<PharmacistRegisterPage> createState() => _PharmacistRegisterPageState();
}

class _PharmacistRegisterPageState extends State<PharmacistRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Kişisel bilgiler
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  // Eczane bilgileri
  final _pharmacyName = TextEditingController();
  final _pharmacyDistrict = TextEditingController();
  final _pharmacyAddress = TextEditingController();
  final _pharmacyPhone = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _workingHours = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _nationalId.dispose();
    _phone.dispose();
    _password.dispose();
    _pharmacyName.dispose();
    _pharmacyDistrict.dispose();
    _pharmacyAddress.dispose();
    _pharmacyPhone.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _workingHours.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authService.registerPharmacist(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        nationalId: _nationalId.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        pharmacyName: _pharmacyName.text.trim(),
        pharmacyDistrict: _pharmacyDistrict.text.trim(),
        pharmacyAddress: _pharmacyAddress.text.trim(),
        pharmacyPhone: _pharmacyPhone.text.trim(),
        latitude: double.tryParse(_latitude.text.trim()) ?? 0,
        longitude: double.tryParse(_longitude.text.trim()) ?? 0,
        workingHours: _workingHours.text.trim(),
      );

      final token = (result["accessToken"] ?? result["token"])?.toString();
      if (token == null || token.isEmpty) {
        throw Exception("Token alinamadi.");
      }

      await TokenStore.set(token);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PharmacyPanelHomePage()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Eczaci Kayit"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Kişisel bilgiler başlığı
                const Text(
                  "Kisisel Bilgiler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(
                    labelText: "Ad",
                    prefixIcon: Icon(Icons.person),
                  ),
                  maxLength: 100,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (v.trim().length < 2) return "En az 2 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(
                    labelText: "Soyad",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  maxLength: 100,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (v.trim().length < 2) return "En az 2 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 200,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return "Gecersiz email";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalId,
                  decoration: const InputDecoration(
                    labelText: "TC Kimlik No",
                    prefixIcon: Icon(Icons.badge),
                  ),
                  maxLength: 11,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (!RegExp(r'^\d{11}$').hasMatch(v.trim())) return "TC Kimlik 11 haneli olmali";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: "Telefon",
                    hintText: "05xx xxx xx xx",
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return "5 ile baslayan 10 haneli olmali";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: "Sifre",
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Zorunlu";
                    if (v.length < 7) return "En az 7 karakter";
                    if (!v.contains(RegExp(r'[A-Z]'))) return "En az 1 buyuk harf";
                    if (!v.contains(RegExp(r'[0-9]'))) return "En az 1 rakam";
                    if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return "En az 1 ozel karakter";
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Eczane bilgileri başlığı
                const Text(
                  "Eczane Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _pharmacyName,
                  decoration: const InputDecoration(
                    labelText: "Eczane Adi",
                    prefixIcon: Icon(Icons.local_pharmacy),
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pharmacyDistrict,
                  decoration: const InputDecoration(
                    labelText: "Ilce",
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pharmacyAddress,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 2,
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pharmacyPhone,
                  decoration: const InputDecoration(
                    labelText: "Eczane Telefon",
                    prefixIcon: Icon(Icons.phone_in_talk),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return "5 ile baslayan 10 haneli olmali";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        decoration: const InputDecoration(
                          labelText: "Enlem",
                          prefixIcon: Icon(Icons.my_location),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v.trim());
                          if (val == null) return "Gecersiz deger";
                          if (val < 36 || val > 42) return "Turkiye sinirlari (36-42)";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        decoration: const InputDecoration(
                          labelText: "Boylam",
                          prefixIcon: Icon(Icons.my_location),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v.trim());
                          if (val == null) return "Gecersiz deger";
                          if (val < 26 || val > 45) return "Turkiye sinirlari (26-45)";
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _workingHours,
                  decoration: const InputDecoration(
                    labelText: "Calisma Saatleri",
                    hintText: "08:00 - 22:00",
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (!RegExp(r'^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$').hasMatch(v.trim())) return "Format: 08:00 - 22:00";
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleRegister,
                    icon: const Icon(Icons.local_pharmacy),
                    label: Text(_loading ? "Kaydediliyor..." : "Eczane Kayit Ol"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A79D),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
