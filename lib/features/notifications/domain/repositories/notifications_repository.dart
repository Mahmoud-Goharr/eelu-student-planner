import '../../data/models/notification_model.dart';

abstract class NotificationsRepository {
  Future<List<NotificationModel>> getNotifications();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  Future<void> deleteNotification(String notificationId);

  Future<void> deleteAllNotifications();
}