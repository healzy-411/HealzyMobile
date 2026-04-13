import 'package:flutter/material.dart';
import '../services/home_care_panel_api_service.dart';
import '../Models/home_care_models.dart';
import 'package:healzy_app/config/api_config.dart';

class HomeCareProviderRequestsPage extends StatefulWidget {
  const HomeCareProviderRequestsPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  Future<void> _updateStatus(int requestId, String newStatus) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Durum: ${_statusText(newStatus)}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kullaniciya iletilecek not ekleyebilirsiniz (opsiyonel):"),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: "Ornegin: Belirtilen saatte gelinecektir...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Iptal"),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Talepler"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Bekleyen"),
            Tab(text: "Onaylanan"),
            Tab(text: "Reddedilen"),
            Tab(text: "Iptal"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                  children: [
                    _buildRequestList(
                      _filterByStatus(["Pending"]),
                      emptyText: "Bekleyen talep yok",
                    ),
                    _buildRequestList(
                      _filterByStatus(["Accepted"]),
                      emptyText: "Onaylanan talep yok",
                    ),
                    _buildRequestList(
                      _filterByStatus(["Rejected"]),
                      emptyText: "Reddedilen talep yok",
                    ),
                    _buildRequestList(
                      _filterByStatus(["Cancelled"]),
                      emptyText: "Iptal edilen talep yok",
                    ),
                  ],
                ),
    );
  }

  Widget _buildRequestList(List<HomeCareProviderRequestModel> requests, {required String emptyText}) {
    if (requests.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) => _requestCard(requests[index]),
      ),
    );
  }

  Widget _requestCard(HomeCareProviderRequestModel request) {
    final statusColor = _statusColor(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ust satir: talep no + durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Talep #${request.id}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(request.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Kullanici adi
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(request.userFullName, style: const TextStyle(fontSize: 14)),
              ],
            ),

            const SizedBox(height: 4),

            // Tarih ve saat
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "${request.serviceDateUtc.day.toString().padLeft(2, '0')}."
                  "${request.serviceDateUtc.month.toString().padLeft(2, '0')}."
                  "${request.serviceDateUtc.year}",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(request.timeSlot, style: const TextStyle(fontSize: 13)),
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
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.addressSnapshot,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.note!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade900),
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.statusNote!,
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Aksiyon butonlari (sadece Pending icin)
            if (request.status == "Pending") ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(request.id, "Accepted"),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Onayla"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
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
                ],
              ),
            ],
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
        return "Bekliyor";
      case "Accepted":
        return "Onaylandi";
      case "Rejected":
        return "Reddedildi";
      case "Cancelled":
        return "Iptal Edildi";
      default:
        return status;
    }
  }
}
