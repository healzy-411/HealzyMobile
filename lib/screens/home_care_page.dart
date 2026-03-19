import 'package:flutter/material.dart';

import '../Models/home_care_models.dart';
import '../models/address_model.dart';
import '../services/address_api_service.dart';
import '../services/home_care_api_service.dart';
import '../services/local_notification_service.dart';

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

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String? selectedTimeSlot;
    final noteController = TextEditingController();
    String? error;
    bool submitting = false;

    // ✅ Dolu slot'ları disable etmek için
    final disabledSlots = <String>{};

    final timeSlots = <String>[
      '10:00',
      '12:00',
      '14:00',
      '16:00',
      '18:00',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tomorrow,
                        firstDate: tomorrow,
                        lastDate: now.add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;

                          // ✅ tarih değişince: slot/hata/disabled reset
                          selectedTimeSlot = null;
                          disabledSlots.clear();
                          error = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
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

                      return ChoiceChip(
                        label: Text(
                          slot,
                          style: TextStyle(
                            color: isDisabled ? Colors.black38 : null,
                          ),
                        ),
                        selected: selected,
                        onSelected: isDisabled
                            ? null
                            : (_) {
                                setModalState(() {
                                  selectedTimeSlot = slot;
                                  error = null; // seçince hata temizle
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
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800],
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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eve Serum Hizmeti'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sağlayıcılar'),
            Tab(text: 'Taleplerim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProvidersTab(),
          _buildRequestsTab(),
        ],
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
              style: const TextStyle(color: Colors.red, fontSize: 12),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                p.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(Icons.medical_services_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.city} / ${p.district}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.address,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                if (p.description != null && p.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.description!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.phone,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _openCreateRequestSheet(p),
                      child: const Text(
                        'Talep Oluştur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
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

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(r.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusText(r.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(r.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      '$dateText • ${r.timeSlot}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.addressSnapshot,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                if (r.note != null && r.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Not: ${r.note}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
                if (r.status == HomeCareRequestStatusModel.pending) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
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
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}