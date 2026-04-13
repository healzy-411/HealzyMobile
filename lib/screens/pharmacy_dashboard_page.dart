import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pharmacy_panel_api_service.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyDashboardPage extends StatefulWidget {
  const PharmacyDashboardPage({super.key});

  @override
  State<PharmacyDashboardPage> createState() => _PharmacyDashboardPageState();
}

class _PharmacyDashboardPageState extends State<PharmacyDashboardPage> {
  final _api = PharmacyPanelApiService(baseUrl: ApiConfig.baseUrl);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // Tarih filtresi
  String _selectedPreset = "Bu Ay";
  DateTime? _customFrom;
  DateTime? _customTo;

  final List<_DatePreset> _presets = [
    _DatePreset("Bugun", _todayRange),
    _DatePreset("Dun", _yesterdayRange),
    _DatePreset("Bu Hafta", _thisWeekRange),
    _DatePreset("Gecen Hafta", _lastWeekRange),
    _DatePreset("Bu Ay", _thisMonthRange),
    _DatePreset("Gecen Ay", _lastMonthRange),
    _DatePreset("Bu Yil", _thisYearRange),
    _DatePreset("Gecen Yil", _lastYearRange),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  (DateTime, DateTime) _getDateRange() {
    if (_customFrom != null && _customTo != null) {
      return (_customFrom!, _customTo!);
    }
    final preset = _presets.firstWhere((p) => p.label == _selectedPreset);
    return preset.range();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _getDateRange();
      final data = await _api.getDashboard(from, to);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  void _onPresetTap(String label) {
    setState(() {
      _selectedPreset = label;
      _customFrom = null;
      _customTo = null;
    });
    _loadDashboard();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end.add(const Duration(days: 1));
        _selectedPreset = "Ozel";
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: const Color(0xFF00A79D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickCustomRange,
            tooltip: "Tarih Sec",
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarih filtreleri
          _buildDatePresets(),
          // İçerik
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadDashboard,
                              child: const Text("Tekrar Dene"),
                            ),
                          ],
                        ),
                      )
                    : _buildDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresets() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          ..._presets.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                  selected: _selectedPreset == p.label,
                  selectedColor: const Color(0xFF00A79D),
                  labelStyle: TextStyle(
                    color: _selectedPreset == p.label
                        ? Colors.white
                        : Colors.black87,
                  ),
                  onSelected: (_) => _onPresetTap(p.label),
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text("Ozel", style: TextStyle(fontSize: 12)),
              selected: _selectedPreset == "Ozel",
              selectedColor: const Color(0xFF00A79D),
              labelStyle: TextStyle(
                color:
                    _selectedPreset == "Ozel" ? Colors.white : Colors.black87,
              ),
              onSelected: (_) => _pickCustomRange(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final totalRevenue = (_data?["totalRevenue"] ?? 0).toDouble();
    final totalOrders = (_data?["totalOrders"] ?? 0) as int;
    final totalItemsSold = (_data?["totalItemsSold"] ?? 0) as int;
    final cancelledOrders = (_data?["cancelledOrders"] ?? 0) as int;

    final dailySales = (_data?["dailySales"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final categorySales = (_data?["categorySales"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final topProducts = (_data?["topProducts"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final statusDist = (_data?["statusDistribution"] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Özet kartlar
          _buildSummaryCards(
              totalRevenue, totalOrders, totalItemsSold, cancelledOrders),
          const SizedBox(height: 20),

          // Günlük satış grafiği
          if (dailySales.isNotEmpty) ...[
            _sectionTitle("Gunluk Satis"),
            const SizedBox(height: 8),
            _buildDailySalesChart(dailySales),
            const SizedBox(height: 24),
          ],

          // Kategori dağılımı (pie chart)
          if (categorySales.isNotEmpty) ...[
            _sectionTitle("Kategori Bazli Satis"),
            const SizedBox(height: 8),
            _buildCategoryPieChart(categorySales),
            const SizedBox(height: 8),
            _buildCategoryLegend(categorySales),
            const SizedBox(height: 24),
          ],

          // Sipariş durumu dağılımı
          if (statusDist.isNotEmpty) ...[
            _sectionTitle("Siparis Durumlari"),
            const SizedBox(height: 8),
            _buildStatusBars(statusDist),
            const SizedBox(height: 24),
          ],

          // En çok satan ürünler
          if (topProducts.isNotEmpty) ...[
            _sectionTitle("En Cok Satan Urunler"),
            const SizedBox(height: 8),
            _buildTopProductsList(topProducts),
            const SizedBox(height: 24),
          ],

          // Boşsa
          if (dailySales.isEmpty &&
              categorySales.isEmpty &&
              topProducts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Bu tarih araliginda veri bulunamadi.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ======== ÖZET KARTLAR ========
  Widget _buildSummaryCards(
      double revenue, int orders, int items, int cancelled) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _summaryCard("Toplam Ciro", "${revenue.toStringAsFixed(2)} TL",
            Icons.attach_money, const Color(0xFF00A79D)),
        _summaryCard("Siparis Sayisi", "$orders",
            Icons.receipt_long, Colors.blue),
        _summaryCard("Satilan Urun", "$items",
            Icons.shopping_bag, Colors.purple),
        _summaryCard("Iptal Edilen", "$cancelled",
            Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ======== GÜNLÜK SATIŞ GRAFİĞİ (Bar Chart) ========
  Widget _buildDailySalesChart(List<Map<String, dynamic>> dailySales) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: dailySales
                  .map((e) => (e["revenue"] ?? 0).toDouble())
                  .fold(0.0, (a, b) => a > b ? a : b) *
              1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = dailySales[group.x.toInt()];
                final date = (item["date"] ?? "").toString();
                final shortDate = date.length >= 10 ? date.substring(5) : date;
                return BarTooltipItem(
                  "$shortDate\n${rod.toY.toStringAsFixed(0)} TL",
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text("${value.toInt()}",
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dailySales.length) {
                    return const SizedBox.shrink();
                  }
                  final date =
                      (dailySales[idx]["date"] ?? "").toString();
                  final short =
                      date.length >= 10 ? date.substring(5) : date;
                  // Çok fazla label varsa aralıklı göster
                  if (dailySales.length > 14 && idx % 3 != 0) {
                    return const SizedBox.shrink();
                  }
                  if (dailySales.length > 7 && dailySales.length <= 14 && idx % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short,
                        style: const TextStyle(
                            fontSize: 9, color: Colors.grey)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: null,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(dailySales.length, (i) {
            final revenue = (dailySales[i]["revenue"] ?? 0).toDouble();
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: revenue,
                  color: const Color(0xFF00A79D),
                  width: dailySales.length > 20 ? 6 : 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ======== KATEGORİ PIE CHART ========
  Widget _buildCategoryPieChart(List<Map<String, dynamic>> categorySales) {
    final colors = [
      const Color(0xFF00A79D),
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: List.generate(categorySales.length, (i) {
            final revenue = (categorySales[i]["revenue"] ?? 0).toDouble();
            final totalRevenue = categorySales
                .map((e) => (e["revenue"] ?? 0).toDouble())
                .fold(0.0, (a, b) => a + b);
            final pct =
                totalRevenue > 0 ? (revenue / totalRevenue * 100) : 0.0;
            return PieChartSectionData(
              color: colors[i % colors.length],
              value: revenue,
              title: "${pct.toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              radius: 50,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(List<Map<String, dynamic>> categorySales) {
    final colors = [
      const Color(0xFF00A79D),
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: List.generate(categorySales.length, (i) {
        final name = categorySales[i]["categoryName"] ?? "";
        final revenue = (categorySales[i]["revenue"] ?? 0).toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text("$name (${revenue.toStringAsFixed(0)} TL)",
                style: const TextStyle(fontSize: 12)),
          ],
        );
      }),
    );
  }

  // ======== SİPARİŞ DURUMU BARLARI ========
  Widget _buildStatusBars(List<Map<String, dynamic>> statusDist) {
    final total = statusDist
        .map((e) => (e["count"] ?? 0) as int)
        .fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: statusDist.map((s) {
          final status = s["status"] ?? "";
          final count = (s["count"] ?? 0) as int;
          final pct = total > 0 ? count / total : 0.0;
          final color = _statusColor(status);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(_statusText(status),
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      color: color,
                      minHeight: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text("$count",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ======== EN ÇOK SATAN ÜRÜNLER ========
  Widget _buildTopProductsList(List<Map<String, dynamic>> topProducts) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: List.generate(topProducts.length, (i) {
          final p = topProducts[i];
          final name = p["medicineName"] ?? "";
          final cat = p["categoryName"] ?? "";
          final qty = (p["quantity"] ?? 0) as int;
          final revenue = (p["revenue"] ?? 0).toDouble();

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.15),
              child: Text("${i + 1}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A79D))),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("$cat | $qty adet",
                style: const TextStyle(fontSize: 12)),
            trailing: Text("${revenue.toStringAsFixed(0)} TL",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A79D))),
          );
        }),
      ),
    );
  }

  // ======== HELPERS ========
  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Preparing":
        return Colors.blue;
      case "Ready":
        return Colors.green;
      case "Delivered":
        return const Color(0xFF00A79D);
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "Pending":
        return "Bekliyor";
      case "Preparing":
        return "Hazirlaniyor";
      case "Ready":
        return "Hazir";
      case "Delivered":
        return "Teslim Edildi";
      case "Cancelled":
        return "Iptal";
      default:
        return status;
    }
  }

  // ======== TARİH PRESET FONKSİYONLARI ========
  static (DateTime, DateTime) _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (start, end);
  }

  static (DateTime, DateTime) _yesterdayRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 1));
    return (start, end);
  }

  static (DateTime, DateTime) _thisWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return (start, end);
  }

  static (DateTime, DateTime) _lastWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final thisWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
    final start = thisWeekStart.subtract(const Duration(days: 7));
    return (start, thisWeekStart);
  }

  static (DateTime, DateTime) _thisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return (start, end);
  }

  static (DateTime, DateTime) _lastMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 1);
    return (start, end);
  }

  static (DateTime, DateTime) _thisYearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return (start, end);
  }

  static (DateTime, DateTime) _lastYearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year - 1, 1, 1);
    final end = DateTime(now.year, 1, 1);
    return (start, end);
  }
}

class _DatePreset {
  final String label;
  final (DateTime, DateTime) Function() range;

  _DatePreset(this.label, this.range);
}
