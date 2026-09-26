import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dataSource);

  final NotificationsRemoteDataSource _dataSource;

  @override
  Future<List<NotificationModel>> getNotifications() {
    return _dataSource.getNotifications();
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _dataSource.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() {
    return _dataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _dataSource.deleteNotification(notificationId);
  }

  @override
  Future<void> deleteAllNotifications() {
    return _dataSource.deleteAllNotifications();
  }
}
