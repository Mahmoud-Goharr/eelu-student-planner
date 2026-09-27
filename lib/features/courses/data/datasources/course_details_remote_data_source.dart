import '../../../../core/services/supabase_service.dart';
import '../../../../core/cache/planner_cache.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../domain/entities/course_details.dart';
import '../models/course_details_model.dart';

class CourseDetailsRemoteDataSource {
  CourseDetailsRemoteDataSource({SupabaseService? service})
    : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<CourseDetailsModel> getDetails({
    required String courseId,
    required String courseName,
  }) async {
    final context = await _academicContext();
    final userId = _service.client.auth.currentUser!.id;

    final selectedRows = await _service.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', context.termId);

    final selectedIds = selectedRows
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final selectedOfferingRows = selectedIds.isEmpty
        ? <dynamic>[]
        : await _service.client
            .from('course_offerings')
            .select('id,instructor,instructor_email,youtube_playlist_url,materials_url,course_id,group_id')
            .eq('term_id', context.termId)
            .eq('course_id', courseId)
            .inFilter('id', selectedIds);

    final selectedOffering = selectedOfferingRows.isEmpty
        ? null
        : Map<String, dynamic>.from(selectedOfferingRows.first as Map);

    if (selectedOffering == null) {
      return CourseDetailsModel.fromParts(
        instructors: const [],
        tasks: const [],
        quizzes: const [],
        exams: await _exams(courseId),
        lectures: const [],
      );
    }

    final offeringId = selectedOffering['id'].toString();

    final allOfferingRows = await _service.client
        .from('course_offerings')
        .select(
          'id,instructor,instructor_email,youtube_playlist_url,materials_url,course_id,group_id',
        )
        .eq('term_id', context.termId)
        .eq('course_id', courseId);

    final groupIds = (allOfferingRows as List)
        .map((row) => (row as Map)['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final groupRows = groupIds.isEmpty
        ? <dynamic>[]
        : await _service.client
            .from('academic_groups')
            .select('id,code')
            .inFilter('id', groupIds);

    final groupCodeById = <String, String>{
      for (final row in groupRows as List)
        if ((row as Map)['id'] != null)
          row['id'].toString(): row['code']?.toString().trim() ?? '',
    };

    final instructors = <CourseInstructor>[];
    final instructorIndex = <String, int>{};

    for (final raw in allOfferingRows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final name = row['instructor']?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      final email = row['instructor_email']?.toString().trim();
      final youtubeUrl = _cleanUrl(row['youtube_playlist_url']);
      final materialUrl = _cleanUrl(row['materials_url']);
      // Keep separate instructor entries when the same instructor has
      // different YouTube playlists. This is important for A/B vs C/D.
      final key = [
        name.toLowerCase(),
        (email ?? '').toLowerCase(),
        youtubeUrl ?? '',
      ].join('|');
      final groupCode = groupCodeById[row['group_id']?.toString() ?? ''] ?? '';
      final isStudent = row['id']?.toString() == offeringId;

      final existingIndex = instructorIndex[key];
      if (existingIndex == null) {
        instructorIndex[key] = instructors.length;
        instructors.add(
          CourseInstructor(
            name: name,
            email: email?.isEmpty == true ? null : email,
            groupCodes: groupCode.isEmpty ? const [] : [groupCode],
            youtubePlaylistUrl: youtubeUrl,
            materialsUrl: materialUrl,
            isStudentInstructor: isStudent,
          ),
        );
      } else {
        final current = instructors[existingIndex];
        final groups = {...current.groupCodes, if (groupCode.isNotEmpty) groupCode}.toList()..sort();
        instructors[existingIndex] = CourseInstructor(
          name: current.name,
          email: current.email,
          groupCodes: groups,
          youtubePlaylistUrl: current.youtubePlaylistUrl ?? youtubeUrl,
          materialsUrl: current.materialsUrl ?? materialUrl,
          isStudentInstructor: current.isStudentInstructor || isStudent,
        );
      }
    }

    instructors.sort((a, b) {
      if (a.isStudentInstructor != b.isStudentInstructor) {
        return a.isStudentInstructor ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    final tasksFuture = _assignments(courseId);
    final quizzesFuture = _quizzes(offeringId, context.termId);
    final examsFuture = _exams(courseId);
    final lecturesFuture = _lectures(
      offeringId,
      context.termId,
      context.scheduleStartDate,
    );

    final results = await Future.wait<List<CourseDetailsItem>>([
      tasksFuture,
      quizzesFuture,
      examsFuture,
      lecturesFuture,
    ]);

    return CourseDetailsModel.fromParts(
      instructors: instructors,
      tasks: results[0],
      quizzes: results[1],
      exams: results[2],
      lectures: results[3],
    );
  }

  String? _cleanUrl(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<List<CourseDetailsItem>> _assignments(String courseId) async {
    final rows = await _service.client
        .from('assignments')
        .select('id,name,due_date')
        .eq('course_id', courseId)
        .order('due_date');

    final userId = _service.client.auth.currentUser?.id;
    final progressRows = userId == null
        ? const <dynamic>[]
        : await _service.client
            .from('student_assignment_progress')
            .select('assignment_id,is_completed')
            .eq('student_id', userId);

    final progress = <String, bool>{
      for (final row in progressRows as List)
        row['assignment_id']?.toString() ?? '':
            row['is_completed'] as bool? ?? false,
    };

    final now = EgyptTime.now();
    final items = (rows as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final assignmentId = map['id']?.toString() ?? '';
          final date = DateTime.tryParse(map['due_date']?.toString() ?? '');
          return CourseDetailsItem(
            title: map['name']?.toString() ?? '',
            subtitle: _dateTime(map['due_date']),
            date: date,
            isCompleted: progress[assignmentId] ?? false,
          );
        })
        .where((item) => item.date != null && !item.date!.isBefore(now))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    return items;
  }

  Future<List<CourseDetailsItem>> _quizzes(
    String offeringId,
    String termId,
  ) async {
    final rows = await _service.client
        .from('quizzes')
        .select(
          'id,title,quiz_date,lecture_start_time,'
          'course_offerings!inner(course_id,group_id,term_id)',
        )
        .eq('offering_id', offeringId)
        .eq('course_offerings.term_id', termId);

    final userId = _service.client.auth.currentUser?.id;
    final completions = userId == null
        ? <String, bool>{}
        : await PlannerCache.instance.loadCompletions(userId);

    final now = EgyptTime.now();
    final items = <CourseDetailsItem>[];

    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final date = DateTime.tryParse(map['quiz_date']?.toString() ?? '');
      final time = map['lecture_start_time']?.toString();
      final parsedTime = time == null || date == null
          ? null
          : DateTime.tryParse(
              '${date.toIso8601String().split('T').first}T$time',
            );

      final quizId = map['id']?.toString() ?? '';
      items.add(
        CourseDetailsItem(
          title: map['title']?.toString() ?? 'Quiz',
          subtitle: [
            if (date != null) _date(date),
            if (parsedTime != null) _time(parsedTime),
          ].join(' • '),
          date: parsedTime ?? date,
          isCompleted: completions['quiz:$quizId'] ?? false,
        ),
      );
    }

    final upcoming = items
        .where((item) => item.date != null && !item.date!.isBefore(now))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    return upcoming;
  }

  Future<List<CourseDetailsItem>> _exams(String courseId) async {
    final exams = await _service.client
        .from('exams')
        .select('id,type,exam_date,exam_time')
        .eq('course_id', courseId)
        .order('exam_date')
        .order('exam_time');

    final userId = _service.client.auth.currentUser?.id;
    final completions = userId == null
        ? <String, bool>{}
        : await PlannerCache.instance.loadCompletions(userId);

    final now = EgyptTime.now();

    final items = (exams as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);

          final date = DateTime.tryParse(map['exam_date']?.toString() ?? '');

          final time = map['exam_time']?.toString();

          DateTime? examDateTime;

          if (date != null && time != null) {
            final parts = time.split(':');

            if (parts.length >= 2) {
              examDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.tryParse(parts[0]) ?? 0,
                int.tryParse(parts[1]) ?? 0,
                parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
              );
            }
          }

          final examId = map['id']?.toString() ?? '';

          return CourseDetailsItem(
            title: map['type']?.toString() ?? 'Exam',
            subtitle: [
              if (date != null) _date(date),
              if (examDateTime != null) _time(examDateTime),
            ].join(' • '),
            date: examDateTime ?? date,
            isCompleted: completions['exam:$examId'] ?? false,
          );
        })
        .where((item) => item.date != null && !item.date!.isBefore(now))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    return items;
  }

  Future<List<CourseDetailsItem>> _lectures(
    String offeringId,
    String termId,
    DateTime scheduleStartDate,
  ) async {
    final rows = await _service.client
        .from('schedule_entries')
        .select(
          'day_of_week,start_time,end_time,instructor,title,delivery_type,'
          'course_offerings!inner(course_id,group_id,term_id)',
        )
        .eq('course_offering_id', offeringId)
        .eq('course_offerings.term_id', termId)
        .order('day_of_week')
        .order('start_time');

    final now = EgyptTime.now();
    final items = <CourseDetailsItem>[];

    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final occurrence = _nextOccurrence(
        scheduleStartDate: scheduleStartDate,
        databaseDay: map['day_of_week'],
        startTime: map['start_time'],
        endTime: map['end_time'],
        now: now,
      );

      if (occurrence == null) continue;

      items.add(
        CourseDetailsItem(
          title: map['title']?.toString().trim().isNotEmpty == true
              ? map['title'].toString()
              : 'Lecture',
          subtitle: _scheduleTime(
            map['start_time'],
            map['end_time'],
            map['instructor'],
            map['delivery_type'],
          ),
          date: occurrence,
        ),
      );
    }

    items.sort((a, b) => a.date!.compareTo(b.date!));
    return items;
  }

  Future<_AcademicContext> _academicContext() async {
    final userId = _service.client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Student session not found.');
    }

    final term = await _service.client
        .from('academic_terms')
        .select('id,schedule_start_date')
        .eq('is_active', true)
        .maybeSingle();

    if (term == null) {
      throw StateError('No active academic term found.');
    }

    final selected = await _service.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', term['id']);

    final selectedIds = selected
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (selectedIds.isEmpty) {
      throw StateError('No courses selected.');
    }

    final scheduleStartDate = DateTime.tryParse(
          term['schedule_start_date']?.toString() ?? '',
        ) ??
        DateTime(2026, 9, 26);

    return _AcademicContext(
      term['id'].toString(),
      scheduleStartDate,
    );
  }

  String _scheduleTime(
    Object? start,
    Object? end,
    Object? instructor,
    Object? mode,
  ) {
    final values = [
      _timeString(start),
      _timeString(end),
      if ((instructor?.toString().trim() ?? '').isNotEmpty)
        instructor.toString().trim(),
      if ((mode?.toString().trim() ?? '').isNotEmpty) mode.toString().trim(),
    ];

    return values.join(' • ');
  }


  String _timeString(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';

    final parts = text.split(':');
    if (parts.length < 2) return text;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) return text;

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _dateTime(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    return date == null ? '' : _date(date);
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

  String _time(DateTime value) {
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    final displayHour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$displayHour:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
  DateTime? _nextOccurrence({
    required DateTime scheduleStartDate,
    required Object? databaseDay,
    required Object? startTime,
    required Object? endTime,
    required DateTime now,
  }) {
    final day = int.tryParse(databaseDay?.toString() ?? '');
    if (day == null || day < 1 || day > 7) return null;

    // Database convention: 1=Saturday ... 7=Friday.
    final targetWeekday = switch (day) {
      1 => DateTime.saturday,
      2 => DateTime.sunday,
      3 => DateTime.monday,
      4 => DateTime.tuesday,
      5 => DateTime.wednesday,
      6 => DateTime.thursday,
      7 => DateTime.friday,
      _ => DateTime.saturday,
    };
    var date = DateTime(
      scheduleStartDate.year,
      scheduleStartDate.month,
      scheduleStartDate.day,
    );

    while (date.weekday != targetWeekday) {
      date = date.add(const Duration(days: 1));
    }

    final today = DateTime(now.year, now.month, now.day);
    while (date.isBefore(today)) {
      date = date.add(const Duration(days: 7));
    }

    final start = _combineDateAndTime(date, startTime);
    final end = _combineDateAndTime(date, endTime);

    if (!end.isAfter(now)) {
      date = date.add(const Duration(days: 7));
      return _combineDateAndTime(date, startTime);
    }

    if (!start.isAfter(now)) {
      return end.isAfter(now) ? start : null;
    }

    return start;
  }

  DateTime _combineDateAndTime(DateTime date, Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return date;
    return EgyptTime.at(date, text);
  }

}

class _AcademicContext {
  const _AcademicContext(this.termId, this.scheduleStartDate);

  final String termId;
  final DateTime scheduleStartDate;

}
