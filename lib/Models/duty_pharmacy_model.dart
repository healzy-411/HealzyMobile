class DutyPharmacyModel {
  final int id;
  final String city;
  final String district;
  final String shortName;
  final String pharmacyName;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String? dutyDate;

  DutyPharmacyModel({
    required this.id,
    required this.city,
    required this.district,
    required this.shortName,
    required this.pharmacyName,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.dutyDate,
  });

  factory DutyPharmacyModel.fromJson(Map<String, dynamic> json) {
    double? toDoubleOrNull(dynamic v) {
      if (v == null) return null;
      return (v as num).toDouble();
    }

    return DutyPharmacyModel(
      id: json['id'] ?? json['Id'] ?? 0,
      city: json['city'] ?? json['City'] ?? '',
      district: json['district'] ?? json['District'] ?? '',
      shortName: json['shortName'] ?? json['ShortName'] ?? '',
      pharmacyName: json['pharmacyName'] ?? json['PharmacyName'] ?? '',
      address: json['address'] ?? json['Address'] ?? '',
      phone: json['phone'] ?? json['Phone'] ?? '',
      latitude: toDoubleOrNull(json['latitude'] ?? json['Latitude']),
      longitude: toDoubleOrNull(json['longitude'] ?? json['Longitude']),
      dutyDate: (json['dutyDate'] ?? json['DutyDate'])?.toString(),
    );
  }
}
