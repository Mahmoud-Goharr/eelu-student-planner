enum NotificationType { task, quiz, exam, lecture, system }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.titleAr,
    this.bodyAr,
    this.type = NotificationType.system,
    this.isRead = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final String? titleAr;
  final String? bodyAr;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final String? route;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final type = NotificationType.values
        .where((v) => v.name == map['type'])
        .firstOrNull;

    return NotificationModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      titleAr: map['title_ar']?.toString(),
      bodyAr: map['body_ar']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      type: type ?? NotificationType.system,
      isRead: map['is_read'] == true,
      route: map['route']?.toString(),
    );
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      titleAr: titleAr,
      bodyAr: bodyAr,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
      route: route,
    );
  }
}
