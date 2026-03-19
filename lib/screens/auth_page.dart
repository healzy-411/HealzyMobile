import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/auth_service.dart';
import 'email_verify_page.dart';
import 'pharmacist_register_page.dart';
import 'pharmacy_panel_home_page.dart';
import 'home_care_provider_panel_home_page.dart';
import 'home_care_provider_register_page.dart';
import '../services/token_store.dart';

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

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool loading = false;

  // Login controllers
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // Register controllers
  final _regFirstName = TextEditingController();
  final _regLastName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regNationalId = TextEditingController();
  final _regPhoneNumber = TextEditingController(); // ✅ NEW
  final _regPassword = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _regFormKey = GlobalKey<FormState>();

  String? _error;
  String? _rolePreview;
  String? _tokenPreview;

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
    _regPhoneNumber.dispose(); // ✅ NEW
    _regPassword.dispose();

    super.dispose();
  }

  Future<void> _handleAuth({required bool isLogin}) async {
    setState(() {
      _error = null;
      _rolePreview = null;
      _tokenPreview = null;
    });

    final formOk = isLogin
        ? _loginFormKey.currentState!.validate()
        : _regFormKey.currentState!.validate();

    if (!formOk) return;

    setState(() => loading = true);

    try {
      Map<String, dynamic> result;

      if (isLogin) {
        // ---------------- LOGIN ----------------
        result = await widget.authService.login(
          email: _loginEmail.text.trim(),
          password: _loginPassword.text,
        );

        final token = (result["accessToken"] ?? result["token"])?.toString();
        if (token == null || token.isEmpty) {
          throw Exception("Token gelmedi. Backend response: $result");
        }

        // ✅ TOKEN’I SAKLA
        await TokenStore.set(token);

        final decoded = JwtDecoder.decode(token);
        final role = (decoded["role"] ??
                decoded[
                    "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])
            ?.toString();

        setState(() {
          _tokenPreview = token;
          _rolePreview = role ?? "(role yok)";
        });

        // Role'e göre yönlendirme
        if (role == "Customer") {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.customerHome),
          );
          return;
        }

        if (role == "Pharmacist") {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PharmacyPanelHomePage()),
          );
          return;
        }

        if (role == "HomeCareProvider") {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeCareProviderPanelHomePage()),
          );
          return;
        }

        throw Exception(
          "Giris basarili ama role = ${role ?? 'null'}. Desteklenmiyor.",
        );
      } else {
        // ---------------- REGISTER ----------------
        result = await widget.authService.registerCustomer(
          firstName: _regFirstName.text.trim(),
          lastName: _regLastName.text.trim(),
          email: _regEmail.text.trim(),
          nationalId: _regNationalId.text.trim(),
          phoneNumber: _regPhoneNumber.text.trim(), // ✅ NEW
          password: _regPassword.text,
        );

        // Register response token dönse bile biz artık direkt verify ekranına gidiyoruz
        final token = (result["accessToken"] ?? result["token"])?.toString();
        if (token != null && token.isNotEmpty) {
          final decoded = JwtDecoder.decode(token);
          final role = (decoded["role"] ??
                  decoded[
                      "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])
              ?.toString();

          setState(() {
            _tokenPreview = token;
            _rolePreview = role ?? "(role yok)";
          });
        }

        if (!mounted) return;

        // ✅ Register sonrası verify sayfasına git
        final verifyResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerifyPage(
              authService: widget.authService,
              email: _regEmail.text.trim(),
              password: _regPassword.text,
            ),
          ),
        );

        // ✅ Verify başarılıysa login tabına dön + email/pass doldur
        if (verifyResult is Map) {
          _loginEmail.text = (verifyResult["email"] ?? "").toString();
          _loginPassword.text = (verifyResult["password"] ?? "").toString();
          _tabController.animateTo(0);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Doğrulama başarılı ✅ Şimdi giriş yap.")),
          );
        }

        return;
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null;

  String? _phoneValidate(String? v) {
    if (v == null || v.trim().isEmpty) return "Zorunlu";
    final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return "5 ile baslayan 10 haneli olmali";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Healzy Auth"),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Login"),
              Tab(text: "Register"),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ---------------- LOGIN ----------------
                  Form(
                    key: _loginFormKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _loginEmail,
                          decoration: const InputDecoration(labelText: "Email"),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Zorunlu";
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return "Gecersiz email";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _loginPassword,
                          decoration:
                              const InputDecoration(labelText: "Password"),
                          obscureText: true,
                          validator: _req,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed:
                              loading ? null : () => _handleAuth(isLogin: true),
                          child: Text(loading ? "Bekle..." : "Login"),
                        ),
                        const SizedBox(height: 16),
                        _debugArea(),
                      ],
                    ),
                  ),

                  // ---------------- REGISTER (Customer) ----------------
                  Form(
                    key: _regFormKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _regFirstName,
                          decoration:
                              const InputDecoration(labelText: "First name"),
                          maxLength: 100,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Zorunlu";
                            if (v.trim().length < 2) return "En az 2 karakter";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _regLastName,
                          decoration:
                              const InputDecoration(labelText: "Last name"),
                          maxLength: 100,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Zorunlu";
                            if (v.trim().length < 2) return "En az 2 karakter";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _regEmail,
                          decoration: const InputDecoration(labelText: "Email"),
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
                          controller: _regNationalId,
                          decoration: const InputDecoration(
                              labelText: "National ID"),
                          maxLength: 11,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Zorunlu";
                            if (!RegExp(r'^\d{11}$').hasMatch(v.trim())) return "TC Kimlik 11 haneli olmali";
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // ✅ NEW: Phone Number
                        TextFormField(
                          controller: _regPhoneNumber,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            hintText: "05xx xxx xx xx",
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 15,
                          validator: _phoneValidate,
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _regPassword,
                          decoration:
                              const InputDecoration(labelText: "Password"),
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: loading
                              ? null
                              : () => _handleAuth(isLogin: false),
                          child: Text(loading ? "Bekle..." : "Register (Customer)"),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PharmacistRegisterPage(
                                  authService: widget.authService,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_pharmacy),
                          label: const Text("Eczaci Olarak Kayit Ol"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00A79D),
                            side: const BorderSide(color: Color(0xFF00A79D)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeCareProviderRegisterPage(
                                  authService: widget.authService,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.medical_services),
                          label: const Text("Serum Saglayici Olarak Kayit Ol"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00A79D),
                            side: const BorderSide(color: Color(0xFF00A79D)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _debugArea(),
                      ],
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

  Widget _debugArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        if (_rolePreview != null) ...[
          const SizedBox(height: 8),
          Text("Decoded role: $_rolePreview"),
        ],
        if (_tokenPreview != null) ...[
          const SizedBox(height: 8),
          const Text("Token (preview):"),
          SelectableText(_tokenPreview!, maxLines: 5),
        ],
      ],
    );
  }
}