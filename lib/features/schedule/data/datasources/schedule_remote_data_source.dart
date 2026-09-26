import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/chronological_sort.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/schedule_model.dart';

class ScheduleRemoteDataSource {
  ScheduleRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  static const _scheduleSelect = '''
    id,
    course_offering_id,
    day_of_week,
    start_time,
    end_time,
    entry_type,
    delivery_type,
    instructor,
    title,
    course_offerings!inner(
      id,
      course_id,
      instructor,
      group_id,
      term_id,
      courses!inner(
        id,
        name,
        level,
        image_url
      ),
      academic_groups!inner(
        id,
        code,
        level
      ),
      academic_terms!inner(
        id,
        schedule_start_date
      )
    )
  ''';

  Future<List<ScheduleModel>> getSchedule() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
      final result = await _getRemoteSchedule(user.id);
      await PlannerCache.instance.saveSchedule(user.id, result);
      return result;
    } catch (_) {
      final cached = await PlannerCache.instance.loadSchedule(user.id);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<List<ScheduleModel>> _getRemoteSchedule(String userId) async {
    final context = await _loadAcademicContext();

    final selected = await _supabase.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', context.termId);

    final selectedIds = selected
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (selectedIds.isEmpty) return [];

    final response = await _supabase.client
        .from('schedule_entries')
        .select(_scheduleSelect)
        .eq('course_offerings.term_id', context.termId)
        .inFilter('course_offering_id', selectedIds)
        .order('day_of_week')
        .order('start_time');

    final result = response
        .map(
          (row) => ScheduleModel.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();

    result.sort((a, b) {
      final day = _dayOrder(a.day).compareTo(_dayOrder(b.day));
      if (day != 0) return day;
      return compareTimeStrings(a.startTime, b.startTime);
    });
    return result;
  }

  Stream<List<ScheduleModel>> watchSchedule() {
    final controller = StreamController<List<ScheduleModel>>();
    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        controller.add(await getSchedule());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () async {
      await refresh();

      channel = _supabase.client
          .channel('eelu_schedule_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'schedule_entries',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'course_offerings',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'courses',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'academic_groups',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_course_selections',
            callback: (_) => refresh(),
          )
          .subscribe();
    };

    controller.onCancel = () async {
      await channel?.unsubscribe();
      await controller.close();
    };

    return controller.stream;
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

  Future<_AcademicContext> _loadAcademicContext() async {
    final termResponse = await _supabase.client
        .from('academic_terms')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();

    if (termResponse == null) {
      throw const PostgrestException(
        message: 'No active academic term found.',
      );
    }

    return _AcademicContext(
      termId: termResponse['id'].toString(),
    );
  }
}

class _AcademicContext {
  const _AcademicContext({required this.termId});

  final String termId;
}
