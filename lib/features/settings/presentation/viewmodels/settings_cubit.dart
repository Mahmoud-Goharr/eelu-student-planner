import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/notifications/local_notification_scheduler.dart';
import '../../../../core/notifications/fcm_service.dart';

import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState()) {
    _load();
  }

  static const _key = 'notifications_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (isClosed) return;
    emit(state.copyWith(notificationsEnabled: prefs.getBool(_key) ?? true));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);

    if (!enabled) {
      await LocalNotificationScheduler.instance.cancelPlannerReminders();
    }

    await FcmService.instance.setNotificationsEnabled(enabled);

    if (!isClosed) {
      emit(state.copyWith(notificationsEnabled: enabled));
    }
  }
}
