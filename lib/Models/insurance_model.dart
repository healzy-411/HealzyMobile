class Insurance {
  final int id;
  final String name;

  Insurance({
    required this.id,
    required this.name,
  });

  factory Insurance.fromJson(Map<String, dynamic> json) {
    return Insurance(
      id: json['id'],
      name: json['name'],
    );
  }
}
