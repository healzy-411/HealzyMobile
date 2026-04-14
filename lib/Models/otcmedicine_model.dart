class OtcMedicine {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? prospectusUrl;
  final String? description;
  final String? barcode;
  final int quantity;

  OtcMedicine({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.prospectusUrl,
    this.description,
    this.barcode,
    this.quantity = 0,
  });

  factory OtcMedicine.fromJson(Map<String, dynamic> json) {
    return OtcMedicine(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      prospectusUrl: json['prospectusUrl'] as String?,
      description: json['description'] as String?,
      barcode: json['barcode'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}
