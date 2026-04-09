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
  final DateTime updatedAtUtc;
  final bool isPrescriptionOrder;

  final int deliveryAddressId;
  final String deliveryAddressSnapshot;
  final String? statusNote;
  final String? paymentMethod;
  final String? orderNote;
  final String? deliveryNote;
  final String? cardNameSnapshot;
  final String? maskedCardNumberSnapshot;
  final String? customerName;

  final double? pharmacyLatitude;
  final double? pharmacyLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  final List<OrderItemDto> items;

  OrderDto({
    required this.orderId,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.status,
    required this.total,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.isPrescriptionOrder,
    required this.deliveryAddressId,
    required this.deliveryAddressSnapshot,
    this.statusNote,
    this.paymentMethod,
    this.orderNote,
    this.deliveryNote,
    this.cardNameSnapshot,
    this.maskedCardNumberSnapshot,
    this.customerName,
    this.pharmacyLatitude,
    this.pharmacyLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
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
      updatedAtUtc: DateTime.parse(j['updatedAtUtc'] as String),
      isPrescriptionOrder: (j['isPrescriptionOrder'] ?? false) as bool,

      deliveryAddressId: (j['deliveryAddressId'] ?? 0) as int,
      deliveryAddressSnapshot: (j['deliveryAddressSnapshot'] ?? '') as String,
      statusNote: j['statusNote'] as String?,
      paymentMethod: j['paymentMethod'] as String?,
      orderNote: j['orderNote'] as String?,
      deliveryNote: j['deliveryNote'] as String?,
      cardNameSnapshot: j['cardNameSnapshot'] as String?,
      maskedCardNumberSnapshot: j['maskedCardNumberSnapshot'] as String?,
      customerName: j['customerName'] as String?,

      pharmacyLatitude: (j['pharmacyLatitude'] as num?)?.toDouble(),
      pharmacyLongitude: (j['pharmacyLongitude'] as num?)?.toDouble(),
      deliveryLatitude: (j['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (j['deliveryLongitude'] as num?)?.toDouble(),

      items: itemsJson
          .map((x) => OrderItemDto.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}