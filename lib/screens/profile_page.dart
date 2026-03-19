import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../models/me_model.dart';
import 'orders_history_page.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  final String baseUrl;
  const ProfilePage({super.key, required this.baseUrl});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final AuthService _api;
  bool _loading = true;
  String? _error;
  MeDto? _me;

  @override
  void initState() {
    super.initState();
    _api = AuthService(baseUrl: widget.baseUrl);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await _api.me();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text("Tekrar Dene")),
                        ],
                      ),
                    ),
                  )
                : (me == null)
                    ? const Center(child: Text("Kullanıcı bilgisi yok."))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person, size: 34, color: Colors.deepPurple),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    me.fullName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          _infoRow(
                            icon: Icons.email_outlined,
                            text: me.email,
                            trailing: const Icon(Icons.check_circle, color: Colors.green),
                          ),
                          const SizedBox(height: 10),

                          _infoRow(
                            icon: Icons.phone_android_outlined,
                            text: me.phoneNumber,
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.history, color: Colors.white),
                              label: const Text(
                                "Geçmiş Siparişlerim",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrdersHistoryPage(
                                      baseUrl: widget.baseUrl,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.logout, color: Colors.white),
                              label: const Text(
                                "Çıkış Yap",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                TokenStore.clear();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AuthPage(
                                      authService: AuthService(baseUrl: widget.baseUrl),
                                      customerHome: const SizedBox(),
                                    ),
                                  ),
                                  (route) => false,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}