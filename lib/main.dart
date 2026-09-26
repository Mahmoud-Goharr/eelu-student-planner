import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/supabase_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_cubit.dart';
import 'core/localization/locale_state.dart';
import 'core/router/app_router.dart' show AppRouter;
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/theme/theme_state.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/local_notification_scheduler.dart';

import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/viewmodels/auth_cubit.dart';
import 'features/splash/presentation/viewmodels/splash_cubit.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FCM] BACKGROUND FCM RECEIVED | messageId=${message.messageId} | '
    'title=${message.notification?.title ?? message.data['title']} | '
    'body=${message.notification?.body ?? message.data['body']} | '
    'data=${message.data}',
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled =
      prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled) {
    debugPrint(
      '[FCM] Background notification ignored because notifications are disabled.',
    );
    return;
  }

  // If the dashboard sends a data-only FCM message, Android will not show a
  // notification automatically. Show it from the background isolate.
  // Messages that already contain an FCM notification payload are left to
  // Android, preventing duplicate notifications.
  if (message.notification == null) {
    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();

    if ((title != null && title.trim().isNotEmpty) ||
        (body != null && body.trim().isNotEmpty)) {
      final plugin = FlutterLocalNotificationsPlugin();
      const channel = AndroidNotificationChannel(
        'student_notifications',
        'Student Notifications',
        description: 'Notifications for EELU Student Planner.',
        importance: Importance.max,
      );

      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );

      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(channel);

      final payload = jsonEncode({
        'route': message.data['route']?.toString(),
        'notification_id': message.data['notification_id']?.toString(),
      });

      await plugin.show(
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
        payload: payload,
      );
    }
  }

  debugPrint('[FCM] BACKGROUND HANDLER FINISHED | messageId=${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------
  // Firebase
  // ------------------------------------------------------------

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[FCM] Background message handler registered.');
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ------------------------------------------------------------
  // Shared Preferences
  // ------------------------------------------------------------

  final preferences = await SharedPreferences.getInstance();

  // ------------------------------------------------------------
  // Supabase
  // IMPORTANT: FCM listens to Supabase auth state and may access
  // Supabase.instance, so Supabase MUST be initialized first.
  // ------------------------------------------------------------

  await Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.publishableKey,
  );

  // ------------------------------------------------------------
  // FCM
  // ------------------------------------------------------------

  try {
    await FcmService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('FCM initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ------------------------------------------------------------
  // Local notifications
  //
  // IMPORTANT:
  // A notification initialization problem must never prevent
  // the application itself from starting.
  // ------------------------------------------------------------

  try {
    await LocalNotificationScheduler.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Local notifications initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ------------------------------------------------------------
  // Start application
  // ------------------------------------------------------------

  runApp(EeluStudentApp(preferences: preferences));

  // getInitialMessage() can run before MaterialApp.router is mounted.
  // Consume a stored notification destination after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmService.instance.consumePendingNavigation();
  });
}

class EeluStudentApp extends StatelessWidget {
  const EeluStudentApp({super.key, this.preferences});

  final SharedPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    if (preferences == null) {
      return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          final loadedPreferences = snapshot.data;

          if (loadedPreferences == null) {
            return const SizedBox.shrink();
          }

          return _buildApp(context, loadedPreferences);
        },
      );
    }

    return _buildApp(context, preferences!);
  }

  Widget _buildApp(BuildContext context, SharedPreferences preferences) {
    final service = SupabaseService();

    final repository = AuthRepositoryImpl(AuthRemoteDataSource(service));

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit(preferences)),
        BlocProvider(create: (_) => LocaleCubit(preferences)),
        BlocProvider(create: (_) => AuthCubit(repository)..restoreSession()),
        BlocProvider(create: (_) => SplashCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<LocaleCubit, LocaleState>(
            builder: (context, localeState) {
              return MaterialApp.router(
                debugShowCheckedModeBanner: false,
                title: AppConstants.appName,

                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeState.themeMode,

                locale: localeState.locale,

                supportedLocales: AppLocalizations.supportedLocales,

                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],

                routerConfig: AppRouter.router,
              );
            },
          );
        },
      ),
    );
  }
}
