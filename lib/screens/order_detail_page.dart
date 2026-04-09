import 'package:flutter/material.dart';

import '../Models/order_model.dart';
import '../services/order_api_service.dart';
import '../services/review_api_service.dart';
import 'cart_page.dart';
import 'pharmacy_detail_page.dart';

class OrderDetailPage extends StatefulWidget {
  final String baseUrl;
  final OrderDto order;

  const OrderDetailPage({
    super.key,
    this.baseUrl = "http://localhost:5009",
    required this.order,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final OrderApiService _api;
  late final ReviewApiService _reviewApi;
  bool _loading = false;
  String? _error;
  bool _hasReviewed = true; // baslarken true, check bitince guncellenir

  @override
  void initState() {
    super.initState();
    _api = OrderApiService(baseUrl: widget.baseUrl);
    _reviewApi = ReviewApiService(baseUrl: widget.baseUrl);
    _checkReview();
  }

  Future<void> _checkReview() async {
    if (widget.order.status != "Delivered") return;
    try {
      final has = await _reviewApi.hasReviewedOrder(widget.order.orderId);
      if (!mounted) return;
      setState(() => _hasReviewed = has);
    } catch (_) {}
  }

  Future<void> _repeatOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.repeatOrder(widget.order.orderId);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartPage()),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst("Exception: ", "");
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showRatingDialog() async {
    int selectedRating = 0;
    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text("Degerlendirme"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Bu siparisi nasil buldunuz?"),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() => selectedRating = i + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: "Yorumunuz (istege bagli)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Iptal"),
                ),
                ElevatedButton(
                  onPressed: selectedRating > 0
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A79D),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Gonder"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || selectedRating == 0) return;

    try {
      await _reviewApi.createReview(
        orderId: widget.order.orderId,
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _hasReviewed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Degerlendirmeniz kaydedildi!")),
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

    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;

    return Scaffold(
      appBar: AppBar(
        title: Text("Siparis #${o.orderId}"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PharmacyDetailPage(pharmacyId: o.pharmacyId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            o.pharmacyName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00A79D),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF00A79D)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _infoRow(Icons.access_time, "Durum", _statusText(o.status)),
                  const SizedBox(height: 4),
                  _infoRow(Icons.calendar_today, "Tarih",
                      "${o.createdAtUtc.day.toString().padLeft(2, '0')}."
                      "${o.createdAtUtc.month.toString().padLeft(2, '0')}."
                      "${o.createdAtUtc.year} "
                      "${o.createdAtUtc.hour.toString().padLeft(2, '0')}:"
                      "${o.createdAtUtc.minute.toString().padLeft(2, '0')}"),
                  if (o.statusNote != null && o.statusNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.note, "Eczane Notu", o.statusNote!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Teslimat bilgileri
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Teslimat Bilgileri",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(Icons.location_on, "Adres", o.deliveryAddressSnapshot),
                  if (o.deliveryNote != null && o.deliveryNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.info_outline, "Teslimat Notu", o.deliveryNote!),
                  ],
                  if (o.orderNote != null && o.orderNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.message, "Siparis Notu", o.orderNote!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Ödeme bilgileri
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Odeme Bilgileri",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.payment,
                    "Odeme Yontemi",
                    o.paymentMethod == "CreditCard" ? "Kredi Karti" : "Kapida Odeme",
                  ),
                  if (o.paymentMethod == "CreditCard" && o.cardNameSnapshot != null) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.credit_card, "Kart", "${o.cardNameSnapshot} (**** ${o.maskedCardNumberSnapshot ?? ''})"),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Ürünler
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Urunler",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...o.items.map(
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "${i.medicineName} x${i.quantity}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            "${i.lineTotal.toStringAsFixed(2)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Toplam",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${o.total.toStringAsFixed(2)} TL",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (o.isPrescriptionOrder || _loading)
                    ? null
                    : _repeatOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        o.isPrescriptionOrder
                            ? "Receteli siparis tekrar edilemez"
                            : "Tekrarla",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            // Degerlendirme butonu
            if (o.status == "Delivered" && !_hasReviewed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showRatingDialog,
                  icon: const Icon(Icons.star_outline),
                  label: const Text(
                    "Degerlendir",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A79D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text("$label: ", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
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
        return "Iptal Edildi";
      default:
        return status;
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
