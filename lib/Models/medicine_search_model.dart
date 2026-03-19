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
