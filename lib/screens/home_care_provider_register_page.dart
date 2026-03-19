import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import 'home_care_provider_panel_home_page.dart';

class HomeCareProviderRegisterPage extends StatefulWidget {
  final AuthService authService;

  const HomeCareProviderRegisterPage({super.key, required this.authService});

  @override
  State<HomeCareProviderRegisterPage> createState() => _HomeCareProviderRegisterPageState();
}

class _HomeCareProviderRegisterPageState extends State<HomeCareProviderRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Kisisel bilgiler
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  // Saglayici bilgileri
  final _providerName = TextEditingController();
  final _providerPhone = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _nationalId.dispose();
    _phone.dispose();
    _password.dispose();
    _providerName.dispose();
    _providerPhone.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authService.registerHomeCareProvider(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        nationalId: _nationalId.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        providerName: _providerName.text.trim(),
        providerPhone: _providerPhone.text.trim(),
        city: _city.text.trim(),
        district: _district.text.trim(),
        address: _address.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );

      final token = (result["accessToken"] ?? result["token"])?.toString();
      if (token == null || token.isEmpty) {
        throw Exception("Token alinamadi.");
      }

      await TokenStore.set(token);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeCareProviderPanelHomePage()),
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
        title: const Text("Serum Saglayici Kayit"),
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

                const Text(
                  "Saglayici Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _providerName,
                  decoration: const InputDecoration(
                    labelText: "Saglayici Adi",
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _providerPhone,
                  decoration: const InputDecoration(
                    labelText: "Saglayici Telefon",
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
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: "Il",
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (v.trim().length < 2) return "En az 2 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _district,
                  decoration: const InputDecoration(
                    labelText: "Ilce",
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (v.trim().length < 2) return "En az 2 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 2,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Zorunlu";
                    if (v.trim().length < 10) return "En az 10 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: "Aciklama (opsiyonel)",
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
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
                    icon: const Icon(Icons.medical_services),
                    label: Text(_loading ? "Kaydediliyor..." : "Serum Saglayici Kayit Ol"),
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
