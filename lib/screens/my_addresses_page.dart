import 'package:flutter/material.dart';
import '../utils/error_messages.dart';

import '../Models/address_model.dart';
import '../services/address_api_service.dart';
import '../theme/app_colors.dart';
import 'add_address_page.dart';
import 'edit_address_page.dart';

class MyAddressesPage extends StatefulWidget {
  final String baseUrl;
  const MyAddressesPage({super.key, required this.baseUrl});

  @override
  State<MyAddressesPage> createState() => _MyAddressesPageState();
}

class _MyAddressesPageState extends State<MyAddressesPage> {
  late final AddressApiService _api = AddressApiService(baseUrl: widget.baseUrl);

  bool _loading = true;
  String? _error;
  List<AddressDto> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AddressDto> _sorted(List<AddressDto> list) {
    final copy = [...list];
    copy.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getMyAddresses();
      if (!mounted) return;
      setState(() => _addresses = _sorted(list));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setDefault(AddressDto a) async {
    try {
      await _api.setDefault(a.id);
      if (!mounted) return;
      setState(() {
        _addresses = _sorted(_addresses
            .map((x) => x.copyWith(isDefault: x.id == a.id))
            .toList());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${a.title} varsayılan yapıldı")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _delete(AddressDto a) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF132B44) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Adresi Sil",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.midnight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "\"${a.title}\" adresi silinsin mi?",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "İptal",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.deleteAddress(a.id);
      if (!mounted) return;
      setState(() {
        _addresses = _addresses.where((x) => x.id != a.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Adres silindi")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _edit(AddressDto a) async {
    final updated = await Navigator.push<AddressDto?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAddressPage(baseUrl: widget.baseUrl, address: a),
      ),
    );
    if (updated != null) {
      await _load();
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<AddressDto?>(
      context,
      MaterialPageRoute(builder: (_) => AddAddressPage(baseUrl: widget.baseUrl)),
    );
    if (created != null) {
      await _load();
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
        title: const Text("Adreslerim"),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton(
                            onPressed: _load,
                            child: const Text("Tekrar Dene"),
                          ),
                        ),
                      ],
                    )
                  : _addresses.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              Icons.location_off_outlined,
                              size: 64,
                              color: sub,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                "Henüz kayıtlı adresiniz yok",
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                "Yeni bir adres eklemek için aşağıdaki butona basın.",
                                style: TextStyle(color: sub, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final a = _addresses[i];
                            return _addressCard(a, fg, sub, isDark);
                          },
                        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.midnight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text("Yeni Adres"),
      ),
    );
  }

  Widget _addressCard(AddressDto a, Color fg, Color sub, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: a.isDefault
              ? Colors.amber.withValues(alpha: 0.55)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.5)),
          width: a.isDefault ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title.isNotEmpty ? a.title : "Adres",
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (a.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        "Varsayılan",
                        style: TextStyle(
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a.fullLine(),
            style: TextStyle(color: sub, fontSize: 13.5, height: 1.4),
          ),
          if (a.fullName.isNotEmpty || a.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (a.fullName.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 14, color: sub),
                  const SizedBox(width: 4),
                  Text(a.fullName, style: TextStyle(color: sub, fontSize: 12.5)),
                  const SizedBox(width: 12),
                ],
                if (a.phone.isNotEmpty) ...[
                  Icon(Icons.phone_outlined, size: 14, color: sub),
                  const SizedBox(width: 4),
                  Text(a.phone, style: TextStyle(color: sub, fontSize: 12.5)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: a.isDefault ? null : () => _setDefault(a),
                icon: Icon(
                  a.isDefault ? Icons.star : Icons.star_border,
                  color: a.isDefault ? Colors.amber : fg,
                  size: 18,
                ),
                label: Text(
                  a.isDefault ? "Varsayılan" : "Varsayılan Yap",
                  style: TextStyle(
                    color: a.isDefault ? Colors.amber : fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: "Düzenle",
                onPressed: () => _edit(a),
                icon: Icon(Icons.edit_outlined, color: fg, size: 20),
              ),
              IconButton(
                tooltip: "Sil",
                onPressed: () => _delete(a),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
