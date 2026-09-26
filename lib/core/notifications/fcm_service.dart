import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_router.dart';
import '../../features/notifications/presentation/sync/notifications_sync_bus.dart';

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _notificationChannel =
      AndroidNotificationChannel(
        'student_notifications',
        'Student Notifications',
        description: 'Notifications for EELU Student Planner.',
        importance: Importance.max,
      );

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  String? _lastStudentId;

  bool _initialized = false;

  bool _isSigningOut = false;
  int _syncGeneration = 0;

  // FCM can deliver the initial message before runApp() mounts the router.
  // Keep its destination and consume it after the first frame.
  String? _pendingRoute;
  String? _pendingNotificationId;
  String? _lastHandledNotificationId;

  // Prevent duplicate FCM syncs for the same user/token.
  bool _syncInProgress = false;
  String? _lastSyncedStudentId;
  String? _lastSyncedToken;

  Future<bool> _notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        final token = await _messaging.getToken();

        if (user != null && token != null && token.trim().isNotEmpty) {
          await Supabase.instance.client
              .from('student_devices')
              .delete()
              .eq('student_id', user.id)
              .eq('fcm_token', token.trim());
        }

        await _localNotifications.cancelAll();
        _clearSyncCache();

        log(
          'Notifications disabled: local notifications cancelled and FCM device token removed.',
          name: 'FCM',
        );
      } catch (error, stackTrace) {
        log(
          'Failed to disable notifications completely: $error',
          name: 'FCM',
          stackTrace: stackTrace,
        );
      }
      return;
    }

    try {
      final notificationsEnabled = await _notificationsEnabled();
      final settings = notificationsEnabled
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : null;

      log(
        'Notification permission after enabling: ${settings?.authorizationStatus}',
        name: 'FCM',
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && !_isSigningOut) {
        await _syncForUser(user, force: true);
      }
    } catch (error, stackTrace) {
      log(
        'Failed to enable notifications: $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      log(
        'Notification permission: ${settings.authorizationStatus}',
        name: 'FCM',
      );

      await _initializeLocalNotifications();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        log(
          'FOREGROUND FCM RECEIVED | '
          'messageId=${message.messageId} | '
          'title=${message.notification?.title ?? message.data['title']} | '
          'body=${message.notification?.body ?? message.data['body']} | '
          'data=${message.data}',
          name: 'FCM',
        );

        if (!await _notificationsEnabled()) {
          log(
            'Ignoring foreground notification because notifications are disabled.',
            name: 'FCM',
          );
          NotificationsSyncBus.instance.notifyChanged();
          return;
        }

        try {
          await _showForegroundNotification(message);
          log(
            'FOREGROUND LOCAL NOTIFICATION DISPLAYED | messageId=${message.messageId}',
            name: 'FCM',
          );
        } catch (error, stackTrace) {
          log(
            'FOREGROUND LOCAL NOTIFICATION FAILED | messageId=${message.messageId} | error=$error',
            name: 'FCM',
            stackTrace: stackTrace,
          );
        }

        // The notification row is already inserted by the Dashboard/Edge
        // Function. Refresh every in-app notification consumer immediately,
        // so Home's unread badge and an already-open Notifications screen
        // update without requiring a restart/manual refresh.
        NotificationsSyncBus.instance.notifyChanged();
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log(
          'FCM NOTIFICATION OPENED | messageId=${message.messageId} | data=${message.data}',
          name: 'FCM',
        );
        _handleNotificationTap(
          route: message.data['route']?.toString(),
          notificationId: message.data['notification_id']?.toString(),
        );
      });

      final initialMessage = await _messaging.getInitialMessage();

      log(
        'FCM INITIAL MESSAGE CHECK | found=${initialMessage != null}',
        name: 'FCM',
      );

      if (initialMessage != null) {
        log(
          'App opened from notification: ${initialMessage.messageId}',
          name: 'FCM',
        );
        await _handleNotificationTap(
          route: initialMessage.data['route']?.toString(),
          notificationId: initialMessage.data['notification_id']?.toString(),
        );
      }

      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) async {
            switch (data.event) {
              case AuthChangeEvent.signedIn:
                if (_pendingNotificationId != null &&
                    _pendingNotificationId!.isNotEmpty) {
                  final pendingId = _pendingNotificationId!;
                  _pendingNotificationId = null;
                  await _markNotificationAsRead(pendingId);
                }

                // The normal login flow calls resetLogoutProtection().
                // Do not start another sync here.
                log(
                  'Supabase signed in. Waiting for Auth flow to start '
                  'the FCM sync.',
                  name: 'FCM',
                );
                break;

              case AuthChangeEvent.tokenRefreshed:
              case AuthChangeEvent.userUpdated:
                if (_isSigningOut) {
                  log(
                    'Skipping FCM sync because logout is in progress.',
                    name: 'FCM',
                  );
                  return;
                }

                final user =
                    data.session?.user ??
                    Supabase.instance.client.auth.currentUser;

                if (user != null) {
                  await _syncForUser(user);
                }
                break;

              case AuthChangeEvent.signedOut:
                _syncGeneration++;

                _clearSyncCache();

                if (!_isSigningOut) {
                  await _removeLastStudentDevice();
                }
                break;

              default:
                break;
            }
          });

      _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        log('FCM token refreshed', name: 'FCM');

        if (_isSigningOut) {
          log(
            'Skipping refreshed FCM token because logout is in progress.',
            name: 'FCM',
          );
          return;
        }

        final user = Supabase.instance.client.auth.currentUser;

        if (user == null) {
          log(
            'Skipping refreshed FCM token because no user '
            'is authenticated.',
            name: 'FCM',
          );
          return;
        }

        await _syncForUser(user, token: newToken, force: true);
      });

      final user = Supabase.instance.client.auth.currentUser;

      if (user != null && !_isSigningOut) {
        await _syncForUser(user);
        await _showUnreadNotificationsFallback(user.id);
      }
    } catch (error, stackTrace) {
      log(
        'FCM initialization failed: $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_notification');

    const settings = InitializationSettings(android: androidSettings);

    log('Initializing Android local notifications.', name: 'FCM');

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        log('Local notification opened: ${response.payload}', name: 'FCM');

        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) {
          return;
        }

        String? route;
        String? notificationId;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            route = decoded['route']?.toString();
            notificationId = decoded['notification_id']?.toString();
          }
        } catch (_) {
          route = payload;
        }

        await _handleNotificationTap(
          route: route,
          notificationId: notificationId,
        );
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_notificationChannel);

    final permissionGranted = await androidPlugin
        ?.requestNotificationsPermission();

    log(
      'Android notification permission request result: $permissionGranted',
      name: 'FCM',
    );
  }

  Future<void> _handleNotificationTap({
    String? route,
    String? notificationId,
  }) async {
    final id = notificationId?.trim();

    if (id != null && id.isNotEmpty && id == _lastHandledNotificationId) {
      return;
    }

    if (id != null && id.isNotEmpty) {
      _lastHandledNotificationId = id;
      await _markNotificationAsRead(id);
    }

    _navigateToNotificationRoute(route);
    NotificationsSyncBus.instance.notifyChanged();
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      _pendingNotificationId = notificationId;
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await Supabase.instance.client
          .from('student_notifications')
          .update({'is_read': true, 'read_at': now, 'updated_at': now})
          .eq('student_id', userId)
          .eq('notification_id', notificationId)
          .eq('is_deleted', false);

      log('Notification marked as read: $notificationId', name: 'FCM');
    } catch (error, stackTrace) {
      log(
        'Failed to mark notification as read: $notificationId | $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    }
  }

  String _normalizeNotificationRoute(String? route) {
    final value = route?.trim();

    if (value == null || value.isEmpty) {
      return '/notifications';
    }

    if (value == '/assignments') {
      return '/tasks';
    }

    const allowedRoutes = {
      '/notifications',
      '/tasks',
      '/quizzes',
      '/exams',
      '/lectures',
      '/profile',
      '/academic-information',
      '/course-details',
      '/task-details',
      '/lecture-progress',
    };

    if (allowedRoutes.contains(value)) {
      return value;
    }

    return '/notifications';
  }

  void _navigateToNotificationRoute(String? route) {
    final destination = _normalizeNotificationRoute(route);

    // If the router is not mounted yet (getInitialMessage during startup),
    // keep the route until main() runs the first post-frame callback.
    if (AppRouter.router.routerDelegate.navigatorKey.currentState == null) {
      _pendingRoute = destination;
      return;
    }

    AppRouter.router.go(destination);
  }

  Future<void> consumePendingNavigation() async {
    final route = _pendingRoute;
    final notificationId = _pendingNotificationId;
    _pendingRoute = null;
    _pendingNotificationId = null;

    if (notificationId != null && notificationId.isNotEmpty) {
      await _markNotificationAsRead(notificationId);
    }

    if (route == null) {
      return;
    }

    AppRouter.router.go(route);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    final title = notification?.title ?? message.data['title']?.toString();

    final body = notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.trim().isEmpty) &&
        (body == null || body.trim().isEmpty)) {
      return;
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      2147483647,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'student_notifications',
        'Student Notifications',
        channelDescription: 'Notifications for EELU Student Planner.',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
    );

    log(
      'Showing foreground local notification | id=$notificationId | title=$title | body=$body | route=${message.data['route']}',
      name: 'FCM',
    );

    final route = message.data['route']?.toString();
    final notificationIdFromData = message.data['notification_id']?.toString();

    final payload = jsonEncode({
      'route': route,
      'notification_id': notificationIdFromData,
    });

    await _localNotifications.show(
      id: notificationId,
      title: title ?? 'EELU Student Planner',
      body: body ?? '',
      notificationDetails: details,
      payload: payload,
    );

    final studentId = Supabase.instance.client.auth.currentUser?.id;
    if (studentId != null &&
        notificationIdFromData != null &&
        notificationIdFromData.trim().isNotEmpty) {
      await _rememberFallbackShownId(studentId, notificationIdFromData);
    }
  }

  static const String _fallbackShownIdsPrefix =
      'fcm_fallback_shown_notification_ids:';

  Future<void> _rememberFallbackShownId(String studentId, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_fallbackShownIdsPrefix$studentId';
      final ids = (prefs.getStringList(key) ?? const <String>[]).toSet()
        ..add(id);
      final saved = ids.toList()..sort();
      if (saved.length > 100) {
        saved.removeRange(0, saved.length - 100);
      }
      await prefs.setStringList(key, saved);
    } catch (error) {
      log('Failed to remember displayed notification: $error', name: 'FCM');
    }
  }

  Future<void> _showUnreadNotificationsFallback(String studentId) async {
    if (!await _notificationsEnabled()) {
      log(
        'Skipping unread notification fallback because notifications are disabled.',
        name: 'FCM',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_fallbackShownIdsPrefix$studentId';
      final stored = prefs.getStringList(key) ?? const <String>[];
      final shownIds = stored.toSet();

      final response = await Supabase.instance.client
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
              route
            )
          ''')
          .eq('student_id', studentId)
          .eq('is_read', false)
          .eq('is_deleted', false)
          .limit(20);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      rows.sort((a, b) {
        final aNotification = Map<String, dynamic>.from(
          (a['notifications'] as Map?) ?? const {},
        );
        final bNotification = Map<String, dynamic>.from(
          (b['notifications'] as Map?) ?? const {},
        );
        final aDate =
            DateTime.tryParse(aNotification['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse(bNotification['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (rows.isEmpty) return;

      final candidates = stored.isEmpty
          ? rows.take(1).toList()
          : rows
                .where(
                  (row) => !shownIds.contains(
                    row['notification_id']?.toString() ?? '',
                  ),
                )
                .take(5)
                .toList();

      if (candidates.isEmpty) return;

      final isArabic =
          ui.PlatformDispatcher.instance.locale.languageCode == 'ar';

      for (final row in candidates) {
        final notification = Map<String, dynamic>.from(
          (row['notifications'] as Map?) ?? const {},
        );
        final id = row['notification_id']?.toString() ?? '';
        final arabicTitle = notification['title_ar']?.toString();
        final arabicBody = notification['body_ar']?.toString();
        final title =
            isArabic && arabicTitle != null && arabicTitle.trim().isNotEmpty
            ? arabicTitle
            : notification['title']?.toString();
        final body =
            isArabic && arabicBody != null && arabicBody.trim().isNotEmpty
            ? arabicBody
            : notification['body']?.toString();

        if ((title == null || title.trim().isEmpty) &&
            (body == null || body.trim().isEmpty)) {
          if (id.isNotEmpty) shownIds.add(id);
          continue;
        }

        await _localNotifications.show(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: title ?? 'EELU Student Planner',
          body: body ?? '',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'student_notifications',
              'Student Notifications',
              channelDescription: 'Notifications for EELU Student Planner.',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
          payload: notification['route']?.toString(),
        );

        if (id.isNotEmpty) shownIds.add(id);
      }

      final saved = shownIds.toList()..sort();
      if (saved.length > 100) {
        saved.removeRange(0, saved.length - 100);
      }
      await prefs.setStringList(key, saved);

      log(
        'Displayed ${candidates.length} unread notification(s) in the Android tray using the startup fallback.',
        name: 'FCM',
      );
    } catch (error, stackTrace) {
      log(
        'Unread notification startup fallback failed: $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncForUser(
    User user, {
    String? token,
    bool force = false,
  }) async {
    if (!await _notificationsEnabled()) {
      log(
        'Skipping FCM sync because notifications are disabled in app settings.',
        name: 'FCM',
      );
      return;
    }

    if (_isSigningOut) {
      log('Skipping FCM sync because logout is in progress.', name: 'FCM');
      return;
    }

    final generationAtStart = _syncGeneration;

    try {
      if (!_isSyncStillValid(user.id, generationAtStart)) {
        log(
          'Skipping FCM sync because authentication state changed.',
          name: 'FCM',
        );
        return;
      }

      /*
       * If another sync is already running, do not start another one.
       *
       * This is especially important during Google login because
       * Supabase can emit more than one auth event around login.
       */
      if (_syncInProgress) {
        log(
          'Skipping duplicate FCM sync because another sync '
          'is already in progress.',
          name: 'FCM',
        );
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!_isSyncStillValid(user.id, generationAtStart)) {
        log(
          'Skipping FCM sync because authentication state changed.',
          name: 'FCM',
        );
        return;
      }

      final role = profile?['role']?.toString();

      if (role != 'student') {
        log(
          'Skipping FCM token sync because user role is '
          '${role ?? 'unknown'}.',
          name: 'FCM',
        );
        return;
      }

      final fcmToken = token ?? await _messaging.getToken();

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        log('FCM token is unavailable.', name: 'FCM');
        return;
      }

      final normalizedToken = fcmToken.trim();

      if (!_isSyncStillValid(user.id, generationAtStart)) {
        log(
          'Skipping FCM sync because authentication state changed.',
          name: 'FCM',
        );
        return;
      }

      /*
       * If this exact student + token was already registered,
       * there is nothing new to send to Supabase.
       *
       * A forced sync is used only when Firebase reports that
       * the FCM token itself changed.
       */
      if (!force &&
          _lastSyncedStudentId == user.id &&
          _lastSyncedToken == normalizedToken) {
        _lastStudentId = user.id;

        log(
          'Skipping duplicate FCM registration. '
          'Token is already synced for this student.',
          name: 'FCM',
        );
        return;
      }

      _syncInProgress = true;

      try {
        final result = await Supabase.instance.client.rpc(
          'register_student_device',
          params: {'p_fcm_token': normalizedToken, 'p_platform': 'android'},
        );

        if (!_isSyncStillValid(user.id, generationAtStart)) {
          log(
            'FCM registration completed after authentication '
            'changed. Ignoring result.',
            name: 'FCM',
          );
          return;
        }

        if (_isSigningOut) {
          log(
            'FCM registration completed while logout was '
            'in progress. Ignoring result.',
            name: 'FCM',
          );
          return;
        }

        _lastStudentId = user.id;
        _lastSyncedStudentId = user.id;
        _lastSyncedToken = normalizedToken;

        log(
          'FCM token saved successfully for student: ${user.id}',
          name: 'FCM',
        );

        log('Device registration result: $result', name: 'FCM');
      } finally {
        _syncInProgress = false;
      }
    } catch (error, stackTrace) {
      _syncInProgress = false;

      if (!_isSyncStillValid(user.id, generationAtStart)) {
        log(
          'Ignoring FCM error because authentication state changed.',
          name: 'FCM',
        );
        return;
      }

      if (_isSigningOut) {
        log('Ignoring FCM error because logout is in progress.', name: 'FCM');
        return;
      }

      log(
        'Failed to save FCM token: $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    }
  }

  bool _isSyncStillValid(String userId, int generationAtStart) {
    if (_isSigningOut) return false;

    if (generationAtStart != _syncGeneration) {
      return false;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return false;

    if (currentUser.id != userId) {
      return false;
    }

    return true;
  }

  Future<void> removeCurrentStudentDeviceBeforeSignOut() async {
    _isSigningOut = true;
    _syncGeneration++;

    log('FCM logout protection enabled.', name: 'FCM');

    await _removeLastStudentDevice();

    _clearSyncCache();
  }

  Future<void> _removeLastStudentDevice() async {
    final studentId = _lastStudentId;

    if (studentId == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('student_devices')
          .delete()
          .eq('student_id', studentId);

      log(
        'Removed FCM devices for signed-out student: $studentId',
        name: 'FCM',
      );
    } catch (error, stackTrace) {
      log(
        'Failed to remove FCM device on sign out: $error',
        name: 'FCM',
        stackTrace: stackTrace,
      );
    } finally {
      _lastStudentId = null;
    }
  }

  Future<void> resetLogoutProtection() async {
    _isSigningOut = false;

    /*
     * A new login starts a new authentication generation.
     * This makes any old in-flight operation invalid.
     */
    _syncGeneration++;

    log('FCM logout protection disabled.', name: 'FCM');

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      log(
        'No authenticated user found after login. '
        'FCM sync will be skipped.',
        name: 'FCM',
      );
      return;
    }

    /*
     * Single normal-login FCM sync.
     *
     * The AuthChangeEvent.signedIn listener intentionally
     * does not call _syncForUser().
     */
    await _syncForUser(user);
    await _showUnreadNotificationsFallback(user.id);
  }

  void _clearSyncCache() {
    _lastSyncedStudentId = null;
    _lastSyncedToken = null;
    _syncInProgress = false;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();

    _authSubscription = null;
    _tokenSubscription = null;

    _initialized = false;

    _syncGeneration++;

    _lastStudentId = null;
    _pendingRoute = null;

    _clearSyncCache();

    _isSigningOut = false;
  }
}
