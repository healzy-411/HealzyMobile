/*import 'package:flutter/material.dart';

import '../Models/medicine_reminder_model.dart';
import '../services/medicine_reminder_api_service.dart';

class AllRemindersPage extends StatefulWidget {
  final MedicineReminderApiService api;
  final Color healzyTurquoise;
  final Color healzyDarkGreen;
  final void Function(MedicineReminderDto item)? onEdit;
  final VoidCallback? onChanged;

  const AllRemindersPage({
    super.key,
    required this.api,
    required this.healzyTurquoise,
    required this.healzyDarkGreen,
    this.onEdit,
    this.onChanged,
  });

  @override
  State<AllRemindersPage> createState() => _AllRemindersPageState();
}

class _AllRemindersPageState extends State<AllRemindersPage> {
  List<MedicineReminderDto> _all = [];
  bool _loading = false;
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
      final list = await widget.api.getAllReminders();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(MedicineReminderDto item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('${item.name} hatırlatıcısı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteReminder(item.id);
      widget.onChanged?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silme başarısız: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _hardDelete(MedicineReminderDto item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kalıcı olarak silinsin mi?'),
        content: Text('${item.name} kalıcı olarak silinecek ve geri getirilemeyecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Kalıcı Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.hardDeleteReminder(item.id);
      widget.onChanged?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} kalıcı olarak silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silme başarısız: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  String _frequencyText(MedicineReminderDto item) {
    final type = item.frequencyType;
    final x = item.xValue;
    if (type == 0) return "Her gün";
    if (type == 1) return "$x günde bir";
    return "Haftada $x gün";
  }

  String _intakeText(int intakeType) => intakeType == 1 ? 'Tok' : 'Aç';

  /// Hatırlatıcının durumunu hesapla
  String _statusText(MedicineReminderDto item) {
    if (!item.isActive) return 'Silindi';
    final now = DateTime.now();
    final start = item.startDateUtc;
    final end = start.add(Duration(days: item.durationDays));
    if (now.isBefore(start)) return 'Bekliyor';
    if (now.isAfter(end)) return 'Tamamlandı';
    return 'Aktif';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif':
        return Colors.green;
      case 'Tamamlandı':
        return Colors.blueGrey;
      case 'Silindi':
        return Colors.red;
      case 'Bekliyor':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grupla: Aktif, Tamamlandı, Silindi
    final active = <MedicineReminderDto>[];
    final completed = <MedicineReminderDto>[];
    final deleted = <MedicineReminderDto>[];

    for (final r in _all) {
      final status = _statusText(r);
      if (status == 'Aktif' || status == 'Bekliyor') {
        active.add(r);
      } else if (status == 'Tamamlandı') {
        completed.add(r);
      } else {
        deleted.add(r);
      }
    }

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.reminder),
      appBar: AppBar(
        title: const Text(
          'Tüm Hatırlatıcılar',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                      ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _all.isEmpty
                  ? const Center(
                      child: Text(
                        'Henüz hatırlatıcı eklenmemiş.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          if (active.isNotEmpty) ...[
                            _sectionHeader('Aktif', Colors.green),
                            ...active.map((r) => _reminderCard(r)),
                          ],
                          if (completed.isNotEmpty) ...[
                            _sectionHeader('Tamamlanan', Colors.blueGrey),
                            ...completed.map((r) => _reminderCard(r)),
                          ],
                          if (deleted.isNotEmpty) ...[
                            _sectionHeader('Silinen', Colors.red),
                            ...deleted.map((r) => _reminderCard(r)),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : widget.healzyDarkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(MedicineReminderDto item) {
    final status = _statusText(item);
    final isEditable = item.isActive && status != 'Tamamlandı';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: widget.healzyTurquoise, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.healzyDarkGreen,
                    ),
                  ),
                ),
                // Durum badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
                    ),
                  ),
                ),
                // Aç/Tok badge
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.intakeType == 0
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _intakeText(item.intakeType),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: item.intakeType == 0 ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_frequencyText(item)} · Günde ${item.timesPerDay} kez · ${item.durationDays} gün',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            // Saatler
            Wrap(
              spacing: 6,
              children: item.timesOfDay
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.healzyTurquoise.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t.split(':').take(2).join(':'),
                          style: TextStyle(
                            color: widget.healzyDarkGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            // Yemek saatleri
            if (item.intakeType == 1 && item.mealTimes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  Icon(Icons.restaurant, size: 14, color: Colors.grey[500]),
                  ...item.mealTimes.map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.split(':').take(2).join(':'),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Tarih bilgisi
            const SizedBox(height: 6),
            Text(
              'Başlangıç: ${_formatDate(item.startDateUtc)} · Bitiş: ${_formatDate(item.startDateUtc.add(Duration(days: item.durationDays)))}',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            // Düzenle / Sil butonları
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isEditable) ...[
                  TextButton.icon(
                    onPressed: () {
                      widget.onEdit?.call(item);
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.edit, size: 18, color: widget.healzyTurquoise),
                    label: Text('Düzenle', style: TextStyle(color: widget.healzyTurquoise)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _delete(item),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => _hardDelete(item),
                    icon: const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                    label: const Text('Kalıcı Sil', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}*/

import 'package:flutter/material.dart';
import 'dart:ui'; // Cam efekti (blur) için gerekli

import '../Models/medicine_reminder_model.dart';
import '../services/medicine_reminder_api_service.dart';
import '../widgets/healzy_bottom_nav.dart';

class AllRemindersPage extends StatefulWidget {
  final MedicineReminderApiService api;
  final Color healzyTurquoise;
  final Color healzyDarkGreen;
  final void Function(MedicineReminderDto item)? onEdit;
  final VoidCallback? onChanged;

  const AllRemindersPage({
    super.key,
    required this.api,
    required this.healzyTurquoise,
    required this.healzyDarkGreen,
    this.onEdit,
    this.onChanged,
  });

  @override
  State<AllRemindersPage> createState() => _AllRemindersPageState();
}

class _AllRemindersPageState extends State<AllRemindersPage> {
  // Renk tanımlamaları
  final Color midnightBlue = const Color(0xFF1B4965);
  final Color pearlWhite = const Color(0xFFFFF8E8);

  List<MedicineReminderDto> _all = [];
  bool _loading = false;
  String? _error;

  // Scrollbar için controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getAllReminders();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // =================== YARDIMCI METOTLAR ======================
  // ============================================================

  String _frequencyText(MedicineReminderDto item) {
    final type = item.frequencyType;
    final x = item.xValue;
    if (type == 0) return "Her gün";
    if (type == 1) return "$x günde bir";
    return "Haftada $x gün";
  }

  String _intakeText(int intakeType) => intakeType == 1 ? 'Tok' : 'Aç';

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _statusText(MedicineReminderDto item) {
    if (!item.isActive) return 'Silindi';
    final now = DateTime.now();
    final start = item.startDateUtc;
    final end = start.add(Duration(days: item.durationDays));
    if (now.isBefore(start)) return 'Bekliyor';
    if (now.isAfter(end)) return 'Tamamlandı';
    return 'Aktif';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif': return Colors.green;
      case 'Tamamlandı': return Colors.blueGrey;
      case 'Silindi': return Colors.red;
      case 'Bekliyor': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // ============================================================
  // =================== SİLME İŞLEMLERİ ========================
  // ============================================================

  Future<void> _delete(MedicineReminderDto item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final bg = isDark ? const Color(0xFF132B44) : Colors.white;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Silinsin mi?',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        content: Text('${item.name} hatırlatıcısı silinecek.',
            style: TextStyle(color: fg)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: fg),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deleteReminder(item.id);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _hardDelete(MedicineReminderDto item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final bg = isDark ? const Color(0xFF132B44) : Colors.white;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kalıcı Silme',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        content: Text('${item.name} kalıcı olarak silinecek.',
            style: TextStyle(color: fg)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: fg),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Kalıcı Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.hardDeleteReminder(item.id);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ============================================================
  // =========================== UI ==============================
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : midnightBlue;

    final active = <MedicineReminderDto>[];
    final completed = <MedicineReminderDto>[];
    final deleted = <MedicineReminderDto>[];

    for (final r in _all) {
      final status = _statusText(r);
      if (status == 'Aktif' || status == 'Bekliyor') active.add(r);
      else if (status == 'Tamamlandı') completed.add(r);
      else deleted.add(r);
    }

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2B), Color(0xFF132B44), Color(0xFF1B3A5C)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFD4EAF7),
              Color(0xFFB8D8EB),
            ],
          );

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.reminder),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Tüm Hatırlatıcılar',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: fgColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: fgColor,
        iconTheme: IconThemeData(color: fgColor),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: fgColor))
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 15)))
                  : _all.isEmpty
                      ? Center(child: Text('Henüz hatırlatıcı eklenmemiş.', style: TextStyle(color: fgColor)))
                  : RawScrollbar(
                      controller: _scrollController,
                      thumbColor: fgColor.withValues(alpha: 0.3),
                      radius: const Radius.circular(20),
                      thickness: 6,
                      thumbVisibility: true,
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: fgColor,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          children: [
                            if (active.isNotEmpty) ...[
                              _sectionHeader('Aktif Planlar', Colors.green),
                              ...active.map((r) => _glassReminderCard(r)),
                            ],
                            if (completed.isNotEmpty) ...[
                              _sectionHeader('Tamamlananlar', Colors.blueGrey),
                              ...completed.map((r) => _glassReminderCard(r)),
                            ],
                            if (deleted.isNotEmpty) ...[
                              _sectionHeader('Silinenler', Colors.red),
                              ...deleted.map((r) => _glassReminderCard(r)),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : midnightBlue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _glassReminderCard(MedicineReminderDto item) {
    final status = _statusText(item);
    final isEditable = item.isActive && status != 'Tamamlandı';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF132B44).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (isDark ? Colors.white : midnightBlue)
                          .withValues(alpha: 0.12),
                      child: Icon(Icons.medication,
                          color: isDark ? Colors.white : midnightBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isDark ? Colors.white : midnightBlue),
                      ),
                    ),
                    _badge(_intakeText(item.intakeType),
                           item.intakeType == 0 ? Colors.orange : Colors.green),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_frequencyText(item)} · ${item.durationDays} Gün',
                  style: TextStyle(
                      color: (isDark ? Colors.white : midnightBlue)
                          .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(item.startDateUtc)} — ${_formatDate(item.startDateUtc.add(Duration(days: item.durationDays)))}',
                  style: TextStyle(
                      color: (isDark ? Colors.white : midnightBlue)
                          .withValues(alpha: 0.5),
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: item.timesOfDay.map((t) => _timeChip(t)).toList(),
                ),
                const Divider(height: 24, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _badge(status, _statusColor(status)),
                    Row(
                      children: [
                        if (isEditable) ...[
                          _actionButton(Icons.edit_rounded, Colors.blue, () {
                            Navigator.pop(context, item);
                          }),
                          const SizedBox(width: 8),
                          _actionButton(Icons.delete_outline_rounded, Colors.red, () => _delete(item)),
                        ] else
                          _actionButton(Icons.delete_forever_rounded, Colors.red, () => _hardDelete(item)),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _timeChip(String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : midnightBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(time.split(':').take(2).join(':'), style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}