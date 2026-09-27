import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/network_probe.dart';
import '../../../tasks/presentation/sync/tasks_sync_bus.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';
import '../../../../core/cache/planner_cache.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/egypt_time.dart';

import '../../../exams/data/models/exam_model.dart';
import '../../../exams/domain/repositories/exams_repository.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/domain/repositories/tasks_repository.dart';
import '../models/home_deadline.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this.tasksRepository, required this.examsRepository})
    : super(const HomeState());

  final TasksRepository tasksRepository;
  final ExamsRepository examsRepository;

  StreamSubscription<List<TaskModel>>? _tasksSubscription;
  StreamSubscription<void>? _tasksSyncSubscription;
  StreamSubscription<void>? _profileSyncSubscription;

  Future<void> load() async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;

    final cachedTasks = userId == null
        ? const <TaskModel>[]
        : await PlannerCache.instance.loadTasks(userId);

    final cachedExams = userId == null
        ? const <ExamModel>[]
        : await PlannerCache.instance.loadExams(userId);

    final cachedHistory = userId == null
        ? const <PlannerHistoryItem>[]
        : await PlannerCache.instance.loadHistory(userId);

    developer.log(
      'Home load started; authenticated=${userId != null}; '
      'cachedTasks=${cachedTasks.length}; '
      'cachedExams=${cachedExams.length}',
      name: 'NotificationDebug',
    );

    if (isClosed) return;

    emit(state.copyWith(status: HomeStatus.loading, clearError: true));

    final online = await NetworkProbe.isOnline();

    developer.log(
      'Home connectivity; online=$online.',
      name: 'NotificationDebug',
    );

    if (isClosed) return;

    if (!online) {
      if (userId != null) {
        emit(
          HomeState(
            status: HomeStatus.success,
            deadlines: _buildDeadlines(cachedTasks, cachedExams),
            taskCount: _activeTaskCount(cachedTasks),
            hasDeadlineHistory: cachedHistory.isNotEmpty,
            errorMessage: 'offline',
          ),
        );

        if (isClosed) return;

        _startTasksWatch();
        _startLocalTasksSync();
        _startProfileSync();
      } else {
        emit(
          state.copyWith(status: HomeStatus.failure, errorMessage: 'offline'),
        );
      }

      return;
    }

    final tasksResult = await _loadTasks();

    if (isClosed) return;

    final examsResult = await _loadExams();

    developer.log(
      'Home remote load completed; '
      'tasks=${tasksResult?.length ?? 'failed'}; '
      'exams=${examsResult?.length ?? 'failed'}; '
      'taskCache=${cachedTasks.length}; '
      'examCache=${cachedExams.length}',
      name: 'NotificationDebug',
    );

    if (isClosed) return;

    final deadlines = _buildDeadlines(
      tasksResult ?? cachedTasks,
      examsResult ?? cachedExams,
    );

    final remoteHistory = userId == null
        ? const <PlannerHistoryItem>[]
        : await PlannerCache.instance.loadHistory(userId);

    if (isClosed) return;

    final hasDeadlineHistory =
        remoteHistory.isNotEmpty ||
        (tasksResult?.isNotEmpty ?? false) ||
        (examsResult?.isNotEmpty ?? false);

    emit(
      HomeState(
        status: HomeStatus.success,
        deadlines: deadlines,
        taskCount: _activeTaskCount(tasksResult ?? cachedTasks),
        hasDeadlineHistory: hasDeadlineHistory,
        errorMessage: tasksResult == null || examsResult == null
            ? 'Unable to load remote deadlines.'
            : null,
      ),
    );

    if (isClosed) return;

    _startTasksWatch();
    _startLocalTasksSync();
    _startProfileSync();
  }

  void _startTasksWatch() {
    _tasksSubscription?.cancel();

    _tasksSubscription = tasksRepository.watchTasks().listen(
      (tasks) async {
        if (isClosed) return;

        if (isClosed) return;

        final exams = _currentExams;

        final userId = SupabaseService().auth.currentUser?.id;

        final history = userId == null
            ? const <PlannerHistoryItem>[]
            : await PlannerCache.instance.loadHistory(userId);

        if (isClosed) return;

        emit(
          state.copyWith(
            status: HomeStatus.success,
            deadlines: _buildDeadlines(tasks, exams),
            taskCount: _activeTaskCount(tasks),
            hasDeadlineHistory:
                history.isNotEmpty || tasks.isNotEmpty || exams.isNotEmpty,
            clearError: true,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Task watch stream failed; errorType=${error.runtimeType}',
          name: 'NotificationDebug',
        );

        // Keep the last successful Home state
        // if the realtime channel fails.
      },
    );
  }

  List<ExamModel> get _currentExams => _lastExams;

  List<ExamModel> _lastExams = const <ExamModel>[];

  void _startLocalTasksSync() {
    _tasksSyncSubscription?.cancel();

    _tasksSyncSubscription = TasksSyncBus.changes.listen((_) async {
      if (isClosed) return;

      final tasks = await _loadTasks();

      if (tasks == null || isClosed) return;

      final userId = SupabaseService().auth.currentUser?.id;

      final history = userId == null
          ? const <PlannerHistoryItem>[]
          : await PlannerCache.instance.loadHistory(userId);

      if (isClosed) return;

      emit(
        state.copyWith(
          status: HomeStatus.success,
          deadlines: _buildDeadlines(tasks, _currentExams),
          taskCount: _activeTaskCount(tasks),
          hasDeadlineHistory:
              history.isNotEmpty ||
              tasks.isNotEmpty ||
              _currentExams.isNotEmpty,
          clearError: true,
        ),
      );
    });
  }

  void _startProfileSync() {
    _profileSyncSubscription?.cancel();

    _profileSyncSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) {
        load();
      }
    });
  }

  Future<List<TaskModel>?> _loadTasks() async {
    try {
      final tasks = await tasksRepository.getTasks();

      return tasks;
    } catch (error) {
      developer.log(
        'Task load failed; errorType=${error.runtimeType}',
        name: 'NotificationDebug',
      );

      return null;
    }
  }

  Future<List<ExamModel>?> _loadExams() async {
    try {
      final exams = await examsRepository.getExams();

      _lastExams = exams;

      return exams;
    } catch (error) {
      developer.log(
        'Exam load failed; errorType=${error.runtimeType}',
        name: 'NotificationDebug',
      );

      return null;
    }
  }

  int _activeTaskCount(List<TaskModel> tasks) {
    final now = EgyptTime.now();

    return tasks
        .where((task) => !task.isCompleted && task.dueDate.isAfter(now))
        .length;
  }

  List<HomeDeadline> _buildDeadlines(
    List<TaskModel> tasks,
    List<ExamModel> exams,
  ) {
    final now = EgyptTime.now();

    final deadlines = <HomeDeadline>[
      for (final task in tasks)
        if (!task.isCompleted &&
            task.dueDate.isAfter(DateTime(now.year, now.month, now.day)))
          HomeDeadline(
            title: task.title,
            course: task.courseId,
            when: task.dueDate,
            type: task.type,
            isExam: false,
            isPersonal: task.isPersonal,
          ),
      for (final exam in exams)
        if (exam.startTime.isAfter(now))
          HomeDeadline(
            title: '${exam.courseName} ${exam.type}',
            course: exam.courseName,
            when: exam.startTime,
            type: exam.type,
            isExam: true,
            isPersonal: false,
          ),
    ];

    deadlines.sort((a, b) => a.when.compareTo(b.when));

    return deadlines;
  }

  @override
  Future<void> close() async {
    await _tasksSubscription?.cancel();
    await _tasksSyncSubscription?.cancel();
    await _profileSyncSubscription?.cancel();

    return super.close();
  }
}
