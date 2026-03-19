class Neighborhood {
  final int id;
  final String name;

  Neighborhood({required this.id, required this.name});

  factory Neighborhood.fromJson(Map<String, dynamic> json) => Neighborhood(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
      );
}