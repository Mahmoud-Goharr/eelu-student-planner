import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/task_model.dart';

class TasksRemoteDataSource {
  TasksRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  Future<List<TaskModel>> getTasks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
      final assignmentsResponse = await _supabase.client
          .from('assignments')
          .select(
            'id,name,course_id,due_date,description,created_at,'
            'courses(name,level)',
          )
          .order('due_date');

      final term = await _supabase.client
          .from('academic_terms')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();

      final selectedRows = term == null
          ? const <Map<String, dynamic>>[]
          : await _supabase.client
              .from('student_course_selections')
              .select('course_offering_id')
              .eq('student_id', user.id)
              .eq('term_id', term['id']);

      final selectedOfferingIds = selectedRows
          .map((row) => row['course_offering_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final selectedCourseOfferingResponse = selectedOfferingIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _supabase.client
              .from('course_offerings')
              .select('id,course_id')
              .inFilter('id', selectedOfferingIds);

      final selectedCourseIds = selectedCourseOfferingResponse
          .map((row) => row['course_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final quizzesResponse = selectedOfferingIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _supabase.client
              .from('quizzes')
              .select(
                'id,title,description,quiz_date,lecture_start_time,'
                'created_at,offering_id,'
                'course_offerings!inner('
                'course_id,group_id,term_id,'
                'courses(name,level),'
                'academic_groups(code,level)'
                ')',
              )
              .inFilter('offering_id', selectedOfferingIds)
              .order('quiz_date');

      final personalResponse = await _supabase.client
          .from('student_assignments')
          .select('id,title,description,due_date,is_completed,created_at')
          .eq('student_id', user.id)
          .order('due_date');

      final progressResponse = await _supabase.client
          .from('student_assignment_progress')
          .select('assignment_id,is_completed')
          .eq('student_id', user.id);

      final progress = <String, bool>{
        for (final row in progressResponse as List)
          row['assignment_id'].toString():
              row['is_completed'] as bool? ?? false,
      };

      final localCompletions = await PlannerCache.instance.loadCompletions(
        user.id,
      );

      final tasks = <TaskModel>[];

      for (final row in assignmentsResponse as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final course = _mapValue(map['courses']);
        final assignmentId = map['id']?.toString() ?? '';
        final assignmentCourseId = map['course_id']?.toString() ?? '';

        if (!selectedCourseIds.contains(assignmentCourseId)) {
          continue;
        }

        tasks.add(
          TaskModel(
            id: 'assignment:$assignmentId',
            title: map['name']?.toString() ?? '',
            description: map['description']?.toString(),
            courseId:
                course['name']?.toString() ??
                map['course_id']?.toString() ??
                '',
            dueDate: _parseDate(map['due_date']),
            type: 'assignment',
            isCompleted: progress[assignmentId] ?? false,
            isPersonal: false,
            createdAt: _parseNullableDate(map['created_at']),
          ),
        );
      }

      for (final row in quizzesResponse as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final offering = _mapValue(map['course_offerings']);
        final course = _mapValue(offering['courses']);
        final quizDate = _parseDate(map['quiz_date']);
        final startTime = map['lecture_start_time']?.toString();
        final quizId = map['id']?.toString() ?? '';

        tasks.add(
          TaskModel(
            id: 'quiz:$quizId',
            title: map['title']?.toString() ?? '',
            description: map['description']?.toString(),
            courseId:
                course['name']?.toString() ??
                offering['course_id']?.toString() ??
                '',
            dueDate: _combineDateAndTime(quizDate, startTime),
            type: 'quiz',
            isCompleted: localCompletions['quiz:$quizId'] ?? false,
            isPersonal: false,
            createdAt: _parseNullableDate(map['created_at']),
          ),
        );
      }

      for (final row in personalResponse as List) {
        final map = Map<String, dynamic>.from(row as Map);

        tasks.add(
          TaskModel(
            id: 'personal:${map['id']}',
            title: map['title']?.toString() ?? '',
            description: map['description']?.toString(),
            courseId: '',
            dueDate: _parseDate(map['due_date']),
            type: 'personal_assignment',
            isCompleted: map['is_completed'] as bool? ?? false,
            isPersonal: true,
            createdAt: _parseNullableDate(map['created_at']),
          ),
        );
      }

      await PlannerCache.instance.saveTasks(user.id, tasks);
      return await _archiveAndKeepActive(user.id, tasks);
    } catch (_) {
      final cached = await PlannerCache.instance.loadTasks(user.id);
      if (cached.isEmpty) rethrow;
      return await _archiveAndKeepActive(user.id, cached);
    }
  }

  Future<List<TaskModel>> _archiveAndKeepActive(
    String userId,
    List<TaskModel> tasks,
  ) async {
    final now = EgyptTime.now();
    final active = <TaskModel>[];

    for (final task in tasks) {
      if (task.dueDate.isAfter(now)) {
        active.add(task);
      } else {
        await PlannerCache.instance.archiveTask(userId, task);
      }
    }

    active.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return active;
  }

  Stream<List<TaskModel>> watchTasks() {
    final controller = StreamController<List<TaskModel>>();
    RealtimeChannel? channel;

    var disposed = false;

    Future<void> refresh() async {
      if (disposed || controller.isClosed) {
        return;
      }

      try {
        final tasks = await getTasks();

        if (disposed || controller.isClosed) {
          return;
        }

        controller.add(tasks);
      } catch (error, stackTrace) {
        if (disposed || controller.isClosed) {
          return;
        }

        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () async {
      if (disposed || controller.isClosed) {
        return;
      }

      await refresh();

      if (disposed || controller.isClosed) {
        return;
      }

      channel = _supabase.client
          .channel(
            'student-tasks-sync-${_supabase.client.auth.currentUser?.id ?? 'guest'}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'assignments',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'quizzes',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_assignments',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_assignment_progress',
            callback: (_) => refresh(),
          )
          .subscribe();
    };

    controller.onCancel = () async {
      disposed = true;

      final currentChannel = channel;
      channel = null;

      if (currentChannel != null) {
        await currentChannel.unsubscribe();
      }

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Future<TaskModel> createPersonalAssignment({
    required String title,
    String? description,
    required DateTime dueDate,
  }) async {
    final response = await _supabase.client
        .from('student_assignments')
        .insert({
          'student_id': _supabase.client.auth.currentUser!.id,
          'title': title,
          'description': description,
          'due_date': dueDate.toIso8601String(),
          'is_completed': false,
        })
        .select('id,title,description,due_date,is_completed,created_at')
        .single();

    final map = Map<String, dynamic>.from(response as Map);

    return TaskModel(
      id: 'personal:${map['id']}',
      title: map['title']?.toString() ?? title,
      description: map['description']?.toString(),
      dueDate: _parseDate(map['due_date']),
      type: 'personal_assignment',
      isCompleted: map['is_completed'] as bool? ?? false,
      isPersonal: true,
      createdAt: _parseNullableDate(map['created_at']),
    );
  }

  Future<TaskModel> updatePersonalAssignment(TaskModel task) async {
    if (!task.id.startsWith('personal:')) {
      throw UnsupportedError(
        'Academic assignments and quizzes are read-only for students.',
      );
    }

    final id = task.id.substring('personal:'.length);

    final response = await _supabase.client
        .from('student_assignments')
        .update({
          'title': task.title,
          'description': task.description,
          'due_date': task.dueDate.toIso8601String(),
          'is_completed': task.isCompleted,
          'completed_at': task.isCompleted
              ? DateTime.now().toIso8601String()
              : null,
        })
        .eq('id', id)
        .select('id,title,description,due_date,is_completed,created_at')
        .single();

    final map = Map<String, dynamic>.from(response as Map);

    return task.copyWith(
      id: 'personal:${map['id']}',
      title: map['title']?.toString() ?? task.title,
      description: map['description']?.toString(),
      dueDate: _parseDate(map['due_date']),
      isCompleted: map['is_completed'] as bool? ?? task.isCompleted,
      createdAt: _parseNullableDate(map['created_at']),
    );
  }

  Future<void> deletePersonalAssignment(String taskId) async {
    if (!taskId.startsWith('personal:')) {
      throw UnsupportedError(
        'Academic assignments and quizzes are read-only for students.',
      );
    }

    final id = taskId.substring('personal:'.length);
    await _supabase.client.from('student_assignments').delete().eq('id', id);
  }

  Future<TaskModel> toggleTaskCompletion({
    required TaskModel task,
    required bool isCompleted,
  }) async {
    if (task.id.startsWith('personal:')) {
      final id = task.id.substring('personal:'.length);

      final response = await _supabase.client
          .from('student_assignments')
          .update({
            'is_completed': isCompleted,
            'completed_at': isCompleted
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', id)
          .select('id,title,description,due_date,is_completed,created_at')
          .single();

      final map = Map<String, dynamic>.from(response as Map);

      return task.copyWith(
        isCompleted: map['is_completed'] as bool? ?? isCompleted,
      );
    }

    if (task.id.startsWith('quiz:')) {
      await PlannerCache.instance.saveCompletion(
        _supabase.client.auth.currentUser!.id,
        task.id,
        isCompleted,
      );
      return task.copyWith(isCompleted: isCompleted);
    }

    if (task.id.startsWith('assignment:')) {
      final assignmentId = task.id.substring('assignment:'.length);

      final response = await _supabase.client
          .from('student_assignment_progress')
          .upsert({
            'assignment_id': assignmentId,
            'student_id': _supabase.client.auth.currentUser!.id,
            'is_completed': isCompleted,
            'completed_at': isCompleted
                ? DateTime.now().toIso8601String()
                : null,
          }, onConflict: 'assignment_id,student_id')
          .select('assignment_id,is_completed')
          .single();

      return task.copyWith(
        isCompleted: response['is_completed'] as bool? ?? isCompleted,
      );
    }

    throw UnsupportedError('This task cannot be marked as completed.');
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static DateTime _combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) return date;

    final parts = time.split(':');
    if (parts.length < 2) return date;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }
}
