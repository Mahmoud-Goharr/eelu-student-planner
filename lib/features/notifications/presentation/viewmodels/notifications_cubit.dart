import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';

import '../../data/models/notification_model.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../sync/notifications_sync_bus.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repository) : super(const NotificationsState());

  final NotificationsRepository _repository;

  Future<void> load() async {
    if (isClosed) {
      return;
    }

    emit(state.copyWith(status: NotificationsStatus.loading));

    try {
      final result = await _repository.getNotifications();

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          status: NotificationsStatus.success,
          notifications: result,
          errorMessage: null,
        ),
      );
    } catch (error) {
      debugPrint('Notifications load failed: $error');

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  void setFilter(NotificationsFilter filter) {
    if (isClosed) {
      return;
    }

    emit(state.copyWith(filter: filter));
  }

  Future<void> markRead(String id) async {
    if (isClosed) {
      return;
    }

    // Update UI immediately.
    final updated = state.notifications
        .map(
          (notification) => notification.id == id
              ? notification.copyWith(isRead: true)
              : notification,
        )
        .toList();

    _replace(updated);

    try {
      // Persist read state in Supabase.
      await _repository.markAsRead(id);

      // Tell other parts of the app that notification state changed.
      NotificationsSyncBus.instance.notifyChanged();
    } catch (error) {
      debugPrint('Mark notification as read failed: $error');

      await load();
    }
  }

  Future<void> markAllRead() async {
    if (isClosed) {
      return;
    }

    // Update UI immediately.
    final updated = state.notifications
        .map((notification) => notification.copyWith(isRead: true))
        .toList();

    _replace(updated);

    try {
      // Persist all read states in Supabase.
      await _repository.markAllAsRead();

      // Notify Home/Header so the red unread badge disappears.
      NotificationsSyncBus.instance.notifyChanged();
    } catch (error) {
      debugPrint('Mark all notifications as read failed: $error');

      await load();
    }
  }

  Future<void> delete(String id) async {
    if (isClosed) {
      return;
    }

    final oldNotifications = state.notifications;

    // Remove immediately from UI.
    _replace(
      oldNotifications.where((notification) => notification.id != id).toList(),
    );

    try {
      // Soft-delete for this student in Supabase.
      await _repository.deleteNotification(id);

      NotificationsSyncBus.instance.notifyChanged();
    } catch (error) {
      debugPrint('Delete notification failed: $error');

      await load();
    }
  }

  Future<void> deleteAll() async {
    if (isClosed) {
      return;
    }

    // Clear UI immediately.
    _replace(const []);

    try {
      // Soft-delete all notifications for this student.
      await _repository.deleteAllNotifications();

      NotificationsSyncBus.instance.notifyChanged();
    } catch (error) {
      debugPrint('Delete all notifications failed: $error');

      await load();
    }
  }

  void _replace(List<NotificationModel> notifications) {
    if (isClosed) {
      return;
    }

    emit(
      state.copyWith(
        notifications: notifications,
        status: NotificationsStatus.success,
        errorMessage: null,
      ),
    );
  }
}
