import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'email_verify_page.dart';

class HomeCareProviderRegisterPage extends StatefulWidget {
  final AuthService authService;

  const HomeCareProviderRegisterPage({super.key, required this.authService});

  @override
  State<HomeCareProviderRegisterPage> createState() => _HomeCareProviderRegisterPageState();
}

class _HomeCareProviderRegisterPageState extends State<HomeCareProviderRegisterPage> {
  // --- TEMA RENKLERİ ---
  static const Color pearl = Color.fromARGB(255, 255, 255, 255);
  static const Color midnight = Color(0xFF102E4A);

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _loading = false;
  String? _error;

  // Controllers (Arkadaşının eklediği licenseNumber dahil güncel liste)
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _providerName = TextEditingController();
  final _providerPhone = TextEditingController();
  final _address = TextEditingController();
  final _licenseNumber = TextEditingController(); // ✅ Yeni eklenen alan
  final _description = TextEditingController();

  static const String _city = "Ankara";
  static const List<String> _ankaraDistricts = [
    'Akyurt', 'Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çankaya',
    'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana',
    'Kahramankazan', 'Kalecik', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan',
    'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle',
  ];
  String? _selectedDistrict;

  @override
  void dispose() {
    _scrollController.dispose();
    _firstName.dispose(); _lastName.dispose(); _email.dispose();
    _nationalId.dispose(); _phone.dispose(); _password.dispose();
    _providerName.dispose(); _providerPhone.dispose();
    _address.dispose();
    _licenseNumber.dispose(); _description.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Zorunlu alan" : null;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await widget.authService.registerHomeCareProvider(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        nationalId: _nationalId.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        providerName: _providerName.text.trim(),
        providerPhone: _providerPhone.text.trim(),
        city: _city,
        district: _selectedDistrict ?? '',
        address: _address.text.trim(),
        licenseNumber: _licenseNumber.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );

      if (!mounted) return;

      final verifyResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerifyPage(
            authService: widget.authService,
            email: _email.text.trim(),
            password: _password.text,
          ),
        ),
      );

      if (!mounted) return;
      if (verifyResult is Map) {
        Navigator.pop(context, verifyResult);
      }
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
            // Üst Midnight Alanı (Kavisli Header)
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
                      child: Text("SERUM SAĞLAYICI", 
                        style: TextStyle(color: pearl, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
                      colors: [Color(0xFFFFFFFF), Color(0xFFD4EAF7), Color(0xFFB8D8EB)],
                    ),
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                          children: [
                            _sectionHeader("Kişisel Bilgiler"),
                            _buildInput(_firstName, "Ad", Icons.person, validator: (v) => (v == null || v.trim().length < 2) ? "En az 2 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_lastName, "Soyad", Icons.person_outline, validator: (v) => (v == null || v.trim().length < 2) ? "En az 2 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_email, "Email", Icons.email, validator: (v) {
                              if (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return "Geçersiz email";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_nationalId, "TC Kimlik No", Icons.badge, isNum: true, maxLength: 11, validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Zorunlu alan";
                              final tc = v.trim();
                              if (tc.length != 11) return "11 haneli olmalı";
                              if (!RegExp(r'^\d{11}$').hasMatch(tc)) return "Sadece rakam giriniz";
                              if (tc.startsWith('0')) return "TC kimlik no 0 ile başlayamaz";
                              final lastDigit = int.parse(tc[10]);
                              if (lastDigit % 2 != 0) return "TC kimlik no çift sayı ile bitmeli";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_phone, "Telefon (0xxx xxx xx xx)", Icons.phone, isNum: true, maxLength: 11, validator: (v) {
                              final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (!RegExp(r'^0\d{10}$').hasMatch(digits)) return "0 ile başlayan 11 hane girin";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildInput(_password, "Şifre", Icons.lock, obscure: true, validator: (v) {
                              if (v == null || v.length < 7) return "En az 7 karakter";
                              if (!v.contains(RegExp(r'[A-Z]'))) return "En az 1 büyük harf";
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
                            
                            _sectionHeader("Sağlayıcı Bilgileri"),
                            _buildInput(_providerName, "Sağlayıcı / Kurum Adı", Icons.medical_services, validator: _req),
                            const SizedBox(height: 12),
                            _buildInput(_providerPhone, "Kurum Telefon (0xxx xxx xx xx)", Icons.phone_in_talk, isNum: true, maxLength: 11, validator: (v) {
                              final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (!RegExp(r'^0\d{10}$').hasMatch(digits)) return "0 ile başlayan 11 hane girin";
                              return null;
                            }),
                            const SizedBox(height: 12),
                            _buildDistrictDropdown(),
                            const SizedBox(height: 12),
                            _buildInput(_address, "Tam Adres", Icons.home, validator: (v) => (v == null || v.trim().length < 10) ? "En az 10 karakter" : null),
                            const SizedBox(height: 12),
                            // ✅ Arkadaşının eklediği Sicil No alanı
                            _buildInput(_licenseNumber, "Sicil Numarası", Icons.badge_outlined, validator: (v) => (v == null || v.trim().length < 3) ? "En az 3 karakter" : null),
                            const SizedBox(height: 12),
                            _buildInput(_description, "Açıklama (Hizmetler vb.)", Icons.description),
                            
                            const SizedBox(height: 30),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
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
              value: _selectedDistrict,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 15, color: midnight),
              decoration: InputDecoration(
                hintText: 'İlçe (Ankara)',
                hintStyle: TextStyle(color: midnight.withOpacity(0.4), fontSize: 14),
                prefixIcon: Icon(Icons.map, color: midnight.withOpacity(0.7), size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
              items: _ankaraDistricts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDistrict = v),
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
              inputFormatters: [
                if (isNum) FilteringTextInputFormatter.digitsOnly,
                if (isNum) FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
              ],
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