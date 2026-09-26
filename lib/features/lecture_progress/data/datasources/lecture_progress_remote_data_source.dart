import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/chronological_sort.dart';
import '../../../../core/utils/egypt_time.dart';

import '../../../../core/services/supabase_service.dart';
import '../models/course_lecture_progress_model.dart';
import '../models/lecture_progress_model.dart';

class LectureProgressRemoteDataSource {
  LectureProgressRemoteDataSource({
    SupabaseService? supabaseService,
  }) : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  static const _scheduleSelect = '''
    id,
    course_offering_id,
    day_of_week,
    start_time,
    end_time,
    entry_type,
    instructor,
    course_offerings!inner(
      id,
      course_id,
      term_id,
      group_id,
      instructor,
      courses!inner(
        id,
        name,
        level
      ),
      academic_groups!inner(
        id,
        code,
        level
      )
    )
  ''';

  Future<List<CourseLectureProgressModel>> getCourseProgress() async {
    final lectures = await getLectureProgress();
    final courses = await getEnrolledCourses();

    final byCourse = <String, List<LectureProgressModel>>{};

    for (final lecture in lectures) {
      byCourse
          .putIfAbsent(lecture.courseId, () => <LectureProgressModel>[])
          .add(lecture);
    }

    return courses
        .map(
          (course) => CourseLectureProgressModel(
            courseId: course.id,
            courseName: course.name,
            lectures: List.unmodifiable(
              byCourse[course.id] ?? const <LectureProgressModel>[],
            ),
          ),
        )
        .toList();
  }

  Future<List<CourseInfo>> getEnrolledCourses() async {
    final user = _supabaseService.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    final context = await _loadAcademicContext();

    final selected = await _supabaseService.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', user.id)
        .eq('term_id', context.termId);

    final selectedIds = selected
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (selectedIds.isEmpty) return [];

    final response = await _supabaseService.client
        .from('course_offerings')
        .select('course_id,courses!inner(id,name,level)')
        .eq('term_id', context.termId)
        .inFilter('id', selectedIds)
        .order('course_id');

    final unique = <String, CourseInfo>{};

    for (final item in response) {
      final row = Map<String, dynamic>.from(item as Map);
      final course = _mapValue(row['courses']);
      final courseId = course['id']?.toString() ?? row['course_id']?.toString();

      if (courseId == null || courseId.isEmpty) continue;

      final name = course['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      unique[courseId] = CourseInfo(id: courseId, name: name);
    }

    final result = unique.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return result;
  }

  Future<List<LectureProgressModel>> getLectureProgress() async {
    final user = _supabaseService.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    final context = await _loadAcademicContext();

    final startDate = _dateOnly(
      context.scheduleStartDate.isAfter(context.termStart)
          ? context.scheduleStartDate
          : context.termStart,
    );
    final termEndDate = _dateOnly(context.termEnd);
    final today = _dateOnly(EgyptTime.now());
    final endDate = today.isBefore(termEndDate) ? today : termEndDate;

    if (startDate.isAfter(endDate)) {
      return [];
    }

    var query = _supabaseService.client
        .from('schedule_entries')
        .select(_scheduleSelect)
        .eq('entry_type', 'lecture')
        .eq('course_offerings.term_id', context.termId);

    final selected = await _supabaseService.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', user.id)
        .eq('term_id', context.termId);
    final selectedIds = selected
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (selectedIds.isEmpty) return [];

    query = query.inFilter('course_offering_id', selectedIds);

    final scheduleResponse = await query
        .order('day_of_week')
        .order('start_time');

    if (scheduleResponse.isEmpty) {
      return [];
    }

    final scheduleEntries = scheduleResponse
        .map(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();

    final scheduleIds = scheduleEntries
        .map((item) => item['id'].toString())
        .toSet()
        .toList();

    final progressResponse = await _supabaseService.client
        .from('student_lecture_progress')
        .select(
          'schedule_entry_id, lecture_date, completed',
        )
        .eq('student_id', user.id)
        .inFilter('schedule_entry_id', scheduleIds)
        .gte('lecture_date', _formatDate(startDate))
        .lte('lecture_date', _formatDate(endDate));

    final completedMap = <String, bool>{};

    for (final item in progressResponse) {
      final row = Map<String, dynamic>.from(item as Map);
      final scheduleEntryId = row['schedule_entry_id'].toString();
      final lectureDate = DateTime.parse(
        row['lecture_date'] as String,
      );

      completedMap[_progressKey(scheduleEntryId, lectureDate)] =
          row['completed'] as bool? ?? false;
    }

    final exceptionResponse = await _supabaseService.client
        .from('schedule_exceptions')
        .select(
          'schedule_entry_id, exception_date, exception_type',
        )
        .inFilter('schedule_entry_id', scheduleIds)
        .gte('exception_date', _formatDate(startDate))
        .lte('exception_date', _formatDate(endDate));

    final cancelledOccurrences = <String>{};

    for (final item in exceptionResponse) {
      final row = Map<String, dynamic>.from(item as Map);
      final type =
          row['exception_type']?.toString().toLowerCase().trim() ?? '';

      if (!type.contains('cancel')) {
        continue;
      }

      final scheduleEntryId = row['schedule_entry_id'].toString();
      final exceptionDate = DateTime.parse(
        row['exception_date'] as String,
      );

      cancelledOccurrences.add(
        _progressKey(
          scheduleEntryId,
          exceptionDate,
        ),
      );
    }

    final result = <LectureProgressModel>[
      // Only materialized lecture occurrences whose class has already ended.
      // Future lectures are intentionally not created in student progress.
    ];
    final now = EgyptTime.now();

    for (final entry in scheduleEntries) {
      final dayOfWeek = _toInt(entry['day_of_week']);
      if (dayOfWeek < 1 || dayOfWeek > 7) continue;

      final offering = _mapValue(entry['course_offerings']);
      final course = _mapValue(offering['courses']);
      final scheduleEntryId = entry['id'].toString();
      final courseId = offering['course_id']?.toString() ?? '';
      final courseName = course['name']?.toString() ?? '';
      final instructor =
          entry['instructor']?.toString() ??
          offering['instructor']?.toString() ??
          '';
      final startTime = entry['start_time']?.toString() ?? '';
      final endTime = entry['end_time']?.toString() ?? '';

      if (courseId.isEmpty || courseName.isEmpty) continue;

      var cursor = startDate;
      while (!cursor.isAfter(endDate)) {
        if (cursor.weekday == _databaseDayToWeekday(dayOfWeek)) {
          final date = _dateOnly(cursor);
          final key = _progressKey(scheduleEntryId, date);
          final end = _combineDateAndTime(date, endTime);

          if (!cancelledOccurrences.contains(key) && end.isBefore(now)) {
            result.add(
              LectureProgressModel(
                scheduleEntryId: scheduleEntryId,
                lectureDate: date,
                courseId: courseId,
                courseName: courseName,
                instructor: instructor,
                startTime: startTime,
                endTime: endTime,
                completed: completedMap[key] ?? false,
              ),
            );
          }
        }

        cursor = cursor.add(const Duration(days: 1));
      }
    }

    result.sort((a, b) {
      final dateCompare = a.lectureDate.compareTo(b.lectureDate);
      if (dateCompare != 0) return dateCompare;
      return compareTimeStrings(a.startTime, b.startTime);
    });

    return result;
  }

  Future<void> setLectureCompleted({
    required LectureProgressModel lecture,
    required bool completed,
  }) async {
    final user = _supabaseService.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    await _supabaseService.client
        .from('student_lecture_progress')
        .upsert(
      {
        'student_id': user.id,
        'schedule_entry_id': lecture.scheduleEntryId,
        'lecture_date': _formatDate(
          lecture.lectureDate,
        ),
        'completed': completed,
        'completed_at': completed
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      },
      onConflict:
          'student_id,schedule_entry_id,lecture_date',
    );
  }

  Future<_AcademicContext> _loadAcademicContext() async {
    final termResponse = await _supabaseService.client
        .from('academic_terms')
        .select('id, start_date, end_date, schedule_start_date')
        .eq('is_active', true)
        .maybeSingle();

    if (termResponse == null) {
      throw const PostgrestException(
        message: 'No active academic term found.',
      );
    }

    final termStart = DateTime.parse(termResponse['start_date'] as String);
    final termEnd = DateTime.parse(termResponse['end_date'] as String);
    final scheduleStartDate = DateTime.tryParse(
          termResponse['schedule_start_date']?.toString() ?? '',
        ) ??
        termStart;

    return _AcademicContext(
      termId: termResponse['id'].toString(),
      termStart: termStart,
      termEnd: termEnd,
      scheduleStartDate: scheduleStartDate,
    );
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  int _databaseDayToWeekday(int day) {
    // Database convention: 1=Saturday ... 7=Friday.
    return switch (day) {
      1 => DateTime.saturday,
      2 => DateTime.sunday,
      3 => DateTime.monday,
      4 => DateTime.tuesday,
      5 => DateTime.wednesday,
      6 => DateTime.thursday,
      7 => DateTime.friday,
      _ => DateTime.saturday,
    };
  }

  DateTime _combineDateAndTime(DateTime date, String value) {
    return EgyptTime.at(date, value);
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _progressKey(
    String scheduleEntryId,
    DateTime date,
  ) {
    return '$scheduleEntryId|${_formatDate(date)}';
  }
}

class CourseInfo {
  const CourseInfo({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _AcademicContext {
  const _AcademicContext({
    required this.termId,
    required this.termStart,
    required this.termEnd,
    required this.scheduleStartDate,
  });

  final String termId;
  final DateTime termStart;
  final DateTime termEnd;
  final DateTime scheduleStartDate;
}
