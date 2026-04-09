class AddressDto {
  final int id;
  final String title;
  final String fullName;
  final String phone;
  final String city;
  final String district;
  final String neighborhood;
  final String addressLine;
  final String? postalCode;
  final String? addressDescription;

  final double? latitude;
  final double? longitude;

  final bool isDefault;
  final bool isSelected;

  AddressDto({
    required this.id,
    required this.title,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.addressLine,
    required this.postalCode,
    required this.addressDescription,
    this.latitude,
    this.longitude,
    required this.isDefault,
    required this.isSelected,
  });

  factory AddressDto.fromJson(Map<String, dynamic> j) {
    return AddressDto(
      id: (j['id'] ?? 0) as int,
      title: (j['title'] ?? '') as String,
      fullName: (j['fullName'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      city: (j['city'] ?? '') as String,
      district: (j['district'] ?? '') as String,
      neighborhood: (j['neighborhood'] ?? '') as String,
      addressLine: (j['addressLine'] ?? '') as String,
      postalCode: j['postalCode']?.toString(),

      addressDescription: j['addressDescription']?.toString(),

      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),

      isDefault: (j['isDefault'] ?? false) as bool,
      isSelected: (j['isSelected'] ?? false) as bool,
    );
  }

  // ✅ HomePage'de seçili adresi local listte güncellemek için
  AddressDto copyWith({
    int? id,
    String? title,
    String? fullName,
    String? phone,
    String? city,
    String? district,
    String? neighborhood,
    String? addressLine,
    String? postalCode,
    String? addressDescription,
    double? latitude,
    double? longitude,
    bool? isDefault,
    bool? isSelected,
  }) {
    return AddressDto(
      id: id ?? this.id,
      title: title ?? this.title,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      addressLine: addressLine ?? this.addressLine,
      postalCode: postalCode ?? this.postalCode,
      addressDescription: addressDescription ?? this.addressDescription,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,

      isDefault: isDefault ?? this.isDefault,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  // ✅ Header’da kısa gösterim
  String shortLine() {
    final parts = [
      title.isNotEmpty ? title : null,
      "$city/$district",
      neighborhood,
    ]
        .where((x) => x != null && x!.trim().isNotEmpty)
        .map((x) => x!.trim())
        .toList();

    return parts.join(" • ");
  }

  // ✅ Listede detay gösterim
  String fullLine() {
    final parts = [
      "$city/$district",
      neighborhood,
      addressLine,
      postalCode,
      // addressDescription'ı listede göstermek istersen aç:
      // addressDescription,
    ]
        .where((x) => x != null && x.toString().trim().isNotEmpty)
        .map((x) => x.toString().trim())
        .toList();

    return parts.join(", ");
  }
}