/*import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../Models/me_model.dart';
import 'orders_history_page.dart';
import 'saved_cards_page.dart';
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

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.credit_card, color: Colors.white),
                              label: const Text(
                                "Kayitli Kartlarim",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SavedCardsPage(),
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
                              onPressed: () async {
                                await TokenStore.clear();
                                if (!context.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AuthPage(
                                      authService: AuthService(baseUrl: widget.baseUrl),
                                      customerHome: const HomePage(),
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
}*/

import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../Models/me_model.dart';
import 'orders_history_page.dart';
import 'saved_cards_page.dart';
import 'auth_page.dart';
import 'home_page.dart';
import '../widgets/healzy_bottom_nav.dart';
import '../theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  final String baseUrl;
  const ProfilePage({super.key, required this.baseUrl});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- RENK PALETİ ---
  static const Color midnight = Color(0xFF1B4965);
  static const Color subTextColor = Color(0xFF5A5A5A);

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
    if (!mounted) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2B), Color(0xFF132B44), Color(0xFF1B3A5C)],
          )
        : AppColors.lightPageGradient;
    return Scaffold(
      bottomNavigationBar:
          const HealzyBottomNav(current: HealzyNavTab.profile),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? _buildErrorWidget()
                  : _buildProfileContent(),
        ),
      ),
    );
  }

  Color get _fg => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : midnight;
  Color get _sub => Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.65)
      : subTextColor;

  Widget _buildProfileContent() {
    final me = _me!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTopBar(),
          const SizedBox(height: 30),
          
          // Profil Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _fg.withOpacity(0.1), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: midnight.withOpacity(0.05),
                    child: Icon(Icons.person, size: 50, color: _fg),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  me.fullName,
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: _fg,
                    letterSpacing: -0.5
                  ),
                ),
                Text(
                  "Müşteri",
                  style: TextStyle(color: _sub, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          _buildSectionTitle("Kişisel Bilgiler"),
          _glassInfoTile(Icons.alternate_email_rounded, "E-posta", me.email, isVerified: true),
          _glassInfoTile(Icons.phone_iphone_rounded, "Telefon", me.phoneNumber),
          const SizedBox(height: 12),
          _glassMenuButton(
            icon: Icons.edit_rounded,
            title: "Profili Düzenle",
            onTap: _handleEditProfile,
          ),

          const SizedBox(height: 28),

          _buildSectionTitle("Hesap İşlemleri"),
          _glassMenuButton(
            icon: Icons.local_mall_outlined,
            title: "Geçmiş Siparişlerim",
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => OrdersHistoryPage(baseUrl: widget.baseUrl))
            ),
          ),
          _glassMenuButton(
            icon: Icons.credit_card_rounded,
            title: "Kayıtlı Kartlarım",
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const SavedCardsPage())
            ),
          ),

          const SizedBox(height: 10),

          TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: const Text(
              "Hesaptan Çıkış Yap",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 16)
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _handleDeleteAccount,
            icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700),
            label: Text(
              "Hesabımı Sil",
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context), 
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: _fg)
        ),
        Expanded(
          child: Center(
            child: Text(
              "Profilim",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _fg)
            )
          )
        ),
        const SizedBox(width: 48), // Denge için
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text(
          title, 
          style: TextStyle(
            color: _fg, 
            fontWeight: FontWeight.bold, 
            fontSize: 16, 
            letterSpacing: 1
          )
        ),
      ),
    );
  }

  Widget _glassInfoTile(IconData icon, String label, String value, {bool isVerified = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _glassDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: _fg, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, color: _sub)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _fg)),
                ],
              ),
            ),
            if (isVerified) const Icon(Icons.verified, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _glassMenuButton({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _glassDecoration(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: _fg, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _fg)
                )
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _fg),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF132B44).withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.4),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Future<void> _handleEditProfile() async {
    final me = _me!;
    final nameParts = me.fullName.split(' ');
    final firstNameCtrl = TextEditingController(text: nameParts.isNotEmpty ? nameParts.first : '');
    final lastNameCtrl = TextEditingController(text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    final phoneCtrl = TextEditingController(text: me.phoneNumber);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? formError;
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF132B44) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Profili Düzenle", style: TextStyle(color: _fg, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameCtrl,
                      decoration: InputDecoration(
                        labelText: "Ad",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameCtrl,
                      decoration: InputDecoration(
                        labelText: "Soyad",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: "Telefon",
                        hintText: "05xx xxx xx xx",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text("İptal", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final firstName = firstNameCtrl.text.trim();
                          final lastName = lastNameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();

                          if (firstName.isEmpty || lastName.isEmpty) {
                            setDialogState(() => formError = "Ad ve soyad zorunludur.");
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            formError = null;
                          });

                          try {
                            await _api.updateProfile(
                              firstName: firstName,
                              lastName: lastName,
                              phone: phone.isNotEmpty ? phone : null,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              formError = e.toString().replaceFirst("Exception: ", "");
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: midnight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(saving ? "Kaydediliyor..." : "Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF132B44) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Hesabı Kalıcı Olarak Sil",
            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hesabınızı kalıcı olarak silmek istiyorsanız aşağıdaki kutucuğa \"onaylıyorum\" yazın.",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Bu işlem geri alınamaz. Tüm verileriniz (siparişler, adresler, kartlar, hatırlatıcılar) silinecektir.",
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: "onaylıyorum",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("İptal", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Hesabımı Sil"),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final confirmation = confirmController.text.trim();
    if (confirmation != "onaylıyorum") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Onay metni hatalı. 'onaylıyorum' yazmalısınız.")),
      );
      return;
    }

    try {
      await _api.deleteAccount(confirmation);
      await TokenStore.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AuthPage(
            authService: AuthService(baseUrl: widget.baseUrl),
            customerHome: const HomePage(),
          ),
        ),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hesabınız kalıcı olarak silindi.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _handleLogout() async {
    await TokenStore.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(
        builder: (_) => AuthPage(
          authService: AuthService(baseUrl: widget.baseUrl), 
          customerHome: const HomePage()
        )
      ), 
      (route) => false
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: midnight),
            onPressed: _load, 
            child: const Text("Tekrar Dene", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}