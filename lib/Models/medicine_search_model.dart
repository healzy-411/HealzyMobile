class MedicineSearchResult {
  final int medicineId;
  final String medicineName;
  final String categoryName;
  final String? description;
  final double referencePrice;
  final List<PharmacyPrice> pharmacies;

  MedicineSearchResult({
    required this.medicineId,
    required this.medicineName,
    required this.categoryName,
    this.description,
    required this.referencePrice,
    required this.pharmacies,
  });

  factory MedicineSearchResult.fromJson(Map<String, dynamic> json) {
    return MedicineSearchResult(
      medicineId: json['medicineId'] ?? 0,
      medicineName: json['medicineName'] ?? '',
      categoryName: json['categoryName'] ?? '',
      description: json['description'],
      referencePrice: (json['referencePrice'] ?? 0).toDouble(),
      pharmacies: (json['pharmacies'] as List? ?? [])
          .map((e) => PharmacyPrice.fromJson(e))
          .toList(),
    );
  }
}

class PharmacyCompareResult {
  final int pharmacyId;
  final String pharmacyName;
  final String district;
  final List<MedicineLine> lines;
  final double totalPrice;

  PharmacyCompareResult({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.district,
    required this.lines,
    required this.totalPrice,
  });

  factory PharmacyCompareResult.fromJson(Map<String, dynamic> json) {
    return PharmacyCompareResult(
      pharmacyId: json['pharmacyId'] ?? 0,
      pharmacyName: json['pharmacyName'] ?? '',
      district: json['district'] ?? '',
      lines: (json['lines'] as List? ?? [])
          .map((e) => MedicineLine.fromJson(e))
          .toList(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }
}

class MedicineLine {
  final int medicineId;
  final String medicineName;
  final double unitPrice;
  final int stockQuantity;

  MedicineLine({
    required this.medicineId,
    required this.medicineName,
    required this.unitPrice,
    required this.stockQuantity,
  });

  factory MedicineLine.fromJson(Map<String, dynamic> json) {
    return MedicineLine(
      medicineId: json['medicineId'] ?? 0,
      medicineName: json['medicineName'] ?? '',
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      stockQuantity: json['stockQuantity'] ?? 0,
    );
  }
}

class PharmacyPrice {
  final int pharmacyId;
  final String pharmacyName;
  final String pharmacyDistrict;
  final double unitPrice;
  final int quantity;
  final String? pharmacyImageUrl;

  PharmacyPrice({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.pharmacyDistrict,
    required this.unitPrice,
    required this.quantity,
    this.pharmacyImageUrl,
  });

  factory PharmacyPrice.fromJson(Map<String, dynamic> json) {
    return PharmacyPrice(
      pharmacyId: json['pharmacyId'] ?? 0,
      pharmacyName: json['pharmacyName'] ?? '',
      pharmacyDistrict: json['pharmacyDistrict'] ?? '',
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      pharmacyImageUrl: json['pharmacyImageUrl'],
    );
  }
}
