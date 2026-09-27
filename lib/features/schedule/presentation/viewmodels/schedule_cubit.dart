import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';

import '../../../../core/utils/egypt_time.dart';

import '../../data/models/schedule_model.dart';
import '../../data/models/schedule_pause_model.dart';
import '../../domain/repositories/schedule_repository.dart';
import 'schedule_state.dart';

class ScheduleCubit extends Cubit<ScheduleState> {
  ScheduleCubit(this._repository) : super(const ScheduleState()) {
    _profileSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) {
        _lastScheduleSignature = null;
        watchSchedule();
      }
    });
  }

  final ScheduleRepository _repository;

  StreamSubscription<ScheduleBundle>? _subscription;
  StreamSubscription<void>? _profileSubscription;

  String? _lastScheduleSignature;
  Future<void> _scheduleQueue = Future.value();
  int _scheduleGeneration = 0;

  Future<void> getSchedule() async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <ScheduleModel>[]
        : await PlannerCache.instance.loadSchedule(userId);

    if (isClosed) return;

    emit(state.copyWith(status: ScheduleStatus.loading, errorMessage: null));

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
      final bundle = await _repository.getSchedule();
      if (isClosed) return;

      emit(
        state.copyWith(
          status: ScheduleStatus.success,
          schedule: _sortSchedule(bundle.schedule),
          pauses: bundle.pauses,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'getSchedule() failed; errorType=${error.runtimeType}',
        name: 'Schedule',
        stackTrace: stackTrace,
      );
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
            errorMessage: AppErrorLocalizer.code(error),
          ),
        );
      }
    }
  }

  Future<void> watchSchedule() async {
    await _subscription?.cancel();
    if (isClosed) return;

    _scheduleGeneration++;
    final generation = _scheduleGeneration;
    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <ScheduleModel>[]
        : await PlannerCache.instance.loadSchedule(userId);

    if (isClosed) return;
    emit(state.copyWith(status: ScheduleStatus.loading, errorMessage: null));

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
      (bundle) async {
        if (isClosed) return;

        emit(
          state.copyWith(
            status: ScheduleStatus.success,
            schedule: _sortSchedule(bundle.schedule),
            pauses: bundle.pauses,
            errorMessage: null,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (isClosed) return;
        developer.log(
          'watchSchedule() stream error; errorType=${error.runtimeType}',
          name: 'Schedule',
          stackTrace: stackTrace,
        );

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
              errorMessage: AppErrorLocalizer.code(error),
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

  String _scheduleSignature(
    List<ScheduleModel> schedule,
    List<SchedulePauseModel> pauses,
  ) {
    final items = [...schedule]..sort((a, b) => a.id.compareTo(b.id));
    final pauseItems = [...pauses]..sort((a, b) => a.id.compareTo(b.id));

    return [
      ...items.map(
        (entry) => [
          entry.id,
          entry.day,
          entry.startTime,
          entry.endTime,
          entry.scheduleStartDate.toIso8601String(),
          entry.scheduleEndDate.toIso8601String(),
          entry.courseName,
          entry.instructor,
        ].join('|'),
      ),
      'PAUSES',
      ...pauseItems.map((pause) => pause.signature),
    ].join('||');
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
