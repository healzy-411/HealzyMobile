class OtcMedicine {
  final int id;
  final String name;
  final double price;

  OtcMedicine({
    required this.id,
    required this.name,
    required this.price,
  });

  factory OtcMedicine.fromJson(Map<String, dynamic> json) {
    return OtcMedicine(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
    );
  }
}
