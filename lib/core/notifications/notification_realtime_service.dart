import 'dart:async';
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'fcm_service.dart';
import '../../features/notifications/presentation/sync/notifications_sync_bus.dart';

/// Keeps the in-app notification state synchronized with the server.
///
/// FCM is still responsible for device push delivery. Supabase Realtime is
/// only used to refresh the Notification Center/Home unread state immediately
/// when the worker creates or updates the student's notification row.
class NotificationRealtimeService {
  NotificationRealtimeService._();

  static final NotificationRealtimeService instance =
      NotificationRealtimeService._();

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;
  String? _subscribedStudentId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final auth = Supabase.instance.client.auth;

    _authSubscription = auth.onAuthStateChange.listen((data) async {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          final user = data.session?.user ?? auth.currentUser;
          if (user != null) {
            await subscribeForStudent(user.id);
          }
          break;

        case AuthChangeEvent.signedOut:
          await unsubscribe();
          break;

        default:
          break;
      }
    });

    final user = auth.currentUser;
    if (user != null) {
      await subscribeForStudent(user.id);
    }
  }

  Future<void> subscribeForStudent(String studentId) async {
    if (studentId.trim().isEmpty) return;

    if (_subscribedStudentId == studentId && _channel != null) {
      return;
    }

    await unsubscribe();

    final client = Supabase.instance.client;

    final channel = client.channel(
      'student-notifications:$studentId',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'student_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) {
            log(
              'Student notification realtime event: '
              '${payload.eventType} | student=$studentId',
              name: 'NotificationRealtime',
            );

            // The Notification Center will re-query the joined notification
            // data. Do not try to reconstruct the notification from the
            // Realtime payload because it only contains student_notifications.
            NotificationsSyncBus.instance.notifyChanged();
          },
        )
        .subscribe();

    _channel = channel;
    _subscribedStudentId = studentId;
  }

  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    _subscribedStudentId = null;

    if (channel == null) return;

    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (error, stackTrace) {
      log(
        'Failed to remove notification realtime channel: $error',
        name: 'NotificationRealtime',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await unsubscribe();
    _initialized = false;
  }
}
