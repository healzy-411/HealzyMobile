import 'pharmacy_model.dart';

class PrescriptionItemDto {
  final int itemId;
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  PrescriptionItemDto({
    required this.itemId,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory PrescriptionItemDto.fromJson(Map<String, dynamic> j) {
    return PrescriptionItemDto(
      itemId: (j['itemId'] ?? 0) as int,
      medicineId: (j['medicineId'] ?? 0) as int,
      medicineName: (j['medicineName'] ?? '') as String,
      quantity: (j['quantity'] ?? 0) as int,
      unitPrice: (j['unitPrice'] ?? 0).toDouble(),
      lineTotal: (j['lineTotal'] ?? 0).toDouble(),
    );
  }
}

class PrescriptionDetailDto {
  final String prescriptionNumber;
  final double insuranceDiscountRate;
  final List<PrescriptionItemDto> items;

  PrescriptionDetailDto({
    required this.prescriptionNumber,
    required this.insuranceDiscountRate,
    required this.items,
  });

  factory PrescriptionDetailDto.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['items'] as List? ?? []);
    return PrescriptionDetailDto(
      prescriptionNumber: (j['prescriptionNumber'] ?? '') as String,
      insuranceDiscountRate: (j['insuranceDiscountRate'] ?? 0).toDouble(),
      items: itemsJson
          .map((x) => PrescriptionItemDto.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PrescriptionPriceResultDto {
  final String prescriptionNumber;
  final double totalBeforeDiscount;
  final double discountRate;
  final double discountAmount;
  final double netTotal;
  final List<PrescriptionItemDto> items;
  final List<Pharmacy> pharmacies;

  PrescriptionPriceResultDto({
    required this.prescriptionNumber,
    required this.totalBeforeDiscount,
    required this.discountRate,
    required this.discountAmount,
    required this.netTotal,
    required this.items,
    required this.pharmacies,
  });

  factory PrescriptionPriceResultDto.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['items'] as List? ?? []);
    final phJson = (j['pharmacies'] as List? ?? []);

    return PrescriptionPriceResultDto(
      prescriptionNumber: (j['prescriptionNumber'] ?? '') as String,
      totalBeforeDiscount: (j['totalBeforeDiscount'] ?? 0).toDouble(),
      discountRate: (j['discountRate'] ?? 0).toDouble(),
      discountAmount: (j['discountAmount'] ?? 0).toDouble(),
      netTotal: (j['netTotal'] ?? 0).toDouble(),
      items: itemsJson
          .map((x) => PrescriptionItemDto.fromJson(x as Map<String, dynamic>))
          .toList(),
      pharmacies: phJson
          .map((x) => Pharmacy.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}

