class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['notification_id'] ?? json['notificationId'] ?? json['id'] ?? 0;
    final int id = rawId is String ? (int.tryParse(rawId) ?? 0) : (rawId as num).toInt();

    final rawIsRead = json['is_read'] ?? json['isRead'] ?? false;
    final bool isRead = rawIsRead == true || rawIsRead == 1 || rawIsRead == 'true' || rawIsRead == '1';

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final DateTime createdAt = rawCreatedAt != null
        ? DateTime.parse(rawCreatedAt.toString())
        : DateTime.now();

    return NotificationModel(
      id: id,
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? json['body'] ?? '',
      type: (json['type'] ?? 'info').toString().trim().toLowerCase(),
      isRead: isRead,
      createdAt: createdAt,
    );
  }
}
