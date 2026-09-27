import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';

import '../../data/models/task_model.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../sync/tasks_sync_bus.dart';
import 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  TasksCubit(this._repository) : super(const TasksState()) {
    _subscribeToRealtime();
    _profileSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) {
        unawaited(getTasks());
      }
    });
  }

  final TasksRepository _repository;
  StreamSubscription<List<TaskModel>>? _tasksSubscription;
  StreamSubscription<void>? _profileSubscription;

  Future<void> getTasks() async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <TaskModel>[]
        : await PlannerCache.instance.loadTasks(userId);

    if (isClosed) return;

    final cachedHistory = userId == null
        ? const <PlannerHistoryItem>[]
        : await PlannerCache.instance.loadHistory(userId);

    if (isClosed) return;

    emit(state.copyWith(status: TasksStatus.loading, clearError: true));

    final online = await NetworkProbe.isOnline();

    if (isClosed) return;

    if (!online) {
      if (cached.isNotEmpty || cachedHistory.isNotEmpty) {
        emit(
          state.copyWith(
            status: TasksStatus.success,
            tasks: cached,
            history: cachedHistory,
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: TasksStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    try {
      final tasks = await _repository.getTasks();

      if (isClosed) return;

      final history = userId == null
          ? const <PlannerHistoryItem>[]
          : await PlannerCache.instance.loadHistory(userId);

      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.success,
          tasks: tasks,
          history: history,
          clearError: true,
        ),
      );
    } catch (error) {
      debugPrint('Tasks load failed: $error');

      if (isClosed) return;

      if (cached.isNotEmpty || cachedHistory.isNotEmpty) {
        emit(
          state.copyWith(
            status: TasksStatus.success,
            tasks: cached,
            history: cachedHistory,
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: TasksStatus.failure,
            errorMessage: AppErrorLocalizer.code(error),
          ),
        );
      }
    }
  }

  /// Compatibility API for older screens that still call createTask().
  /// The student-created item is always stored as a personal Assignment.
  Future<void> createTask({
    required String title,
    String? description,
    String courseId = '',
    required DateTime dueDate,
    String type = 'assignment',
    String priority = 'medium',
    int level = 0,
    String section = '',
  }) {
    return createPersonalAssignment(
      title: title,
      description: description,
      dueDate: dueDate,
    );
  }

  /// Compatibility getter for screens that previously used demoTasks.
  /// Production data is now loaded from Supabase.
  static List<TaskModel> get demoTasks => const <TaskModel>[];

  bool get isBusy => switch (state.status) {
        TasksStatus.creating ||
        TasksStatus.updating ||
        TasksStatus.deleting =>
          true,
        _ => false,
      };

  Future<void> createPersonalAssignment({
    required String title,
    String? description,
    required DateTime dueDate,
  }) async {
    if (isClosed || isBusy) return;

    emit(state.copyWith(status: TasksStatus.creating, clearError: true));

    try {
      final task = await _repository.createPersonalAssignment(
        title: title,
        description: description,
        dueDate: dueDate,
      );

      if (isClosed) return;

      TasksSyncBus.notify();

      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.createSuccess,
          tasks: [...state.tasks, task]
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> updatePersonalAssignment(TaskModel task) async {
    if (isClosed || isBusy) return;

    emit(state.copyWith(status: TasksStatus.updating, clearError: true));

    try {
      final updated = await _repository.updatePersonalAssignment(task);

      if (isClosed) return;

      final tasks = state.tasks
          .map((item) => item.id == updated.id ? updated : item)
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      TasksSyncBus.notify();

      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.updateSuccess,
          tasks: tasks,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (isClosed || isBusy) return;

    emit(state.copyWith(status: TasksStatus.deleting, clearError: true));

    try {
      await _repository.deletePersonalAssignment(taskId);

      if (isClosed) return;

      TasksSyncBus.notify();

      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.deleteSuccess,
          tasks: state.tasks.where((task) => task.id != taskId).toList(),
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> toggleTaskCompletion({
    required TaskModel task,
    required bool isCompleted,
  }) async {
    if (isClosed || !task.canToggleCompletion || isBusy) return;

    final oldTasks = state.tasks;

    emit(
      state.copyWith(
        status: TasksStatus.updating,
        tasks: oldTasks
            .map(
              (item) => item.id == task.id
                  ? item.copyWith(isCompleted: isCompleted)
                  : item,
            )
            .toList(),
        clearError: true,
      ),
    );

    try {
      final updated = await _repository.toggleTaskCompletion(
        task: task,
        isCompleted: isCompleted,
      );

      if (isClosed) return;

      TasksSyncBus.notify();

      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.updateSuccess,
          tasks: state.tasks
              .map((item) => item.id == updated.id ? updated : item)
              .toList(),
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: TasksStatus.failure,
          tasks: oldTasks,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  void _subscribeToRealtime() {
    _tasksSubscription?.cancel();

    _tasksSubscription = _repository.watchTasks().listen(
      (tasks) {
        if (isClosed) return;

        emit(
          state.copyWith(
            status: TasksStatus.success,
            tasks: tasks,
            clearError: true,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (isClosed) return;
        debugPrint('Realtime tasks stream failed: $error');
      },
    );
  }

  @override
  Future<void> close() async {
    await _tasksSubscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
