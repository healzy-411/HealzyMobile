import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/error_messages.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  final AuthService authService;
  final String email;

  const ResetPasswordPage({
    super.key,
    required this.authService,
    required this.email,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.resetPassword(
        email: widget.email,
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifren güncellendi. Yeni şifreyle giriş yapabilirsin.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      // Auth ekranına dön (ForgotPasswordPage pushReplacement ile geçildi için sadece 1 pop)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await widget.authService.forgotPassword(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod tekrar gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
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
        title: const Text('Yeni Şifre'),
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
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: fg.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 16),
                Text(
                  'Email kutunu kontrol et',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adresine 6 haneli kod gönderildi. Kodu gir ve yeni şifreni belirle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                _buildInput(
                  _code,
                  '6 haneli kod',
                  Icons.pin_outlined,
                  isDark: isDark,
                  isNum: true,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.trim().length != 6) return '6 haneli kod gir';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildInput(
                  _password,
                  'Yeni şifre',
                  Icons.lock_outline,
                  isDark: isDark,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.length < 7) return 'En az 7 karakter';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'En az 1 büyük harf';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildInput(
                  _passwordConfirm,
                  'Yeni şifre (tekrar)',
                  Icons.lock_outline,
                  isDark: isDark,
                  obscure: true,
                  validator: (v) {
                    if (v != _password.text) return 'Şifreler eşleşmiyor';
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
                            'Şifreyi Sıfırla',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resending || _loading ? null : _resend,
                  child: Text(
                    _resending ? 'Gönderiliyor...' : 'Kodu tekrar gönder',
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
    bool obscure = false,
    bool isNum = false,
    int? maxLength,
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
            obscureText: obscure,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            maxLength: maxLength,
            inputFormatters: [
              if (isNum) FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ],
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
              counterText: '',
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }
}
