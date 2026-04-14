import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/auth_service.dart';
import 'email_verify_page.dart';
import 'pharmacist_register_page.dart';
import 'pharmacy_panel_home_page.dart';
import 'home_care_provider_panel_home_page.dart';
import 'home_care_provider_register_page.dart';
import '../services/token_store.dart';
import 'dart:ui'; // Cam efekti için gerekli

class AuthPage extends StatefulWidget {
  final AuthService authService;
  final Widget customerHome;

  const AuthPage({
    super.key,
    required this.authService,
    required this.customerHome,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  // --- SENİN TEMA RENKLERİN ---
  static const Color pearl = Color.fromARGB(255, 255, 255, 255);
  static const Color midnight = Color(0xFF102E4A);

  late final TabController _tabController;
  bool loading = false;

  // Controllers (Arkadaşının eklediği _regPhoneNumber dahil)
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regFirstName = TextEditingController();
  final _regLastName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regNationalId = TextEditingController();
  final _regPhoneNumber = TextEditingController(); 
  final _regPassword = TextEditingController();
  final _regPasswordConfirm = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _regFormKey = GlobalKey<FormState>();

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regFirstName.dispose();
    _regLastName.dispose();
    _regEmail.dispose();
    _regNationalId.dispose();
    _regPhoneNumber.dispose();
    _regPassword.dispose();
    _regPasswordConfirm.dispose();
    super.dispose();
  }

  // --- VALIDATORS ---
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Zorunlu alan" : null;
  String? _emailValidate(String? v) {
    if (v == null || v.trim().isEmpty) return "Zorunlu alan";
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return "Geçersiz email formatı";
    return null;
  }
  String? _phoneValidate(String? v) {
    if (v == null || v.trim().isEmpty) return "Zorunlu alan";
    final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return "5 ile başlayan 10 haneli numara girin";
    return null;
  }

  // --- AUTH LOGIC (Arkadaşının güncel mantığı) ---
  Future<void> _handleAuth({required bool isLogin}) async {
    setState(() => _error = null);
    final formOk = isLogin ? _loginFormKey.currentState!.validate() : _regFormKey.currentState!.validate();
    if (!formOk) return;
    setState(() => loading = true);

    try {
      if (isLogin) {
        final result = await widget.authService.login(email: _loginEmail.text.trim(), password: _loginPassword.text);
        final token = (result["accessToken"] ?? result["token"])?.toString();
        if (token == null || token.isEmpty) throw Exception("Giriş yapılamadı. Lütfen tekrar deneyin.");
        await TokenStore.set(token);
        final decoded = JwtDecoder.decode(token);
        final role = (decoded["role"] ?? decoded["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])?.toString();
        if (!mounted) return;
        if (role == "Customer") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.customerHome));
        else if (role == "Pharmacist") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacyPanelHomePage()));
        else if (role == "HomeCareProvider") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeCareProviderPanelHomePage()));
      } else {
        await widget.authService.registerCustomer(
          firstName: _regFirstName.text.trim(),
          lastName: _regLastName.text.trim(),
          email: _regEmail.text.trim(),
          nationalId: _regNationalId.text.trim(),
          phoneNumber: _regPhoneNumber.text.trim(),
          password: _regPassword.text,
        );
        if (!mounted) return;
        final verifyResult = await Navigator.push(context, MaterialPageRoute(builder: (_) => EmailVerifyPage(authService: widget.authService, email: _regEmail.text.trim(), password: _regPassword.text)));
        if (verifyResult is Map) {
          _loginEmail.text = verifyResult["email"] ?? "";
          _loginPassword.text = verifyResult["password"] ?? "";
          _tabController.animateTo(0);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pearl,
      body: Column(
        children: [
          // Üst Midnight Alanı (Tasarımını Geri Getirdik)
          Container(
            height: MediaQuery.of(context).size.height * 0.28,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("HEALZY", style: TextStyle(color: pearl, fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: pearl,
                    indicatorWeight: 3,
                    labelColor: pearl,
                    unselectedLabelColor: pearl.withOpacity(0.5),
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    tabs: const [Tab(text: "Giriş Yap"), Tab(text: "Kayıt Ol")],
                  ),
                ],
              ),
            ),
          ),
          // Alt Pearl Alanı (Kavisli Beyaz Panel)
          Expanded(
            child: Container(
              color: const Color(0xFF1B4965),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [pearl, Color.fromARGB(255, 255, 248, 232)],
                  ),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(), _buildRegisterForm()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          _buildInput(_loginEmail, "Email", Icons.email, validator: _emailValidate),
          const SizedBox(height: 15),
          _buildInput(_loginPassword, "Şifre", Icons.lock, obscure: true, validator: _req),
          const SizedBox(height: 30),
          _buildMainButton("Giriş Yap", () => _handleAuth(isLogin: true)),
          if (_error != null) _debugArea(),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Scrollbar(
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(10),
      child: ListView(
        padding: const EdgeInsets.only(top: 25, bottom: 50),
        children: [
          _buildInput(_regFirstName, "Ad", Icons.person, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regLastName, "Soyad", Icons.person_outline, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regEmail, "Email", Icons.email_outlined, validator: _emailValidate),
          const SizedBox(height: 12),
          _buildInput(_regNationalId, "TC Kimlik No", Icons.badge, isNum: true, validator: (v) => (v?.length != 11) ? "11 haneli olmalı" : null),
          const SizedBox(height: 12),
          _buildInput(_regPhoneNumber, "Telefon (5xx...)", Icons.phone, isNum: true, validator: _phoneValidate),
          const SizedBox(height: 12),
          _buildInput(_regPassword, "Şifre", Icons.vpn_key, obscure: true, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regPasswordConfirm, "Şifre (Tekrar)", Icons.vpn_key_outlined, obscure: true, validator: (v) {
            if (v == null || v.isEmpty) return "Zorunlu alan";
            if (v != _regPassword.text) return "Şifreler eşleşmiyor";
            return null;
          }),
          const SizedBox(height: 30),
          _buildMainButton("Kayıt Ol", () => _handleAuth(isLogin: false)),
          const SizedBox(height: 20),
          _buildSmallButton("Eczacı Olarak Kaydol", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacistRegisterPage(authService: widget.authService)));
          }),
          _buildSmallButton("Serum Sağlayıcı Olarak Kaydol", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => HomeCareProviderRegisterPage(authService: widget.authService)));
          }),
          if (_error != null) _debugArea(),
        ],
      ),
    );
  }

  // --- TASARIMIN KALBİ: CUSTOM INPUT ---
  Widget _buildInput(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool isNum = false, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: midnight.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(fontSize: 15, color: midnight),
              keyboardType: isNum ? TextInputType.number : TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: midnight.withOpacity(0.4), fontSize: 16),
                prefixIcon: Icon(icon, color: midnight.withOpacity(0.7), size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: InputBorder.none,
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
        gradient: const LinearGradient(colors: [midnight, Color(0xFF1B4965)]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: midnight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: loading ? null : onPressed,
        child: Text(loading ? "Lütfen Bekleyin..." : text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: pearl)),
      ),
    );
  }

  Widget _buildSmallButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: midnight, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(text, style: const TextStyle(color: midnight, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _debugArea() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(_error ?? "", style: const TextStyle(color: Colors.red, fontSize: 14)),
    );
  }
}