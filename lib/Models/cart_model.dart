class CartResponse {
  final int cartId;
  final String status;
  final double total;
  final List<CartItem> items;

  CartResponse({
    required this.cartId,
    required this.status,
    required this.total,
    required this.items,
  });

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? []);
    return CartResponse(
      cartId: (json['cartId'] as num).toInt(),
      status: (json['status'] ?? '').toString(),
      total: (json['total'] as num? ?? 0).toDouble(),
      items: itemsJson.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class CartItem {
  final int id;
  final int pharmacyId;
  final String pharmacyName;
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  CartItem({
    required this.id,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: (json['id'] as num).toInt(),
      pharmacyId: (json['pharmacyId'] as num).toInt(),
      pharmacyName: (json['pharmacyName'] ?? '').toString(),
      medicineId: (json['medicineId'] as num).toInt(),
      medicineName: (json['medicineName'] ?? '').toString(),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
      lineTotal: (json['lineTotal'] as num? ?? 0).toDouble(),
    );
  }
}
