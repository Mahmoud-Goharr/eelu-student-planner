import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../exams/data/models/exam_model.dart';
import '../../../exams/domain/repositories/exams_repository.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/domain/repositories/tasks_repository.dart';
import '../../../tasks/presentation/sync/tasks_sync_bus.dart';
import 'all_deadlines_state.dart';

class AllDeadlinesCubit extends Cubit<AllDeadlinesState> {
  AllDeadlinesCubit({
    required this.tasksRepository,
    required this.examsRepository,
  }) : super(const AllDeadlinesState()) {
    _tasksSubscription = tasksRepository.watchTasks().listen(
      (tasks) {
        if (isClosed) return;
        _replaceTasks(tasks);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('All deadlines tasks realtime failed: $error');
      },
    );

    _tasksSyncSubscription = TasksSyncBus.changes.listen((_) {
      if (!isClosed) unawaited(load(silent: true));
    });

    _profileSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) unawaited(load(silent: true));
    });
  }

  final TasksRepository tasksRepository;
  final ExamsRepository examsRepository;

  StreamSubscription<List<TaskModel>>? _tasksSubscription;
  StreamSubscription<void>? _tasksSyncSubscription;
  StreamSubscription<void>? _profileSubscription;

  Future<void> load({bool silent = false}) async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    if (userId == null) {
      emit(
        state.copyWith(
          status: AllDeadlinesStatus.failure,
          errorMessage: 'User is not authenticated.',
        ),
      );
      return;
    }

    if (!silent) {
      emit(state.copyWith(status: AllDeadlinesStatus.loading, clearError: true));
    }

    final cachedTasks = await PlannerCache.instance.loadTasks(userId);
    final cachedExams = await PlannerCache.instance.loadExams(userId);

    if (isClosed) return;

    final online = await NetworkProbe.isOnline();
    if (isClosed) return;

    if (!online) {
      emit(
        AllDeadlinesState(
          status: AllDeadlinesStatus.success,
          tasks: cachedTasks,
          exams: cachedExams,
          errorMessage: 'offline',
        ),
      );
      return;
    }

    try {
      final results = await Future.wait([
        tasksRepository.getTasks(),
        examsRepository.getExams(),
      ]);

      if (isClosed) return;

      emit(
        AllDeadlinesState(
          status: AllDeadlinesStatus.success,
          tasks: results[0] as List<TaskModel>,
          exams: results[1] as List<ExamModel>,
        ),
      );
    } catch (error) {
      debugPrint('All deadlines load failed: $error');

      if (isClosed) return;

      if (cachedTasks.isNotEmpty || cachedExams.isNotEmpty) {
        emit(
          AllDeadlinesState(
            status: AllDeadlinesStatus.success,
            tasks: cachedTasks,
            exams: cachedExams,
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          AllDeadlinesState(
            status: AllDeadlinesStatus.failure,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> toggleTask(TaskModel task, bool completed) async {
    if (isClosed || !task.canToggleCompletion) return;

    try {
      final updated = await tasksRepository.toggleTaskCompletion(
        task: task,
        isCompleted: completed,
      );

      if (isClosed) return;

      final tasks = state.tasks
          .map((item) => item.id == updated.id ? updated : item)
          .toList();

      _replaceTasks(tasks);
      TasksSyncBus.notify();
    } catch (error) {
      debugPrint('All deadlines completion update failed: $error');
      rethrow;
    }
  }

  void _replaceTasks(List<TaskModel> tasks) {
    if (isClosed) return;

    emit(
      state.copyWith(
        status: AllDeadlinesStatus.success,
        tasks: tasks,
        clearError: true,
      ),
    );
  }

  List<TaskModel> get upcomingTasks {
    final now = EgyptTime.now();
    return state.tasks
        .where((task) => !task.isCompleted && task.dueDate.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<ExamModel> get upcomingExams {
    final now = EgyptTime.now();
    return state.exams.where((exam) => exam.startTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Future<void> close() async {
    await _tasksSubscription?.cancel();
    await _tasksSyncSubscription?.cancel();
    await _profileSubscription?.cancel();
    return super.close();
  }
}
