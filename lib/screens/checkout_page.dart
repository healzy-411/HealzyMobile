import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Models/cart_model.dart';
import '../Models/address_model.dart';
import '../Models/pharmacy_model.dart';
import '../Models/saved_card_model.dart';
import '../services/address_api_service.dart';
import '../services/api_service.dart';
import '../services/order_api_service.dart';
import '../services/saved_card_api_service.dart';
import '../services/token_store.dart';
import 'saved_cards_page.dart';
import '../utils/distance_utils.dart';
import 'package:healzy_app/config/api_config.dart';
import '../theme/app_colors.dart';

class CheckoutPage extends StatefulWidget {
  final CartResponse cart;
  final List<int>? prescriptionItemIds;
  final String? prescriptionNumber;

  const CheckoutPage({
    super.key,
    required this.cart,
    this.prescriptionItemIds,
    this.prescriptionNumber,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final String baseUrl = ApiConfig.baseUrl;

  late final AddressApiService _addressApi = AddressApiService(baseUrl: baseUrl);
  late final OrderApiService _orderApi = OrderApiService(baseUrl: baseUrl);
  late final SavedCardApiService _cardApi = SavedCardApiService(baseUrl: baseUrl);
  final _apiService = ApiService();

  // State
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<AddressDto> _addresses = [];
  AddressDto? _selectedAddress;
  Pharmacy? _pharmacy;
  List<SavedCardDto> _savedCards = [];

  // Form state
  final _orderNoteController = TextEditingController();
  bool _dontRingBell = false;
  bool _leaveAtDoor = false;
  String _paymentMethod = 'CashOnDelivery';
  int? _selectedCardId;
  int? _estimatedMinutes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _orderNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _addressApi.getMyAddresses(),
        _apiService.getPharmacies(),
        _cardApi.getMyCards(),
      ]);

      final addresses = results[0] as List<AddressDto>;
      final pharmacies = results[1] as List<Pharmacy>;
      final cards = results[2] as List<SavedCardDto>;

      // Secili veya default adresi bul
      final pharmacyId = widget.cart.items.first.pharmacyId;
      final pharmacy = pharmacies.where((p) => p.id == pharmacyId).firstOrNull;

      AddressDto? selectedAddr = addresses.where((a) => a.isSelected).firstOrNull;
      selectedAddr ??= addresses.where((a) => a.isDefault).firstOrNull;
      selectedAddr ??= addresses.firstOrNull;

      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddress = selectedAddr;
        _pharmacy = pharmacy;
        _savedCards = cards;
        _loading = false;
      });

      _calculateDeliveryTime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  void _calculateDeliveryTime() {
    if (_pharmacy == null || _selectedAddress == null) {
      setState(() => _estimatedMinutes = null);
      return;
    }
    final addrLat = _selectedAddress!.latitude;
    final addrLng = _selectedAddress!.longitude;
    if (addrLat == null || addrLng == null) {
      setState(() => _estimatedMinutes = null);
      return;
    }
    final dist = DistanceUtils.haversineKm(
      _pharmacy!.latitude,
      _pharmacy!.longitude,
      addrLat,
      addrLng,
    );
    setState(() => _estimatedMinutes = DistanceUtils.estimateDeliveryMinutes(dist));
  }

  Future<void> _changeAddress() async {
    if (_addresses.isEmpty) return;

    showModalBottomSheet(
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
              const Text("Teslimat Adresi Sec",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...(_addresses.map((a) => ListTile(
                    leading: Icon(
                      a.id == _selectedAddress?.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: Colors.orange,
                    ),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(a.fullLine(), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      try {
                        await _addressApi.selectAddress(a.id);
                      } catch (_) {}
                      setState(() => _selectedAddress = a);
                      _calculateDeliveryTime();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _completeOrder() async {
    // Validasyon
    if (_selectedAddress == null) {
      setState(() => _error = "Lutfen bir teslimat adresi secin.");
      return;
    }
    if (_paymentMethod == 'CreditCard' && _selectedCardId == null) {
      setState(() => _error = "Lutfen bir kart secin veya kapida odeme tercih edin.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final body = {
        'paymentMethod': _paymentMethod,
        'orderNote': _orderNoteController.text.trim().isEmpty
            ? null
            : _orderNoteController.text.trim(),
        'dontRingBell': _dontRingBell,
        'leaveAtDoor': _leaveAtDoor,
        'savedCardId': _paymentMethod == 'CreditCard' ? _selectedCardId : null,
      };

      await _orderApi.createFromMyCart(body: body);

      // Recete akisindan geldiysek, receteyi Used yap
      if (widget.prescriptionNumber != null &&
          widget.prescriptionNumber!.trim().isNotEmpty) {
        try {
          final token = TokenStore.get();
          await http.post(
            Uri.parse("$baseUrl/api/prescriptions/mark-used"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              "prescriptionNumber": widget.prescriptionNumber!.trim(),
            }),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF102E4A);
    final bg = isDark ? const Color(0xFF132B44) : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: bg,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00B894).withValues(alpha: 0.15),
                  radius: 36,
                  child: const Icon(Icons.celebration,
                      color: Color(0xFF00B894), size: 36),
                ),
                const SizedBox(height: 16),
                Text("Siparişiniz Oluşturuldu",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: fg)),
                const SizedBox(height: 8),
                Text("Teşekkür Ederiz!",
                    style: TextStyle(color: fg.withValues(alpha: 0.8))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF102E4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
                    child: const Text("Tamam",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ödeme"),
        elevation: 0.5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.lightPageGradient,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red[50],
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPharmacySection(),
                        const SizedBox(height: 16),
                        _buildCartSummarySection(),
                        const SizedBox(height: 16),
                        _buildOrderNoteSection(),
                        const SizedBox(height: 16),
                        _buildDeliveryPrefsSection(),
                        const SizedBox(height: 16),
                        _buildAddressSection(),
                        const SizedBox(height: 16),
                        _buildDeliveryMethodSection(),
                        const SizedBox(height: 16),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 16),
                        _buildPaymentSummarySection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                // Alt buton
                _buildBottomButton(),
              ],
            ),
      ),
    );
  }

  // ============= SECTION BUILDERS =============

  Widget _sectionCard({required String title, required Widget child, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.55),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
              ],
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // 1. Eczane Bilgileri
  Widget _buildPharmacySection() {
    if (_pharmacy == null) return const SizedBox.shrink();
    return _sectionCard(
      title: "Eczane Bilgileri",
      icon: Icons.local_pharmacy,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _pharmacy!.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 60, height: 60, color: Colors.grey[200],
                      child: const Icon(Icons.local_pharmacy, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pharmacy!.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_pharmacy!.address,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_pharmacy!.phone, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Sepet İçeriği
  Widget _buildCartSummarySection() {
    return _sectionCard(
      title: "Sepet İçeriği (${widget.cart.items.length} ürün)",
      icon: Icons.shopping_bag_outlined,
      child: Column(
        children: widget.cart.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.medicineName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text("${item.quantity} adet x ${item.unitPrice.toStringAsFixed(2)} TL",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text("${item.lineTotal.toStringAsFixed(2)} TL",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. Sipariş Notu
  Widget _buildOrderNoteSection() {
    return _sectionCard(
      title: "Sipariş Notu",
      icon: Icons.note_alt_outlined,
      child: TextField(
        controller: _orderNoteController,
        maxLength: 500,
        maxLines: 2,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: "Siparişle ilgili notunuz varsa yazın...",
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: IconButton(
            icon: const Icon(Icons.keyboard_hide),
            tooltip: "Klavyeyi Kapat",
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ),
      ),
    );
  }

  // 4. Teslimat Tercihleri
  Widget _buildDeliveryPrefsSection() {
    return _sectionCard(
      title: "Teslimat Tercihleri",
      icon: Icons.doorbell_outlined,
      child: Column(
        children: [
          CheckboxListTile(
            value: _dontRingBell,
            onChanged: (v) => setState(() => _dontRingBell = v ?? false),
            title: const Text("Zili Çalma"),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.orange,
          ),
          CheckboxListTile(
            value: _leaveAtDoor,
            onChanged: (v) => setState(() => _leaveAtDoor = v ?? false),
            title: const Text("Siparişi Kapıya Bırak"),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  // 5. Teslimat Adresi
  Widget _buildAddressSection() {
    return _sectionCard(
      title: "Teslimat Adresi",
      icon: Icons.location_on_outlined,
      child: _selectedAddress == null
          ? const Text("Adres bulunamadi. Lutfen profil sayfasindan adres ekleyin.",
              style: TextStyle(color: Colors.red))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedAddress!.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_selectedAddress!.fullLine(),
                    style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                const SizedBox(height: 4),
                Text("${_selectedAddress!.fullName} - ${_selectedAddress!.phone}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _changeAddress,
                  child: const Text("Değiştir",
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
    );
  }

  // 6. Teslimat Yöntemi
  Widget _buildDeliveryMethodSection() {
    return _sectionCard(
      title: "Teslimat Yöntemi",
      icon: Icons.delivery_dining,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Eczane Kurye",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          _estimatedMinutes != null
              ? Text("Tahmini teslimat: ~$_estimatedMinutes dakika",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14))
              : Text("Tahmini süre hesaplanamadı",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  // 7. Ödeme Yöntemi
  Widget _buildPaymentMethodSection() {
    return _sectionCard(
      title: "Ödeme Yöntemi",
      icon: Icons.payment,
      child: Column(
        children: [
          RadioListTile<String>(
            value: 'CashOnDelivery',
            groupValue: _paymentMethod,
            onChanged: (v) => setState(() {
              _paymentMethod = v!;
              _selectedCardId = null;
            }),
            title: const Text("Kapıda Ödeme"),
            secondary: const Icon(Icons.money, color: Colors.green),
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.orange,
          ),
          RadioListTile<String>(
            value: 'CreditCard',
            groupValue: _paymentMethod,
            onChanged: (v) => setState(() {
              _paymentMethod = v!;
              // Varsayılan kartı otomatik seç
              final defaultCard = _savedCards.where((c) => c.isDefault).firstOrNull;
              _selectedCardId = defaultCard?.id ?? _savedCards.firstOrNull?.id;
            }),
            title: const Text("Kredi Kartı"),
            secondary: const Icon(Icons.credit_card, color: Colors.blue),
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.orange,
          ),
          if (_paymentMethod == 'CreditCard') ...[
            const Divider(),
            if (_savedCards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Kayıtlı kart bulunamadı.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedCardsPage()),
                        );
                        _loadData();
                      },
                      icon: const Icon(Icons.add_card),
                      label: const Text("Kart Ekle"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_savedCards.map((card) => RadioListTile<int>(
                    value: card.id,
                    groupValue: _selectedCardId,
                    onChanged: (v) => setState(() => _selectedCardId = v),
                    title: Text(card.cardName),
                    subtitle: Text(
                        "**** ${card.maskedCardNumber} - ${card.cardholderName} - ${card.expiryMonth.toString().padLeft(2, '0')}/${card.expiryYear}"),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.orange,
                  ))),
          ],
        ],
      ),
    );
  }

  // 8. Ödeme Özeti
  Widget _buildPaymentSummarySection() {
    return _sectionCard(
      title: "Ödeme Özeti",
      icon: Icons.receipt_long,
      child: Column(
        children: [
          ...widget.cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text("${item.medicineName} x${item.quantity}",
                            style: TextStyle(color: Colors.grey[700], fontSize: 14))),
                    Text("${item.lineTotal.toStringAsFixed(2)} TL",
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Toplam",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${widget.cart.total.toStringAsFixed(2)} TL",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  // 10. Alt Buton
  Widget _buildBottomButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF132B44).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.55),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _submitting ? null : _completeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF102E4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Ödemeyi Tamamla",
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
