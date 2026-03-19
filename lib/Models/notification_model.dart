class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAtUtc;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdAtUtc,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? '',
      referenceId: json['referenceId'],
      isRead: json['isRead'] ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}
