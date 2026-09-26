import '../../../../core/services/supabase_service.dart';
import '../models/notification_model.dart';

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  Future<List<NotificationModel>> getNotifications() async {
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    final response = await _supabase.client
        .from('student_notifications')
        .select('''
          notification_id,
          is_read,
          is_deleted,
          notifications (
            id,
            title,
            body,
            title_ar,
            body_ar,
            created_at,
            type,
            route
          )
        ''')
        .eq('student_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);

      final notification = Map<String, dynamic>.from(
        (map['notifications'] as Map?) ?? {},
      );

      notification['is_read'] = map['is_read'] == true;

      return NotificationModel.fromMap(notification);
    }).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.client
        .from('student_notifications')
        .update({'is_read': true, 'read_at': now, 'updated_at': now})
        .eq('student_id', userId)
        .eq('notification_id', notificationId)
        .eq('is_deleted', false);
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.client
        .from('student_notifications')
        .update({'is_read': true, 'read_at': now, 'updated_at': now})
        .eq('student_id', userId)
        .eq('is_read', false)
        .eq('is_deleted', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.client
        .from('student_notifications')
        .update({'is_deleted': true, 'deleted_at': now, 'updated_at': now})
        .eq('student_id', userId)
        .eq('notification_id', notificationId)
        .eq('is_deleted', false);
  }

  Future<void> deleteAllNotifications() async {
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.client
        .from('student_notifications')
        .update({'is_deleted': true, 'deleted_at': now, 'updated_at': now})
        .eq('student_id', userId)
        .eq('is_deleted', false);
  }
}
