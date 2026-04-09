class Pharmacy {
  final int id;
  final String name;
  final String district;      // C#'taki District
  final String address;       // C#'taki Address
  final String phone;         // C#'taki Phone
  final String workingHours;  // C#'taki WorkingHours
  final double latitude;      // C#'taki Latitude
  final double longitude;     // C#'taki Longitude
  final String imageUrl;      // C#'taki ImageUrl
  final double averageRating;
  final int reviewCount;
  final bool isOpen;
  final bool isOnDuty;

  Pharmacy({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.workingHours,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isOpen = true,
    this.isOnDuty = false,
  });

  // JSON verisini Flutter nesnesine çeviren fabrika
  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    return Pharmacy(
      // Not: Backend'den gelen veriler genellikle küçük harfle (camelCase) başlar.
      // Ancak C# bazen Büyük Harfle (PascalCase) gönderebilir.
      // Bu yüzden her ikisini de kontrol ediyoruz (?? operatörü ile).
      
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      district: json['district'] ?? json['District'] ?? '',
      address: json['address'] ?? json['Address'] ?? '',
      phone: json['phone'] ?? json['Phone'] ?? '',
      workingHours: json['workingHours'] ?? json['WorkingHours'] ?? '09:00 - 18:00',
      latitude: (json['latitude'] ?? json['Latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['Longitude'] ?? 0).toDouble(),
      
      // Eğer backend resim yollamazsa varsayılan bir eczane resmi koyuyoruz
      imageUrl: json['imageUrl'] ?? json['ImageUrl'] ?? 'https://img.freepik.com/free-photo/pharmacy-store-interior-blur-background_1484-1596.jpg',
      averageRating: (json['averageRating'] ?? json['AverageRating'] ?? 0).toDouble(),
      reviewCount: (json['reviewCount'] ?? json['ReviewCount'] ?? 0) as int,
      isOpen: (json['isOpen'] ?? json['IsOpen'] ?? true) as bool,
      isOnDuty: (json['isOnDuty'] ?? json['IsOnDuty'] ?? false) as bool,
    );
  }
}