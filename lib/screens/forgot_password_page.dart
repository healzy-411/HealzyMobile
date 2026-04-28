import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/error_messages.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final AuthService authService;

  const ForgotPasswordPage({super.key, required this.authService});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim().toLowerCase();

    try {
      await widget.authService.forgotPassword(email: email);
      if (!mounted) return;
      // Kod yollandı (veya email yok — backend aynı cevabı dönüyor). User'ı reset sayfasına yönlendir.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kod gönderildi. Mail kutunu kontrol et.'),
          backgroundColor: Color(0xFF102E4A),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            authService: widget.authService,
            email: email,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.midnight;
    final sub = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2B), Color(0xFF132B44), Color(0xFF1B3A5C)],
          )
        : AppColors.lightPageGradient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Şifremi Unuttum'),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Icon(
                  Icons.lock_reset_rounded,
                  size: 72,
                  color: fg.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 20),
                Text(
                  'Şifreni mi unuttun?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email adresini gir, sana 6 haneli sıfırlama kodu gönderelim.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 28),
                _buildInput(
                  _email,
                  'Email',
                  Icons.email_outlined,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null ||
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                      return 'Geçerli bir email gir';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midnight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Kod Gönder',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          // Email alani bos gecilirse ResetPassword backend'e bos email
                          // gidiyor ve "kod gecersiz" donuyor — once dogrula.
                          if (!_formKey.currentState!.validate()) {
                            setState(() => _error = 'Devam etmek için önce mail adresini gir.');
                            return;
                          }
                          setState(() => _error = null);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResetPasswordPage(
                                authService: widget.authService,
                                email: _email.text.trim().toLowerCase(),
                              ),
                            ),
                          );
                        },
                  child: Text(
                    'Kodum var, devam et',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    final fieldBg = isDark
        ? const Color(0xFF132B44).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.6);
    final fieldBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.5);
    final textColor = isDark ? Colors.white : AppColors.midnight;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.midnight.withValues(alpha: 0.4);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.midnight.withValues(alpha: 0.7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fieldBorder, width: 1),
          ),
          child: TextFormField(
            controller: controller,
            style: TextStyle(fontSize: 15, color: textColor),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: hintColor, fontSize: 14),
              prefixIcon: Icon(icon, color: iconColor, size: 22),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }
}
