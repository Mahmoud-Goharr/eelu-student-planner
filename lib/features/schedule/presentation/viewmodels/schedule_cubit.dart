import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';

import '../../../../core/notifications/local_notification_scheduler.dart';
import '../../../../core/utils/egypt_time.dart';

import '../../data/models/schedule_model.dart';
import '../../domain/repositories/schedule_repository.dart';
import 'schedule_state.dart';

class ScheduleCubit extends Cubit<ScheduleState> {
  ScheduleCubit(this._repository) : super(const ScheduleState()) {
    _profileSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) watchSchedule();
    });
  }

  final ScheduleRepository _repository;
  StreamSubscription<List<ScheduleModel>>? _subscription;
  StreamSubscription<void>? _profileSubscription;

  Future<void> getSchedule() async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <ScheduleModel>[]
        : await PlannerCache.instance.loadSchedule(userId);

    if (isClosed) return;

    emit(
      state.copyWith(
        status: ScheduleStatus.loading,
        errorMessage: null,
      ),
    );

    final online = await NetworkProbe.isOnline();
    if (isClosed) return;

    if (!online) {
      if (cached.isNotEmpty) {
        emit(
          state.copyWith(
            status: ScheduleStatus.success,
            schedule: _sortSchedule(cached),
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ScheduleStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    try {
      final schedule = await _repository.getSchedule();
      if (isClosed) return;
      await _scheduleLectureReminders(schedule);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ScheduleStatus.success,
          schedule: _sortSchedule(schedule),
          errorMessage: null,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      if (cached.isNotEmpty) {
        emit(
          state.copyWith(
            status: ScheduleStatus.success,
            schedule: _sortSchedule(cached),
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ScheduleStatus.failure,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> watchSchedule() async {
    await _subscription?.cancel();
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <ScheduleModel>[]
        : await PlannerCache.instance.loadSchedule(userId);

    if (isClosed) return;

    emit(
      state.copyWith(
        status: ScheduleStatus.loading,
        errorMessage: null,
      ),
    );

    final online = await NetworkProbe.isOnline();
    if (isClosed) return;

    if (!online) {
      if (cached.isNotEmpty) {
        emit(
          state.copyWith(
            status: ScheduleStatus.success,
            schedule: _sortSchedule(cached),
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ScheduleStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    _subscription = _repository.watchSchedule().listen(
      (schedule) async {
        if (isClosed) return;
        await _scheduleLectureReminders(schedule);
        if (isClosed) return;
        emit(
          state.copyWith(
            status: ScheduleStatus.success,
            schedule: _sortSchedule(schedule),
            errorMessage: null,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (isClosed) return;
        if (state.schedule.isNotEmpty) {
          emit(
            state.copyWith(
              status: ScheduleStatus.success,
              errorMessage: 'offline',
            ),
          );
        } else if (cached.isNotEmpty) {
          emit(
            state.copyWith(
              status: ScheduleStatus.success,
              schedule: _sortSchedule(cached),
              errorMessage: 'offline',
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: ScheduleStatus.failure,
              errorMessage: error.toString(),
            ),
          );
        }
      },
    );
  }

  List<ScheduleModel> _sortSchedule(List<ScheduleModel> items) {
    final result = [...items];
    result.sort((a, b) {
      final day = _dayOrder(a.day).compareTo(_dayOrder(b.day));
      if (day != 0) return day;
      return _timeMinutes(a.startTime).compareTo(_timeMinutes(b.startTime));
    });
    return result;
  }

  int _dayOrder(String day) => switch (day.toLowerCase()) {
        'saturday' => 1,
        'sunday' => 2,
        'monday' => 3,
        'tuesday' => 4,
        'wednesday' => 5,
        'thursday' => 6,
        'friday' => 7,
        _ => 99,
      };

  int _timeMinutes(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  Future<void> _scheduleLectureReminders(List<ScheduleModel> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') == false) {
      await LocalNotificationScheduler.instance.cancelPlannerReminders();
      return;
    }
    final reminders = <PlannerReminder>[];
    final now = EgyptTime.now();

    for (final entry in schedule) {
      final day = _databaseDay(entry.day);
      if (day == null) continue;

      var date = EgyptTime.dateOnly(entry.scheduleStartDate);

      while (date.weekday != day) {
        date = _addCalendarDays(date, 1);
      }

      while (!date.isAfter(now)) {
        final end = _combine(date, entry.endTime);
        if (end.isAfter(now)) break;
        date = _addCalendarDays(date, 7);
      }

      for (var i = 0; i < 8; i++) {
        final start = _combine(date, entry.startTime);
        if (start.isAfter(now)) {
          reminders.add(
            PlannerReminder(
              id: 'lecture:${entry.id}:${date.toIso8601String()}',
              titleEn: 'Lecture: ${entry.courseName}',
              titleAr: 'محاضرة: ${entry.courseName}',
              bodyEn: '${entry.startTime} - ${entry.endTime} • ${entry.instructor}',
              bodyAr: '${_time(entry.startTime)} - ${_time(entry.endTime)} • ${entry.instructor}',
              eventAt: start,
              // Lecture reminder = start of the SAME calendar day.
              notificationAt: EgyptTime.dateOnly(start),
            ),
          );
        }
        date = _addCalendarDays(date, 7);
      }
    }

    await LocalNotificationScheduler.instance.replaceReminders(
      reminders,
      idStart: LocalNotificationScheduler.plannerLectureIdStart,
    );
  }

  tz.TZDateTime _addCalendarDays(DateTime value, int days) {
    final base = EgyptTime.dateOnly(value);
    return tz.TZDateTime(
      tz.local,
      base.year,
      base.month,
      base.day + days,
    );
  }

  int? _databaseDay(String day) {
    return switch (day.toLowerCase()) {
      'saturday' => DateTime.saturday,
      'sunday' => DateTime.sunday,
      'monday' => DateTime.monday,
      'tuesday' => DateTime.tuesday,
      'wednesday' => DateTime.wednesday,
      'thursday' => DateTime.thursday,
      'friday' => DateTime.friday,
      _ => null,
    };
  }

  DateTime _combine(DateTime date, String value) =>
      EgyptTime.at(date, value);

  String _time(String value) {
    final parts = value.split(':');
    final hour24 = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
