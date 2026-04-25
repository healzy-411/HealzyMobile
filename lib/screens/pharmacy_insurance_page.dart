import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pharmacy_panel_api_service.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyInsurancePage extends StatefulWidget {
  const PharmacyInsurancePage({super.key});

  @override
  State<PharmacyInsurancePage> createState() => _PharmacyInsurancePageState();
}

class _PharmacyInsurancePageState extends State<PharmacyInsurancePage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);

  List<Map<String, dynamic>> _myInsurances = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getInsurances();
      setState(() {
        _myInsurances = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    List<Map<String, dynamic>>? allCompanies;
    try {
      allCompanies = await _api.getAllInsuranceCompanies();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sigorta sirketleri yuklenemedi: $e")),
      );
      return;
    }

    // Zaten eklenmis olanlari cikar
    final myIds = _myInsurances.map((i) => i["insuranceCompanyId"]).toSet();
    final available = allCompanies.where((c) => !myIds.contains(c["id"])).toList();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eklenecek yeni sigorta sirketi bulunamadi.")),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sigorta Sirketi Ekle",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...available.map((company) {
                final id = company["id"] as int;
                final name = company["name"] ?? "";
                return ListTile(
                  leading: const Icon(Icons.health_and_safety, color: Colors.teal),
                  title: Text(name),
                  trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _api.addInsurance(id);
                      _load();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("$name eklendi.")),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceFirst("Exception: ", "")),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmRemove(int companyId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sigorta Kaldir"),
        content: Text("\"$name\" kaldirilacak. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Iptal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Kaldir", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.removeInsurance(companyId);
        _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name kaldirildi.")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.65) : Colors.grey[700]!;
    final fg = titleC;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: const Text("Sigorta Yönetimi"),
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.lightPageGradient,
            color: isDark ? AppColors.darkBg : null,
          ),
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Sigorta Ekle", style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text("Tekrar Dene")),
                      ],
                    ),
                  )
                : _myInsurances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.health_and_safety, size: 64, color: muted),
                            const SizedBox(height: 12),
                            Text("Henüz sigorta şirketi eklenmemiş.",
                                style: TextStyle(color: titleC, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text("Aşağıdaki butondan ekleyebilirsiniz.",
                                style: TextStyle(color: muted, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _myInsurances.length,
                          itemBuilder: (context, i) {
                            final ins = _myInsurances[i];
                            final name = ins["insuranceCompanyName"] ?? "";
                            final id = ins["insuranceCompanyId"] as int;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF132B44).withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.68),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : AppColors.midnight.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.health_and_safety,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: titleC)),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: isDark ? Colors.red.shade300 : Colors.red),
                                    onPressed: () => _confirmRemove(id, name),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
