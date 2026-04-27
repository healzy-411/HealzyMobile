import 'package:flutter/material.dart';
import '../services/home_care_panel_api_service.dart';
import '../Models/home_care_models.dart';
import '../theme/app_colors.dart';
import '../widgets/accept_with_employee_dialog.dart';
import 'package:healzy_app/config/api_config.dart';

class HomeCareProviderRequestsPage extends StatefulWidget {
  final int initialTabIndex;
  const HomeCareProviderRequestsPage({super.key, this.initialTabIndex = 0});

  @override
  State<HomeCareProviderRequestsPage> createState() => _HomeCareProviderRequestsPageState();
}

class _HomeCareProviderRequestsPageState extends State<HomeCareProviderRequestsPage>
    with SingleTickerProviderStateMixin {
  final _api = HomeCarePanelApiService(baseUrl: ApiConfig.baseUrl);

  late TabController _tabController;
  List<HomeCareProviderRequestModel> _requests = [];
  bool _loading = true;
  String? _error;

  static const List<String> _tabStatuses = [
    'Pending',
    'Accepted',
    'Completed',
    'Rejected',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabStatuses.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabStatuses.length - 1),
    );
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getRequests();
      setState(() {
        _requests = list.map((e) => HomeCareProviderRequestModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  List<HomeCareProviderRequestModel> _filterByStatus(List<String> statuses) {
    return _requests.where((r) => statuses.contains(r.status)).toList();
  }

  Future<void> _acceptWithEmployee(int requestId) async {
    final ok = await showAcceptWithEmployeeDialog(
      context: context,
      api: _api,
      requestId: requestId,
    );
    if (!mounted) return;
    if (ok) {
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Talep onaylandi ve calisan atandi")),
      );
    }
  }

  Future<void> _updateStatus(int requestId, String newStatus) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade700;
    final dialogBg = isDark ? const Color(0xFF132B44) : null;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade50;
    final borderC = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.grey.shade400;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          "Durum: ${_statusText(newStatus)}",
          style: TextStyle(color: titleC),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kullaniciya iletilecek not ekleyebilirsiniz (opsiyonel):",
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(color: titleC),
              decoration: InputDecoration(
                hintText: "Ornegin: Belirtilen saatte gelinecektir...",
                hintStyle: TextStyle(color: muted),
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
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Iptal", style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _statusColor(newStatus),
              foregroundColor: Colors.white,
            ),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
      await _api.updateRequestStatus(requestId, newStatus, note: note);
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Talep durumu guncellendi: ${_statusText(newStatus)}")),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final appBarBg = isDark ? AppColors.darkBg : Colors.white;
    final appBarFg = isDark ? Colors.white : AppColors.midnight;
    final tabSelected = isDark ? Colors.white : AppColors.midnight;
    final tabUnselected = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.midnight.withValues(alpha: 0.55);
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : null,
      appBar: AppBar(
        title: const Text("Talepler"),
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarFg),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: tabSelected,
          unselectedLabelColor: tabUnselected,
          indicatorColor: tabSelected,
          tabs: _tabStatuses
              .map((s) => Tab(text: _statusText(s)))
              .toList(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: titleC))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadRequests,
                          child: const Text("Tekrar Dene"),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: _tabStatuses
                        .map((s) => _buildRequestList(
                              _filterByStatus([s]),
                              emptyText: _emptyTextFor(s),
                              isDark: isDark,
                            ))
                        .toList(),
                  ),
      ),
    );
  }

  Widget _buildRequestList(List<HomeCareProviderRequestModel> requests,
      {required String emptyText, required bool isDark}) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) => _requestCard(requests[index], isDark),
      ),
    );
  }

  Widget _requestCard(HomeCareProviderRequestModel request, bool isDark) {
    final statusColor = _statusColor(request.status);
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.grey.shade700;
    final iconMuted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.grey;
    final noteBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7);
    final noteFg = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.midnight.withValues(alpha: 0.85);
    final statusNoteBg = isDark
        ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
        : Colors.blue.shade50;
    final statusNoteFg = isDark
        ? const Color(0xFF93C5FD)
        : Colors.blue.shade900;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ust satir: talep no + durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Talep #${request.id}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleC,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(request.status),
                    style: TextStyle(
                      color: isDark ? Colors.white : statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Kullanici adi
            Row(
              children: [
                Icon(Icons.person, size: 16, color: iconMuted),
                const SizedBox(width: 4),
                Text(
                  request.userFullName,
                  style: TextStyle(fontSize: 14, color: titleC),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Tarih ve saat
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: iconMuted),
                const SizedBox(width: 4),
                Text(
                  "${request.serviceDateUtc.day.toString().padLeft(2, '0')}."
                  "${request.serviceDateUtc.month.toString().padLeft(2, '0')}."
                  "${request.serviceDateUtc.year}",
                  style: TextStyle(fontSize: 14, color: titleC),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 16, color: iconMuted),
                const SizedBox(width: 4),
                Text(
                  request.timeSlot,
                  style: TextStyle(fontSize: 14, color: titleC),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Adres
            if (request.addressSnapshot.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: iconMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.addressSnapshot,
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ),
                  ],
                ),
              ),

            // Kullanici notu
            if (request.note != null && request.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: noteBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.note!,
                          style: TextStyle(fontSize: 14, color: noteFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Status notu
            if (request.statusNote != null && request.statusNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusNoteBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment, size: 14, color: statusNoteFg),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.statusNote!,
                          style: TextStyle(fontSize: 14, color: statusNoteFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Tamamlanan talep icin kazanc rozeti
            if (request.status == "Completed" && request.earningAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet,
                          size: 13,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${request.earningAmount!.toStringAsFixed(0)} TL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Aksiyon butonlari
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetail(request),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text("Detay"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: titleC,
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.midnight.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                if (request.status == "Pending") ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(request.id, "Rejected"),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reddet"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _acceptWithEmployee(request.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Onayla"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                if (request.status == "Accepted") ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _completeRequest(request.id),
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text("Tamamla"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Accepted":
        return Colors.green;
      case "Completed":
        return const Color(0xFF6366F1);
      case "Rejected":
        return Colors.red;
      case "Cancelled":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "Pending":
        return "Bekleyen";
      case "Accepted":
        return "Kabul Edildi";
      case "Completed":
        return "Tamamlandı";
      case "Rejected":
        return "Reddedildi";
      case "Cancelled":
        return "İptal";
      default:
        return status;
    }
  }

  String _emptyTextFor(String status) {
    switch (status) {
      case "Pending":
        return "Bekleyen talep yok";
      case "Accepted":
        return "Kabul edilen talep yok";
      case "Completed":
        return "Tamamlanan talep yok";
      case "Rejected":
        return "Reddedilen talep yok";
      case "Cancelled":
        return "İptal edilen talep yok";
      default:
        return "Talep yok";
    }
  }

  Future<void> _completeRequest(int requestId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade700;
    final dialogBg = isDark ? const Color(0xFF132B44) : null;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade50;
    final borderC = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.grey.shade400;
    final accent = const Color(0xFF6366F1);

    final amountController = TextEditingController();
    bool saving = false;
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Row(
                children: [
                  Icon(Icons.flag, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text("Hizmeti Tamamla", style: TextStyle(color: titleC)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kazanc Tutari (TL) *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: titleC),
                      decoration: InputDecoration(
                        hintText: "0.00",
                        hintStyle: TextStyle(color: muted),
                        suffixText: "TL",
                        suffixStyle: TextStyle(color: muted),
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
                          borderSide: BorderSide(color: accent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
                        child: Text(
                          err!,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, false),
                  child: Text("Iptal", style: TextStyle(color: muted)),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final raw = amountController.text.trim().replaceAll(',', '.');
                          final val = double.tryParse(raw);
                          if (val == null || val <= 0) {
                            setDialogState(() {
                              err = "Kazanc tutari zorunludur ve 0'dan buyuk olmalı.";
                            });
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            err = null;
                          });
                          try {
                            await _api.updateRequestStatus(
                              requestId,
                              'Completed',
                              earningAmount: val,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              err = e.toString().replaceFirst('Exception: ', '');
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
                      : const Icon(Icons.flag, size: 16),
                  label: Text(saving ? "Kaydediliyor..." : "Tamamla"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;
    await _loadRequests();
    if (!mounted) return;
    // Tamamlandı sekmesine geç
    final completedIndex = _tabStatuses.indexOf('Completed');
    if (completedIndex >= 0) _tabController.animateTo(completedIndex);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Talep tamamlandi')),
    );
  }

  Future<void> _showDetail(HomeCareProviderRequestModel r) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : AppColors.midnight;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade700;
    final dividerC = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade200;
    final dialogBg = isDark ? const Color(0xFF132B44) : Colors.white;
    final statusColor = _statusColor(r.status);

    String fmtDateTime(DateTime dt) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    }

    String fmtDate(DateTime dt) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
    }

    Widget row(String label, String? value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                (value == null || value.isEmpty) ? '—' : value,
                style: TextStyle(
                  fontSize: 13,
                  color: (value == null || value.isEmpty)
                      ? (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.grey.shade400)
                      : titleC,
                ),
              ),
            ),
          ],
        ),
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                child: Row(
                  children: [
                    Text(
                      "Talep #${r.id}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleC,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusText(r.status),
                        style: TextStyle(
                          color: isDark ? Colors.white : statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dividerC),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      row("Müşteri", r.userFullName),
                      row(
                        "Hizmet Tarihi",
                        '${fmtDate(r.serviceDateUtc)} • ${r.timeSlot.isEmpty ? '-' : r.timeSlot}',
                      ),
                      row("Adres", r.addressSnapshot),
                      row("Müşteri Notu", r.note),
                      row("Oluşturulma Tarihi", fmtDateTime(r.createdAtUtc)),
                      row("Atanan Çalışan", r.assignedEmployeeName),
                      if (r.status == 'Completed') ...[
                        row(
                          "Kazanç",
                          r.earningAmount != null
                              ? '${r.earningAmount!.toStringAsFixed(2)} TL'
                              : null,
                        ),
                        row(
                          "Tamamlanma",
                          r.completedAtUtc != null
                              ? fmtDateTime(r.completedAtUtc!)
                              : null,
                        ),
                        row("İşlem Açıklaması", r.completionNote),
                      ],
                      if (r.status == 'Cancelled' || r.status == 'Rejected')
                        row("İptal / Red Nedeni", r.statusNote),
                      if (r.status == 'Accepted' &&
                          r.statusNote != null &&
                          r.statusNote!.isNotEmpty)
                        row("Not", r.statusNote),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
