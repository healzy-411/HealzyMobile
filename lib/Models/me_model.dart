class MeDto {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String phoneNumber;

  MeDto({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.phoneNumber,
  });

  factory MeDto.fromJson(Map<String, dynamic> j) {
    return MeDto(
      userId: (j["userId"] ?? "").toString(),
      email: (j["email"] ?? "").toString(),
      fullName: (j["fullName"] ?? "").toString(),
      role: (j["role"] ?? "").toString(),
      phoneNumber: (j["phoneNumber"] ?? "").toString(),
    );
  }
}