import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // --- TEMA RENKLERİ ---
  static const Color pearl = Color.fromARGB(255, 255, 255, 255);
  static const Color midnight = Color(0xFF102E4A);

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Controllers (Arkadaşının güncellediği liste)
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _pharmacyName = TextEditingController();
  final _pharmacyDistrict = TextEditingController();
  static const List<String> _ankaraDistricts = [
    'Akyurt', 'Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çankaya',
    'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana',
    'Kahramankazan', 'Kalecik', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan',
    'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle',
  ];
  final _pharmacyAddress = TextEditingController();
  final _pharmacyPhone = TextEditingController();
  final _licenseNumber = TextEditingController(); // ✅ Yeni eklenen alan
  final _workingHours = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose();
    _nationalId.dispose(); _phone.dispose(); _password.dispose();
    _pharmacyName.dispose(); _pharmacyDistrict.dispose();
    _pharmacyAddress.dispose(); _pharmacyPhone.dispose();
    _licenseNumber.dispose(); _workingHours.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Zorunlu alan" : null;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

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
        licenseNumber: _licenseNumber.text.trim(), // ✅ Yeni alan servise gönderiliyor
        workingHours: _workingHours.text.trim(),
      );

      final token = (result["accessToken"] ?? result["token"])?.toString();
      if (token == null || token.isEmpty) throw Exception("Kayıt tamamlanamadı. Lütfen tekrar deneyin.");
      await TokenStore.set(token);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacyPanelHomePage()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(midnight),
          mainAxisMargin: 40,
        ),
      ),
      child: Scaffold(
        backgroundColor: pearl,
        body: Column(
          children: [
            // Üst Midnight Alanı
            Container(
              height: MediaQuery.of(context).size.height * 0.18,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [midnight, Color(0xFF1B4965)],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: pearl),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Center(
                      child: Text("ECZACI KAYDI", 
                        style: TextStyle(color: pearl, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ],
                ),
              ),
            ),
            // Alt Form Alanı
            Expanded(
              child: Container(
                color: const Color(0xFF1B4965),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [pearl, Color.fromARGB(255, 255, 248, 232)],
                    ),
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                          children: [
                            _sectionHeader("Kişisel Bilgiler"),
                            _buildInput(_firstName, "Ad", Icons.person, validator: (v) => (v == null || v.trim().length < 2) ? "En az 2 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_lastName, "Soyad", Icons.person_outline, validator: (v) => (v == null || v.trim().length < 2) ? "En az 2 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_email, "Email", Icons.email, validator: (v) {
                              if (v == null || v.isEmpty) return "Zorunlu";
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return "Geçersiz email";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_nationalId, "TC Kimlik No", Icons.badge, isNum: true, maxLength: 11, validator: (v) => (v?.length != 11) ? "11 haneli olmalı" : null),
                            const SizedBox(height: 12),
                            _buildInput(_phone, "Telefon (05xx xxx xx xx)", Icons.phone, isNum: true, maxLength: 11, validator: (v) {
                              final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (!RegExp(r'^05\d{9}$').hasMatch(digits)) return "05 ile başlayan 11 hane girin";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_password, "Şifre", Icons.lock, obscure: true, validator: (v) {
                              if (v == null || v.length < 7) return "En az 7 karakter";
                              if (!v.contains(RegExp(r'[A-Z]'))) return "En az 1 büyük harf";
                              if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return "En az 1 özel karakter";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_passwordConfirm, "Şifre (Tekrar)", Icons.lock_outline, obscure: true, validator: (v) {
                              if (v != _password.text) return "Şifreler eşleşmiyor";
                              return null;
                            }),
                            
                            const SizedBox(height: 30),
                            const Divider(color: midnight, thickness: 0.5),
                            const SizedBox(height: 20),
                            
                            _sectionHeader("Eczane Bilgileri"),
                            _buildInput(_pharmacyName, "Eczane Adı", Icons.local_pharmacy, validator: _req),
                            const SizedBox(height: 12),
                            _buildDistrictDropdown(),
                            const SizedBox(height: 12),
                            _buildInput(_pharmacyAddress, "Tam Adres", Icons.home, validator: _req),
                            const SizedBox(height: 12),
                            _buildInput(_pharmacyPhone, "Eczane Telefon (05xx xxx xx xx)", Icons.phone_in_talk, isNum: true, maxLength: 11, validator: (v) {
                              final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (digits.length != 11) return "11 haneli olmalı";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            // ✅ Arkadaşının eklediği yeni sicil numarası alanı
                            _buildInput(_licenseNumber, "Eczane Sicil Numarası", Icons.badge_outlined, validator: (v) => (v == null || v.trim().length < 3) ? "En az 3 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_workingHours, "Çalışma Saatleri (08:00 - 22:00)", Icons.access_time, validator: (v) {
                              if (v == null || !RegExp(r'^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$').hasMatch(v.trim())) return "Format: 08:00 - 22:00";
                              return null;
                            }),
                            
                            const SizedBox(height: 30),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                              ),
                            _buildMainButton(_loading ? "KAYDEDİLİYOR..." : "KAYDI TAMAMLA", _handleRegister),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(title, style: const TextStyle(color: midnight, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDistrictDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: midnight.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _pharmacyDistrict.text.isEmpty ? null : _pharmacyDistrict.text,
              isExpanded: true,
              style: const TextStyle(fontSize: 15, color: midnight),
              decoration: InputDecoration(
                hintText: 'İlçe',
                hintStyle: TextStyle(color: midnight.withOpacity(0.4), fontSize: 14),
                prefixIcon: Icon(Icons.location_city, color: midnight.withOpacity(0.7), size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
              items: _ankaraDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _pharmacyDistrict.text = v ?? ''),
              validator: (v) => (v == null || v.isEmpty) ? 'İlçe seçin' : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool isNum = false, int? maxLength, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: midnight.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(fontSize: 15, color: midnight),
              keyboardType: isNum ? TextInputType.number : TextInputType.emailAddress,
              maxLength: maxLength,
              inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : null,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: midnight.withOpacity(0.4), fontSize: 14),
                prefixIcon: Icon(icon, color: midnight.withOpacity(0.7), size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                counterText: '',
              ),
              validator: validator,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [midnight, Color(0xFF1B4965)]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: midnight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _loading ? null : onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pearl)),
      ),
    );
  }
}