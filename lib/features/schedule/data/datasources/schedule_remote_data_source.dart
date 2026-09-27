import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/chronological_sort.dart';
import '../../../../core/cache/planner_cache.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/schedule_model.dart';
import '../models/schedule_pause_model.dart';
import '../../domain/repositories/schedule_repository.dart';

class ScheduleRemoteDataSource {
  ScheduleRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  static const _scheduleSelect = """
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
        schedule_start_date,
        end_date
      )
    )
  """;

  Future<ScheduleBundle> getSchedule() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
      final bundle = await _getRemoteSchedule(user.id);

      await PlannerCache.instance.saveSchedule(
        user.id,
        bundle.schedule,
      );

      developer.log(
        'Schedule repository returned '
        '${bundle.schedule.length} entries and '
        '${bundle.pauses.length} active pauses.',
        name: 'Schedule',
      );

      return bundle;
    } catch (error, stackTrace) {
      final cached = await PlannerCache.instance.loadSchedule(
        user.id,
      );

      developer.log(
        'Schedule query failed; '
        'errorType=${error.runtimeType}; '
        'cachedEntries=${cached.length}; '
        'usingCache=${cached.isNotEmpty}',
        name: 'Schedule',
        stackTrace: stackTrace,
      );

      if (cached.isEmpty) {
        rethrow;
      }

      return ScheduleBundle(
        schedule: cached,
        pauses: const [],
      );
    }
  }

  Future<ScheduleBundle> _getRemoteSchedule(String userId) async {
    final context = await _loadAcademicContext();

    final selected = await _supabase.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', context.termId);

    final selectedIds = selected
        .map(
          (row) => row['course_offering_id']?.toString() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toList();

    developer.log(
      'Schedule enrollment query; '
      'selectedOfferings=${selectedIds.length}.',
      name: 'Schedule',
    );

    if (selectedIds.isEmpty) {
      return ScheduleBundle(
        schedule: const [],
        pauses: await _loadActivePauses(),
      );
    }

    final response = await _supabase.client
        .from('schedule_entries')
        .select(_scheduleSelect)
        .eq(
          'course_offerings.term_id',
          context.termId,
        )
        .eq(
          'entry_type',
          'lecture',
        )
        .inFilter(
          'course_offering_id',
          selectedIds,
        )
        .order('day_of_week')
        .order('start_time');

    final result = response
        .map(
          (row) => ScheduleModel.fromMap(
            Map<String, dynamic>.from(
              row as Map,
            ),
          ),
        )
        .toList();

    result.sort((a, b) {
      final day = _dayOrder(a.day).compareTo(
        _dayOrder(b.day),
      );

      if (day != 0) {
        return day;
      }

      return compareTimeStrings(
        a.startTime,
        b.startTime,
      );
    });

    final pauses = await _loadActivePauses();

    developer.log(
      'Schedule entry query returned '
      '${result.length} lecture entries.',
      name: 'Schedule',
    );

    return ScheduleBundle(
      schedule: result,
      pauses: pauses,
    );
  }

  Future<List<SchedulePauseModel>> _loadActivePauses() async {
    try {
      final response = await _supabase.client
          .from('schedule_pauses')
          .select(
            'id,start_date,end_date,reason,is_active',
          )
          .eq(
            'is_active',
            true,
          )
          .order('start_date');

      final pauses = response
          .map(
            (row) => SchedulePauseModel(
              id: row['id']?.toString() ?? '',
              startDate: DateTime.tryParse(
                row['start_date']?.toString() ?? '',
              ),
              endDate: DateTime.tryParse(
                row['end_date']?.toString() ?? '',
              ),
              reason: row['reason']?.toString() ?? '',
              isActive: row['is_active'] == true,
            ),
          )
          .toList();

      developer.log(
        'Active schedule pauses loaded: '
        '${pauses.length}.',
        name: 'Schedule',
      );

      return pauses;
    } on PostgrestException catch (
      error,
      stackTrace
    ) {
      developer.log(
        'Failed to load schedule pauses; '
        'message=${error.message}; '
        'code=${error.code}; '
        'details=${error.details}; '
        'hint=${error.hint}',
        name: 'Schedule',
        stackTrace: stackTrace,
      );

      // A schedule pause is optional.
      // It must never prevent the normal schedule
      // from loading.
      return const [];
    } catch (error, stackTrace) {
      developer.log(
        'Unexpected error while loading schedule pauses; '
        'errorType=${error.runtimeType}',
        name: 'Schedule',
        stackTrace: stackTrace,
      );

      // A schedule pause is optional.
      // Keep the normal schedule working.
      return const [];
    }
  }

  Stream<ScheduleBundle> watchSchedule() {
    final controller = StreamController<ScheduleBundle>();

    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        controller.add(
          await getSchedule(),
        );
      } catch (error, stackTrace) {
        developer.log(
          'Schedule watch refresh failed; '
          'errorType=${error.runtimeType}',
          name: 'Schedule',
          stackTrace: stackTrace,
        );

        controller.addError(
          error,
          stackTrace,
        );
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
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'academic_terms',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'schedule_pauses',
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
        .select(
          'id,start_date,end_date,schedule_start_date',
        )
        .eq(
          'is_active',
          true,
        )
        .maybeSingle();

    if (termResponse == null) {
      throw const PostgrestException(
        message: 'No active academic term found.',
      );
    }

    return _AcademicContext(
      termId: termResponse['id'].toString(),
      startDate: DateTime.tryParse(
        termResponse['start_date']?.toString() ?? '',
      ),
      endDate: DateTime.tryParse(
        termResponse['end_date']?.toString() ?? '',
      ),
    );
  }
}

class _AcademicContext {
  const _AcademicContext({
    required this.termId,
    required this.startDate,
    required this.endDate,
  });

  final String termId;
  final DateTime? startDate;
  final DateTime? endDate;
}