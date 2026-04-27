import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Models/home_care_models.dart';
import '../Models/address_model.dart';
import '../services/address_api_service.dart';
import '../services/home_care_api_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_colors.dart';
import 'package:healzy_app/config/api_config.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../widgets/healzy_bottom_nav.dart';

class HomeCarePage extends StatefulWidget {
  final String baseUrl;

  const HomeCarePage({super.key, required this.baseUrl});

  @override
  State<HomeCarePage> createState() => _HomeCarePageState();
}

class _HomeCarePageState extends State<HomeCarePage>
    with SingleTickerProviderStateMixin {
  late final HomeCareApiService _api =
      HomeCareApiService(baseUrl: widget.baseUrl);
  late final AddressApiService _addressApi =
      AddressApiService(baseUrl: widget.baseUrl);

  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  bool _loadingProviders = true;
  bool _loadingRequests = true;
  bool _loadingAddresses = true;

  String? _errorProviders;
  String? _errorRequests;
  String? _errorAddresses;

  List<AddressDto> _addresses = [];
  AddressDto? _selectedAddress;

  List<HomeCareProviderModel> _providers = [];
  List<HomeCareRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadProviders(); // ✅ adres olmasa bile providers gelsin
    _loadRequests();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _errorAddresses = null;
    });

    try {
      final list = await _addressApi.getMyAddresses();
      AddressDto? selected;
      if (list.isNotEmpty) {
        selected = list.firstWhere(
          (a) => a.isSelected,
          orElse: () => list.first,
        );
      }

      if (!mounted) return;
      setState(() {
        _addresses = list;
        _selectedAddress = selected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAddresses = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingAddresses = false;
      });
    }
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _errorProviders = null;
    });

    try {
      final list = await _api.getProviders(); // ✅ filtresiz
      if (!mounted) return;
      setState(() {
        _providers = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorProviders = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingProviders = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loadingRequests = true;
      _errorRequests = null;
    });

    try {
      final list = await _api.getMyRequests();
      if (!mounted) return;
      setState(() {
        _requests = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorRequests = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingRequests = false;
      });
    }
  }

  Future<void> _openCreateRequestSheet(HomeCareProviderModel provider) async {
    final addr = _selectedAddress;
    if (addr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir teslimat adresi seçin.'),
        ),
      );
      return;
    }

    DateTime selectedDate = DateTime.now();
    String? selectedTimeSlot;
    final noteController = TextEditingController();
    String? error;
    bool submitting = false;

    // ✅ Dolu slot'ları disable etmek için
    final disabledSlots = <String>{};

    // ✅ Sağlayıcının admin panelinden tanımladığı zaman slotları
    List<String> timeSlots = [];
    List<Map<String, dynamic>> slotAvailability = [];

    Future<void> loadSlotAvailability(DateTime date) async {
      try {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        slotAvailability = await _api.getSlotAvailability(provider.id, dateStr);
        timeSlots = slotAvailability.map((s) => (s['label'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        disabledSlots.clear();
        final now = DateTime.now();
        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

        for (final s in slotAvailability) {
          final label = (s['label'] ?? '').toString();

          // Dolu slot
          if (s['isFull'] == true) {
            disabledSlots.add(label);
            continue;
          }

          // Bugünse ve saat geçmişse devre dışı bırak
          if (isToday && label.isNotEmpty) {
            // "08:00 - 09:00" veya "08:00" formatından saati parse et
            final timePart = label.split('-').first.trim();
            final parts = timePart.split(':');
            if (parts.length == 2) {
              final hour = int.tryParse(parts[0]) ?? 0;
              final minute = int.tryParse(parts[1]) ?? 0;
              if (hour < now.hour || (hour == now.hour && minute <= now.minute)) {
                disabledSlots.add(label);
              }
            }
          }
        }
      } catch (_) {
        // Fallback: eski yöntem
        try {
          timeSlots = await _api.getProviderTimeSlots(provider.id);
        } catch (_) {}
      }
    }

    await loadSlotAvailability(selectedDate);

    if (!mounted) return;
    if (timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu sağlayıcı henüz zaman slotu tanımlamamış.')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : AppColors.pearl;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : Colors.grey.shade300;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return GestureDetector(
              onTap: () => FocusScope.of(ctx).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Evde Serum Talebi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    addr.fullLine(),
                    style: TextStyle(fontSize: 14, color: subColor),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tarih Seç',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate.isBefore(today) ? today : selectedDate,
                        firstDate: today,
                        lastDate: now.add(const Duration(days: 30)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.fromSeed(
                                seedColor: AppColors.midnight,
                                brightness: isDark
                                    ? Brightness.dark
                                    : Brightness.light,
                                primary: isDark ? AppColors.pearl : AppColors.midnight,
                                surface: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightBlueSoft,
                                onSurface: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.midnight,
                              ),
                              dialogTheme: DialogThemeData(
                                backgroundColor: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightBlueSoft,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        selectedDate = picked;
                        selectedTimeSlot = null;
                        error = null;
                        // Tarih değişince slot availability yeniden yükle
                        await loadSlotAvailability(picked);
                        setModalState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saat Seç',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // ✅ Dolu slot = disabled
                  Wrap(
                    spacing: 8,
                    children: timeSlots.map((slot) {
                      final selected = selectedTimeSlot == slot;
                      final isDisabled = disabledSlots.contains(slot);

                      final chipFg = isDisabled
                          ? subColor.withValues(alpha: 0.5)
                          : (selected
                              ? (isDark ? AppColors.midnight : Colors.white)
                              : (isDark ? Colors.white : AppColors.midnight));
                      return ChoiceChip(
                        label: Text(slot, style: TextStyle(color: chipFg)),
                        selected: selected,
                        selectedColor: isDark
                            ? AppColors.pearl
                            : AppColors.midnight,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceElevated
                            : Colors.white,
                        side: BorderSide(color: borderColor),
                        onSelected: isDisabled
                            ? null
                            : (_) {
                                setModalState(() {
                                  selectedTimeSlot = slot;
                                  error = null;
                                });
                              },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Not (opsiyonel)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Kısa bir not bırakabilirsiniz',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF102E4A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: submitting ? null : () async {
                        if (submitting) return;
                        setModalState(() => submitting = true);

                        if (selectedTimeSlot == null) {
                          setModalState(() {
                            error = 'Lütfen bir saat seçin.';
                            submitting = false;
                          });
                          return;
                        }

                        try {
                          // ✅ EN ÖNEMLİ FIX:
                          // local date -> UTC midnight date-only (timezone kaymasın)
                          final dateOnlyUtc = DateTime.utc(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                          );

                          final request = await _api.createRequest(
                            providerId: provider.id,
                            addressId: addr.id,
                            serviceDate: dateOnlyUtc, // ✅ burada UTC date-only gönderiyoruz
                            timeSlot: selectedTimeSlot!,
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );

                          await LocalNotificationService.I.scheduleOneTime(
                            id: 800000 + request.id,
                            title: 'Evde serum talebiniz alındı',
                            body: '${provider.name} için talebiniz beklemede.',
                            whenLocal: DateTime.now().add(
                              const Duration(seconds: 2),
                            ),
                          );

                          final parts = request.timeSlot.split(':');
                          if (parts.length == 2) {
                            final hh = int.tryParse(parts[0]) ?? 0;
                            final mm = int.tryParse(parts[1]) ?? 0;

                            final localDate = DateTime(
                              request.serviceDateUtc.year,
                              request.serviceDateUtc.month,
                              request.serviceDateUtc.day,
                              hh,
                              mm,
                            );

                            final remindAt =
                                localDate.subtract(const Duration(hours: 1));

                            if (remindAt.isAfter(DateTime.now())) {
                              await LocalNotificationService.I.scheduleOneTime(
                                id: 810000 + request.id,
                                title: 'Yaklaşan evde serum randevusu',
                                body:
                                    '${provider.name} için ${request.timeSlot} saatinde evde serum randevunuz var.',
                                whenLocal: remindAt,
                              );
                            }
                          }

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Talebiniz oluşturuldu. Durum: Beklemede'),
                            ),
                          );
                          await _loadRequests();
                        } catch (e) {
                          final msg =
                              e.toString().replaceFirst('Exception: ', '');

                          setModalState(() {
                            error = msg;

                            // ✅ kontenjan dolu ise seçili slot'u disable et
                            if (msg.toLowerCase().contains('kontenjan dolu') &&
                                selectedTimeSlot != null) {
                              disabledSlots.add(selectedTimeSlot!);
                              selectedTimeSlot = null; // yeni slot seçsin
                            }
                          });
                        } finally {
                          setModalState(() => submitting = false);
                        }
                      },
                      child: const Text(
                        'Talebi Gönder',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(HomeCareRequestStatusModel s) {
    switch (s) {
      case HomeCareRequestStatusModel.pending:
        return Colors.orange;
      case HomeCareRequestStatusModel.accepted:
        return Colors.green;
      case HomeCareRequestStatusModel.rejected:
        return Colors.red;
      case HomeCareRequestStatusModel.cancelled:
        return Colors.grey;
      case HomeCareRequestStatusModel.completed:
        return const Color(0xFF00B894);
    }
  }

  String _statusText(HomeCareRequestStatusModel s) {
    switch (s) {
      case HomeCareRequestStatusModel.pending:
        return 'Beklemede';
      case HomeCareRequestStatusModel.accepted:
        return 'Onaylandı';
      case HomeCareRequestStatusModel.rejected:
        return 'Reddedildi';
      case HomeCareRequestStatusModel.cancelled:
        return 'İptal edildi';
      case HomeCareRequestStatusModel.completed:
        return 'Tamamlandı';
    }
  }

  void _showRequestDetail(HomeCareRequestModel r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.pearl,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final labelColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final valueTextColor =
            isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
        Widget row(String label, String? value, {Color? valueColor}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(label,
                    style: TextStyle(fontSize: 14, color: labelColor, fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: Text(
                    value == null || value.isEmpty ? '—' : value,
                    style: TextStyle(
                      fontSize: 14,
                      color: valueColor ?? valueTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Talep #${r.id}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(r.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_statusText(r.status),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: _statusColor(r.status))),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                row('Sağlayıcı', r.providerName),
                row('Hizmet Tarihi',
                  '${r.serviceDateUtc.day.toString().padLeft(2, '0')}.${r.serviceDateUtc.month.toString().padLeft(2, '0')}.${r.serviceDateUtc.year} • ${r.timeSlot}'),
                row('Adres', r.addressSnapshot),
                row('Notunuz', r.note),
                row('Oluşturulma',
                  '${r.createdAtUtc.day.toString().padLeft(2, '0')}.${r.createdAtUtc.month.toString().padLeft(2, '0')}.${r.createdAtUtc.year} ${r.createdAtUtc.hour.toString().padLeft(2, '0')}:${r.createdAtUtc.minute.toString().padLeft(2, '0')}'),
                row('Atanan Çalışan', r.assignedEmployeeName),
                if (r.status == HomeCareRequestStatusModel.completed) ...[
                  row('Kazanç',
                    r.earningAmount != null
                      ? '${r.earningAmount!.toStringAsFixed(2)} TL'
                      : null,
                    valueColor: Colors.green.shade700),
                  row('Tamamlanma',
                    r.completedAtUtc != null
                      ? '${r.completedAtUtc!.day.toString().padLeft(2, '0')}.${r.completedAtUtc!.month.toString().padLeft(2, '0')}.${r.completedAtUtc!.year} ${r.completedAtUtc!.hour.toString().padLeft(2, '0')}:${r.completedAtUtc!.minute.toString().padLeft(2, '0')}'
                      : null),
                  row('Çalışan Notu', r.completionNote,
                      valueColor: isDark ? Colors.white : Colors.indigo.shade700),
                ],
                if (r.status == HomeCareRequestStatusModel.cancelled ||
                    r.status == HomeCareRequestStatusModel.rejected)
                  row('İptal / Red Nedeni', r.statusNote, valueColor: Colors.red.shade700),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? AppColors.darkGradient
        : AppColors.lightPageGradient;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: const Text('Eve Serum Hizmeti'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor:
              isDark ? AppColors.pearl : AppColors.midnight,
          labelColor:
              isDark ? AppColors.pearl : AppColors.midnight,
          unselectedLabelColor:
              isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Sağlayıcılar'),
            Tab(text: 'Taleplerim'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          top: false,
          bottom: false,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProvidersTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProvidersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadAddresses();
        await _loadProviders();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadingAddresses) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          const Text(
            'Adres',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_addresses.isEmpty && !_loadingAddresses)
            const Text(
              'Kayıtlı adresiniz bulunamadı. Lütfen önce bir adres ekleyin.',
              style: TextStyle(color: Colors.red),
            )
          else
            DropdownButtonFormField<AddressDto>(
              value: _selectedAddress,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _addresses
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          a.shortLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAddress = val;
                });
              },
            ),
          if (_errorAddresses != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorAddresses!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Sağlayıcılar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadingProviders)
            const Center(child: CircularProgressIndicator())
          else if (_errorProviders != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorProviders!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_providers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Aktif sağlayıcı bulunamadı.'),
            )
          else
            ..._providers.map(_buildProviderCard),
        ],
      ),
    );
  }

  Widget _buildProviderCard(HomeCareProviderModel p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bodyColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.midnight).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.midnight.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              child: Image.network(
                p.imageUrl!.startsWith('http') ? p.imageUrl! : '${ApiConfig.baseUrl}${p.imageUrl}',
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheHeight: 280,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.surface,
                  alignment: Alignment.center,
                  child: Icon(Icons.medical_services_outlined, color: subColor),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.city} / ${p.district}',
                  style: TextStyle(fontSize: 14, color: subColor),
                ),
                const SizedBox(height: 4),
                Text(
                  p.address,
                  style: TextStyle(fontSize: 14, color: bodyColor),
                ),
                if (p.description != null && p.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.description!,
                    style: TextStyle(fontSize: 14, color: bodyColor),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse('tel:${p.phone}')),
                        child: Row(
                        children: [
                          Icon(Icons.phone_rounded,
                              size: 16, color: titleColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: titleColor,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? AppColors.pearlGradient
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          onTap: () => _openCreateRequestSheet(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Text(
                              'Talep Oluştur',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.midnight
                                    : AppColors.pearl,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            if (_loadingRequests) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_errorRequests != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorRequests!,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (_requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text("Henuz bir talebiniz yok.", style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final r = _requests[index - 1];
          final date = r.serviceDateUtc;
          final dateText =
              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark
              ? AppColors.darkSurface
              : AppColors.lightBlueSoft.withValues(alpha: 0.55);
          final titleColor =
              isDark ? AppColors.darkTextPrimary : AppColors.midnight;
          final subColor =
              isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
          final bodyColor =
              isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

          return InkWell(
            onTap: () => _showRequestDetail(r),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.midnight.withValues(alpha: 0.10),
              ),
              boxShadow: AppShadows.soft(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(r.status)
                            .withValues(alpha: isDark ? 0.25 : 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _statusText(r.status),
                        style: TextStyle(
                          fontSize: 14,
                          color: _statusColor(r.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Text(
                      '$dateText • ${r.timeSlot}',
                      style: TextStyle(fontSize: 14, color: subColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.addressSnapshot,
                  style: TextStyle(fontSize: 14, color: bodyColor),
                ),
                if (r.note != null && r.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Not: ${r.note}',
                    style: TextStyle(fontSize: 14, color: bodyColor),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRequestDetail(r),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Detay'),
                      style: TextButton.styleFrom(
                        foregroundColor: titleColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    if (r.status == HomeCareRequestStatusModel.pending)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await _api.cancelRequest(r.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Talep iptal edildi.'),
                              ),
                            );
                            await _loadRequests();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e
                                      .toString()
                                      .replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Talebi İptal Et'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}