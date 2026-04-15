import 'package:flutter/material.dart';
import 'cart_api_service.dart';
import '../Models/cart_model.dart';

/// Sepete ekleme öncesi eczane çakışmasını kontrol eder.
/// Farklı eczaneden ürün varsa kullanıcıya dialog gösterir.
/// true dönerse ekleme yapılabilir, false dönerse iptal.
Future<bool> checkCartPharmacyConflict({
  required BuildContext context,
  required CartApiService cartApi,
  required int pharmacyId,
  required String pharmacyName,
}) async {
  CartResponse cart;
  try {
    cart = await cartApi.getMyCart();
  } catch (_) {
    // Sepet alınamazsa (token yok vs.) devam et, backend zaten kontrol eder
    return true;
  }

  if (cart.items.isEmpty) return true;

  final existingPharmacyId = cart.items.first.pharmacyId;
  if (existingPharmacyId == pharmacyId) return true;

  final existingPharmacyName = cart.items.first.pharmacyName;

  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Sepeti degistir"),
      content: Text(
        "Sepetinizde $existingPharmacyName eczanesinden urunler var. "
        "Sepeti temizleyip $pharmacyName eczanesinden urunleri eklemek istiyor musunuz?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Iptal"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF102E4A),
            foregroundColor: Colors.white,
          ),
          child: const Text("Sepeti Temizle ve Ekle"),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  try {
    await cartApi.clearCart();
  } catch (_) {}

  return true;
}
