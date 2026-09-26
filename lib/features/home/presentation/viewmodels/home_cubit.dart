import 'dart:async';

import '../../../../core/connectivity/network_probe.dart';
import '../../../tasks/presentation/sync/tasks_sync_bus.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';
import '../../../../core/cache/planner_cache.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/notifications/local_notification_scheduler.dart';
import '../../../../core/utils/egypt_time.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    if (isClosed) return;

    emit(state.copyWith(status: HomeStatus.loading, clearError: true));

    final online = await NetworkProbe.isOnline();
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
        await _scheduleReminders(cachedTasks, cachedExams);
        if (isClosed) return;
        _startTasksWatch();
        _startLocalTasksSync();
        _startProfileSync();
      } else {
        emit(
          state.copyWith(
            status: HomeStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    final tasksResult = await _loadTasks();
    if (isClosed) return;
    final examsResult = await _loadExams();
    if (isClosed) return;

    final deadlines = _buildDeadlines(
      tasksResult ?? cachedTasks,
      examsResult ?? cachedExams,
    );
    final remoteHistory = userId == null
        ? const <PlannerHistoryItem>[]
        : await PlannerCache.instance.loadHistory(userId);
    if (isClosed) return;

    final hasDeadlineHistory = remoteHistory.isNotEmpty ||
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

    await _scheduleReminders(
      tasksResult ?? cachedTasks,
      examsResult ?? cachedExams,
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

        await _scheduleReminders(tasks, _currentExams);
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
            hasDeadlineHistory: history.isNotEmpty || tasks.isNotEmpty || exams.isNotEmpty,
            clearError: true,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        // Keep the last successful Home state if the realtime channel fails.
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
      await _scheduleReminders(tasks, _currentExams);
      emit(
        state.copyWith(
          status: HomeStatus.success,
          deadlines: _buildDeadlines(tasks, _currentExams),
          taskCount: _activeTaskCount(tasks),
          hasDeadlineHistory: history.isNotEmpty || tasks.isNotEmpty || _currentExams.isNotEmpty,
          clearError: true,
        ),
      );
    });
  }

  void _startProfileSync() {
    _profileSyncSubscription?.cancel();
    _profileSyncSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) load();
    });
  }

  Future<List<TaskModel>?> _loadTasks() async {
    try {
      final tasks = await tasksRepository.getTasks();
      return tasks;
    } catch (_) {
      return null;
    }
  }

  Future<List<ExamModel>?> _loadExams() async {
    try {
      final exams = await examsRepository.getExams();
      _lastExams = exams;
      return exams;
    } catch (_) {
      return null;
    }
  }

  int _activeTaskCount(List<TaskModel> tasks) {
    final now = EgyptTime.now();
    return tasks.where(
      (task) => !task.isCompleted && task.dueDate.isAfter(now),
    ).length;
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

  Future<void> _scheduleReminders(
    List<TaskModel> tasks,
    List<ExamModel> exams,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') == false) {
      await LocalNotificationScheduler.instance.cancelPlannerReminders();
      return;
    }

    final reminders = <PlannerReminder>[];
    final now = EgyptTime.now();

    // Academic assignments/quizzes and exams are deadline-based reminders.
    // The dashboard/FCM tells the student immediately when a new item is
    // created. The app itself handles time-based reminders from its deadline.
    for (final task in tasks.where((item) => !item.isCompleted)) {
      final deadline = task.dueDate;
      if (!deadline.isAfter(now)) continue;

      final (titleEn, titleAr) = switch (task.type) {
        'quiz' => ('Quiz reminder: ${task.title}', 'تذكير باختبار: ${task.title}'),
        'personal_assignment' => (
            'Assignment reminder: ${task.title}',
            'تذكير بتاسك: ${task.title}',
          ),
        _ => ('Assignment reminder: ${task.title}', 'تذكير بالاسيمنت: ${task.title}'),
      };

      final course = task.courseId.isEmpty
          ? 'EELU Student Planner'
          : task.courseId;

      final reminders24h = deadline.subtract(const Duration(hours: 24));
      if (reminders24h.isAfter(now)) {
        reminders.add(
          PlannerReminder(
            id: 'deadline24:${task.id}',
            titleEn: titleEn,
            titleAr: titleAr,
            bodyEn: '$course is due in 24 hours (${_time(deadline)}).',
            bodyAr: '$course موعده النهائي خلال 24 ساعة (${_time(deadline)}).',
            eventAt: deadline,
            notificationAt: reminders24h,
          ),
        );
      }

    }

    for (final exam in exams.where((item) => item.startTime.isAfter(now))) {
      final eventAt = exam.startTime;
      final typeEn = _examTypeEn(exam.type);
      final typeAr = _examTypeAr(exam.type);

      final reminder24h = eventAt.subtract(const Duration(hours: 24));
      if (reminder24h.isAfter(now)) {
        reminders.add(
          PlannerReminder(
            id: 'exam24:${exam.id}',
            titleEn: '$typeEn reminder: ${exam.courseName}',
            titleAr: 'تذكير بـ$typeAr: ${exam.courseName}',
            bodyEn: '${exam.courseName} starts in 24 hours at ${_time(eventAt)}.',
            bodyAr: '${exam.courseName} يبدأ خلال 24 ساعة الساعة ${_time(eventAt)}.',
            eventAt: eventAt,
            notificationAt: reminder24h,
          ),
        );
      }

    }

    await LocalNotificationScheduler.instance.replaceReminders(
      reminders,
      idStart: LocalNotificationScheduler.plannerTaskIdStart,
    );
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  String _examTypeEn(String value) {
    return switch (value.toLowerCase()) {
      'quiz' => 'Quiz',
      'midterm' => 'Midterm exam',
      _ => 'Final exam',
    };
  }

  String _examTypeAr(String value) {
    return switch (value.toLowerCase()) {
      'quiz' => 'الاختبار القصير',
      'midterm' => 'الاختبار النصفي',
      _ => 'الامتحان النهائي',
    };
  }

  @override
  Future<void> close() async {
    await _tasksSubscription?.cancel();
    await _tasksSyncSubscription?.cancel();
    await _profileSyncSubscription?.cancel();
    return super.close();
  }
}
