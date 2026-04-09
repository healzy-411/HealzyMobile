class SavedCardDto {
  final int id;
  final String cardName;
  final String cardholderName;
  final String maskedCardNumber;
  final int expiryMonth;
  final int expiryYear;
  final bool isDefault;

  SavedCardDto({
    required this.id,
    required this.cardName,
    required this.cardholderName,
    required this.maskedCardNumber,
    required this.expiryMonth,
    required this.expiryYear,
    required this.isDefault,
  });

  factory SavedCardDto.fromJson(Map<String, dynamic> j) {
    return SavedCardDto(
      id: j['id'] ?? 0,
      cardName: j['cardName'] ?? '',
      cardholderName: j['cardholderName'] ?? '',
      maskedCardNumber: j['maskedCardNumber'] ?? '',
      expiryMonth: j['expiryMonth'] ?? 1,
      expiryYear: j['expiryYear'] ?? 2026,
      isDefault: j['isDefault'] ?? false,
    );
  }
}
