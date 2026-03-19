class District {
  final int id;
  final String name;

  District({required this.id, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['district'] ?? json['District'] ?? json['name'] ?? '', // Arkadaşın 'district' mi 'name' mi yazdı emin olalım
    );
  }
}