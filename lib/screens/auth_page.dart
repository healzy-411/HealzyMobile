import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/auth_service.dart';
import 'email_verify_page.dart';
import 'forgot_password_page.dart';
import 'pharmacist_register_page.dart';
import 'pharmacy_panel_home_page.dart';
import 'home_care_provider_panel_home_page.dart';
import 'home_care_provider_register_page.dart';
import '../services/token_store.dart';
import 'dart:ui';
import '../theme/app_colors.dart';

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
  late final TabController _tabController;
  bool loading = false;
  bool _rememberMe = false;

  // ScrollController'lar — Scrollbar için ayrı controller lazım
  final _loginScrollController = ScrollController();
  final _registerScrollController = ScrollController();

  // Controllers
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
    _loginScrollController.dispose();
    _registerScrollController.dispose();
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
    if (!RegExp(r'^0\d{10}$').hasMatch(digits)) return "0 ile başlayan 11 haneli numara girin";
    return null;
  }

  // --- AUTH LOGIC ---
  Future<void> _handleAuth({required bool isLogin}) async {
    setState(() => _error = null);
    final formOk = isLogin ? _loginFormKey.currentState!.validate() : _regFormKey.currentState!.validate();
    if (!formOk) return;
    setState(() => loading = true);

    try {
      if (isLogin) {
        try {
          final result = await widget.authService.login(email: _loginEmail.text.trim(), password: _loginPassword.text, rememberMe: _rememberMe);
          final token = (result["accessToken"] ?? result["token"])?.toString();
          if (token == null || token.isEmpty) throw Exception("Giriş yapılamadı. Lütfen tekrar deneyin.");
          await TokenStore.set(token);
          final refreshToken = result["refreshToken"]?.toString();
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await TokenStore.setRefreshToken(refreshToken);
          }
          final decoded = JwtDecoder.decode(token);
          final role = (decoded["role"] ?? decoded["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])?.toString();
          if (!mounted) return;
          if (role == "Customer") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.customerHome));
          else if (role == "Pharmacist") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PharmacyPanelHomePage()));
          else if (role == "HomeCareProvider") Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeCareProviderPanelHomePage()));
        } on EmailNotVerifiedException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.orange.shade700));
          final verifyResult = await Navigator.push(context, MaterialPageRoute(builder: (_) => EmailVerifyPage(authService: widget.authService, email: e.email, password: _loginPassword.text)));
          if (!mounted) return;
          if (verifyResult is Map) {
            _loginEmail.text = verifyResult["email"] ?? e.email;
            _loginPassword.text = verifyResult["password"] ?? _loginPassword.text;
          }
        }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerColor = isDark ? AppColors.darkBg : AppColors.midnight;

    final bodyGradient = isDark
        ? const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppColors.darkSurface, AppColors.darkBg])
        : const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppColors.pearl, AppColors.lightBlueSoft, Color(0xFFB8D8EB)]);

    final joinColor = isDark ? AppColors.darkBg : AppColors.midnight;

    final tabLabelColor = isDark ? AppColors.darkTextPrimary : AppColors.pearl;
    final tabUnselected = isDark ? AppColors.darkTextTertiary : AppColors.pearl.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.pearl,
      body: Column(
        children: [
          // Üst Header
          Container(
            height: MediaQuery.of(context).size.height * 0.28,
            width: double.infinity,
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(60)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("HEALZY", style: TextStyle(color: tabLabelColor, fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: tabLabelColor,
                    indicatorWeight: 3,
                    labelColor: tabLabelColor,
                    unselectedLabelColor: tabUnselected,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    tabs: const [Tab(text: "Giriş Yap"), Tab(text: "Kayıt Ol")],
                  ),
                ],
              ),
            ),
          ),
          // Alt Form Alanı
          Expanded(
            child: Container(
              color: joinColor,
              child: Container(
                decoration: BoxDecoration(
                  gradient: bodyGradient,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(60)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(isDark), _buildRegisterForm(isDark)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Form(
      key: _loginFormKey,
      child: ListView(
        controller: _loginScrollController,
        padding: const EdgeInsets.only(top: 40),
        children: [
          _buildInput(_loginEmail, "Email", Icons.email, isDark: isDark, validator: _emailValidate),
          const SizedBox(height: 15),
          _buildInput(_loginPassword, "Şifre", Icons.lock, isDark: isDark, obscure: true, validator: _req),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: isDark ? AppColors.pearl : AppColors.midnight,
                  checkColor: isDark ? AppColors.midnight : AppColors.pearl,
                  side: BorderSide(color: isDark ? AppColors.pearl.withValues(alpha: 0.5) : AppColors.midnight.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: 8),
              Text("Beni Hatırla", style: TextStyle(color: isDark ? AppColors.pearl : AppColors.midnight, fontSize: 14)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordPage(
                        authService: widget.authService,
                      ),
                    ),
                  );
                },
                child: Text(
                  "Şifremi Unuttum",
                  style: TextStyle(
                    color: isDark ? AppColors.pearl : AppColors.midnight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMainButton("Giriş Yap", () => _handleAuth(isLogin: true), isDark: isDark),
          if (_error != null) _debugArea(isDark),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Form(
      key: _regFormKey,
      child: Scrollbar(
        controller: _registerScrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(10),
        child: ListView(
          controller: _registerScrollController,
          padding: const EdgeInsets.only(top: 25, bottom: 50),
          children: [
          _buildInput(_regFirstName, "Ad", Icons.person, isDark: isDark, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regLastName, "Soyad", Icons.person_outline, isDark: isDark, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regEmail, "Email", Icons.email_outlined, isDark: isDark, validator: _emailValidate),
          const SizedBox(height: 12),
          _buildInput(_regNationalId, "TC Kimlik No", Icons.badge, isDark: isDark, isNum: true, maxLength: 11, validator: (v) {
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
          _buildInput(_regPhoneNumber, "Telefon (0xxx xxx xx xx)", Icons.phone, isDark: isDark, isNum: true, maxLength: 11, validator: _phoneValidate),
          const SizedBox(height: 12),
          _buildInput(_regPassword, "Şifre", Icons.vpn_key, isDark: isDark, obscure: true, validator: _req),
          const SizedBox(height: 12),
          _buildInput(_regPasswordConfirm, "Şifre (Tekrar)", Icons.vpn_key_outlined, isDark: isDark, obscure: true, validator: (v) {
            if (v == null || v.isEmpty) return "Zorunlu alan";
            if (v != _regPassword.text) return "Şifreler eşleşmiyor";
            return null;
          }),
          const SizedBox(height: 30),
          _buildMainButton("Kayıt Ol", () => _handleAuth(isLogin: false), isDark: isDark),
          const SizedBox(height: 20),
          _buildSmallButton("Eczacı Olarak Kaydol", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacistRegisterPage(authService: widget.authService)));
          }, isDark: isDark),
          _buildSmallButton("Serum Sağlayıcı Olarak Kaydol", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => HomeCareProviderRegisterPage(authService: widget.authService)));
          }, isDark: isDark),
          if (_error != null) _debugArea(isDark),
        ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {required bool isDark, bool obscure = false, bool isNum = false, int? maxLength, String? Function(String?)? validator}) {
    final fieldBg = isDark ? AppColors.darkSurface.withValues(alpha: 0.8) : Colors.white;
    final fieldBorder = isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final hintColor = isDark ? AppColors.darkTextTertiary : AppColors.midnight.withValues(alpha: 0.4);
    final iconColor = isDark ? AppColors.darkTextSecondary : AppColors.midnight.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: (isDark ? Colors.black : AppColors.midnight).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: fieldBg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: fieldBorder, width: 1.5),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              style: TextStyle(fontSize: 15, color: textColor),
              keyboardType: isNum ? TextInputType.number : TextInputType.emailAddress,
              maxLength: maxLength,
              inputFormatters: [
                if (isNum) FilteringTextInputFormatter.digitsOnly,
                if (isNum) FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
              ],
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: hintColor, fontSize: 16),
                prefixIcon: Icon(icon, color: iconColor, size: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                border: InputBorder.none,
                counterText: '',
              ),
              validator: validator,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(String text, VoidCallback onPressed, {required bool isDark}) {
    final btnGradient = isDark
        ? const LinearGradient(colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface])
        : const LinearGradient(colors: [AppColors.midnight, AppColors.midnightSoft]);
    final btnTextColor = isDark ? AppColors.darkTextPrimary : AppColors.pearl;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.midnight.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: btnGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: loading ? null : onPressed,
        child: Text(loading ? "Lütfen Bekleyin..." : text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: btnTextColor)),
      ),
    );
  }

  Widget _buildSmallButton(String text, VoidCallback onPressed, {required bool isDark}) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.midnight;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _debugArea(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(_error ?? "", style: const TextStyle(color: AppColors.error, fontSize: 14)),
    );
  }
}
