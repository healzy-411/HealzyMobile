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
import 'my_addresses_page.dart';
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
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(gradient: bgGradient),
          ),
        ),
        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          bottomNavigationBar:
              const HealzyBottomNav(current: HealzyNavTab.profile),
          body: SafeArea(
            bottom: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? _buildErrorWidget()
                    : _buildProfileContent(),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 200),
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
          _glassInfoTile(
            Icons.alternate_email_rounded,
            "E-posta",
            me.email,
            isVerified: true,
            onEdit: _handleChangeEmail,
          ),
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
          _glassMenuButton(
            icon: Icons.location_on_outlined,
            title: "Kayıtlı Adreslerim",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyAddressesPage(baseUrl: widget.baseUrl),
              ),
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

  Widget _glassInfoTile(
    IconData icon,
    String label,
    String value, {
    bool isVerified = false,
    VoidCallback? onEdit,
  }) {
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
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 16, color: _fg),
                label: Text(
                  "Değiştir",
                  style: TextStyle(color: _fg, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
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

  Future<void> _handleChangeEmail() async {
    final me = _me;
    if (me == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF132B44) : Colors.white;
    final borderC =
        isDark ? Colors.white.withValues(alpha: 0.18) : Colors.grey.shade400;
    final fieldFill =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50;

    // --- Adım 1: mevcut e-postaya kod gönder onayı
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("E-posta Değiştir", style: TextStyle(color: _fg)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mevcut e-posta adresinize 6 haneli bir doğrulama kodu göndereceğiz.",
                  style: TextStyle(color: _sub, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fieldFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderC),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alternate_email_rounded, size: 16, color: _sub),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          me.email,
                          style: TextStyle(
                              color: _fg, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx, false),
                child: Text("İptal", style: TextStyle(color: _sub)),
              ),
              ElevatedButton.icon(
                onPressed: sending
                    ? null
                    : () async {
                        setDialog(() => sending = true);
                        try {
                          await _api.requestEmailChange();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                        } catch (e) {
                          setDialog(() => sending = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  e.toString().replaceFirst("Exception: ", "")),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined, size: 16),
                label: Text(sending ? "Gönderiliyor..." : "Kodu Gönder"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        });
      },
    );

    if (confirmed != true || !mounted) return;

    // --- Adım 2: kod + yeni e-posta
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? err;
        bool saving = false;
        bool resending = false;
        return StatefulBuilder(builder: (ctx, setDialog) {
          InputDecoration dec(String label, String hint) => InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: _sub),
                hintStyle: TextStyle(color: _sub.withValues(alpha: 0.7)),
                filled: true,
                fillColor: fieldFill,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderC),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderC),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("E-posta Değiştir", style: TextStyle(color: _fg)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${me.email} adresine gönderilen 6 haneli kodu girin ve yeni e-posta adresinizi yazın.",
                    style: TextStyle(color: _sub, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(color: _fg, letterSpacing: 4),
                    decoration: dec("Doğrulama Kodu", "123456"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: _fg),
                    decoration: dec("Yeni E-posta", "yeni@ornek.com"),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(err!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: (saving || resending)
                          ? null
                          : () async {
                              setDialog(() {
                                resending = true;
                                err = null;
                              });
                              try {
                                await _api.requestEmailChange();
                                if (!ctx.mounted) return;
                                setDialog(() => resending = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text("Yeni kod gönderildi.")),
                                );
                              } catch (e) {
                                setDialog(() {
                                  resending = false;
                                  err = e
                                      .toString()
                                      .replaceFirst("Exception: ", "");
                                });
                              }
                            },
                      child: Text(
                        resending ? "Gönderiliyor..." : "Kodu tekrar gönder",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: Text("İptal", style: TextStyle(color: _sub)),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        final newEmail = emailCtrl.text.trim();
                        if (code.length != 6) {
                          setDialog(() => err = "Kod 6 haneli olmalı.");
                          return;
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(newEmail)) {
                          setDialog(() => err = "Geçerli bir e-posta girin.");
                          return;
                        }
                        setDialog(() {
                          saving = true;
                          err = null;
                        });
                        try {
                          await _api.confirmEmailChange(
                              code: code, newEmail: newEmail);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                        } catch (e) {
                          setDialog(() {
                            saving = false;
                            err =
                                e.toString().replaceFirst("Exception: ", "");
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(saving ? "Güncelleniyor..." : "Onayla"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        });
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-posta adresiniz güncellendi.")),
      );
      _load();
    }
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
    await _api.logout();
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