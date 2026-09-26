import '../../data/models/notification_model.dart';

enum NotificationsStatus { initial, loading, success, failure }

enum NotificationsFilter { all, unread }

class NotificationsState {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.filter = NotificationsFilter.all,
    this.errorMessage,
  });
  final NotificationsStatus status;
  final List<NotificationModel> notifications;
  final NotificationsFilter filter;
  final String? errorMessage;
  int get unreadCount => notifications.where((n) => !n.isRead).length;
  List<NotificationModel> get visibleNotifications =>
      filter == NotificationsFilter.unread
      ? notifications.where((n) => !n.isRead).toList()
      : notifications;
  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationModel>? notifications,
    NotificationsFilter? filter,
    String? errorMessage,
  }) => NotificationsState(
    status: status ?? this.status,
    notifications: notifications ?? this.notifications,
    filter: filter ?? this.filter,
    errorMessage: errorMessage,
  );
}
