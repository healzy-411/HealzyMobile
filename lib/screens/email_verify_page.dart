import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EmailVerifyPage extends StatefulWidget {
  final AuthService authService;
  final String email;
  final String password; // registerda girilen şifreyi login’e taşımak için

  const EmailVerifyPage({
    super.key,
    required this.authService,
    required this.email,
    required this.password,
  });

  @override
  State<EmailVerifyPage> createState() => _EmailVerifyPageState();
}

class _EmailVerifyPageState extends State<EmailVerifyPage> {
  final _code = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() { error = null; loading = true; });
    try {
      await widget.authService.verifyEmail(
        email: widget.email,
        code: _code.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email doğrulandı ✅ Şimdi giriş yapabilirsin.")),
      );

      // ✅ Login ekranına email/pass ile geri dön
      Navigator.pop(context, {
        "email": widget.email,
        "password": widget.password,
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() { error = null; loading = true; });
    try {
      await widget.authService.sendEmailCode(email: widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kod tekrar gönderildi 📩")),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Email Verification")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text("Email: ${widget.email}"),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "6 haneli kod",
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: loading ? null : _verify,
                  child: Text(loading ? "Bekle..." : "Verify"),
                ),
                TextButton(
                  onPressed: loading ? null : _resend,
                  child: const Text("Kodu tekrar gönder"),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
