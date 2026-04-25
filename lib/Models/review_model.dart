class ReviewDto {
  final int id;
  final String userFirstName;
  final int rating;
  final String? comment;
  final DateTime createdAtUtc;

  ReviewDto({
    required this.id,
    required this.userFirstName,
    required this.rating,
    this.comment,
    required this.createdAtUtc,
  });

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    return ReviewDto(
      id: json['id'] ?? 0,
      userFirstName: json['userFirstName'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}

class PharmacyDetailModel {
  final int pharmacyId;
  final String name;
  final String district;
  final String address;
  final String phone;
  final String workingHours;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final double averageRating;
  final int reviewCount;
  final List<ReviewDto> recentReviews;
  final bool isOpen;

  PharmacyDetailModel({
    required this.pharmacyId,
    required this.name,
    required this.district,
    required this.address,
    required this.phone,
    required this.workingHours,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.averageRating,
    required this.reviewCount,
    required this.recentReviews,
    this.isOpen = true,
  });

  factory PharmacyDetailModel.fromJson(Map<String, dynamic> json) {
    return PharmacyDetailModel(
      pharmacyId: json['pharmacyId'] ?? 0,
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      workingHours: json['workingHours'] ?? '',
      imageUrl: json['imageUrl'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      recentReviews: (json['recentReviews'] as List? ?? [])
          .map((e) => ReviewDto.fromJson(e))
          .toList(),
      isOpen: json['isOpen'] ?? true,
    );
  }
}
