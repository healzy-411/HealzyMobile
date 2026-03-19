class OrderItemDto {
  final int id;
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  OrderItemDto({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderItemDto.fromJson(Map<String, dynamic> j) {
    return OrderItemDto(
      id: (j['id'] ?? 0) as int,
      medicineId: (j['medicineId'] ?? 0) as int,
      medicineName: (j['medicineName'] ?? '') as String,
      quantity: (j['quantity'] ?? 0) as int,
      unitPrice: (j['unitPrice'] ?? 0).toDouble(),
      lineTotal: (j['lineTotal'] ?? 0).toDouble(),
    );
  }
}

class OrderDto {
  final int orderId;
  final int pharmacyId;
  final String pharmacyName;
  final String status;
  final double total;
  final DateTime createdAtUtc;
  final bool isPrescriptionOrder;

  final int deliveryAddressId;
  final String deliveryAddressSnapshot;
  final String? statusNote;

  final List<OrderItemDto> items;

  OrderDto({
    required this.orderId,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.status,
    required this.total,
    required this.createdAtUtc,
    required this.isPrescriptionOrder,
    required this.deliveryAddressId,
    required this.deliveryAddressSnapshot,
    this.statusNote,
    required this.items,
  });

  factory OrderDto.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['items'] as List? ?? []);
    return OrderDto(
      orderId: (j['orderId'] ?? 0) as int,
      pharmacyId: (j['pharmacyId'] ?? 0) as int,
      pharmacyName: (j['pharmacyName'] ?? '') as String,
      status: (j['status'] ?? '') as String,
      total: (j['total'] ?? 0).toDouble(),
      createdAtUtc: DateTime.parse(j['createdAtUtc'] as String),
      isPrescriptionOrder: (j['isPrescriptionOrder'] ?? false) as bool,

      deliveryAddressId: (j['deliveryAddressId'] ?? 0) as int,
      deliveryAddressSnapshot: (j['deliveryAddressSnapshot'] ?? '') as String,
      statusNote: j['statusNote'] as String?,

      items: itemsJson
          .map((x) => OrderItemDto.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}