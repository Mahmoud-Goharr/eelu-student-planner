import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/utils/chronological_sort.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/lecture_model.dart';

class LecturesRemoteDataSource {
  LecturesRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  static const _select = '''
    id,
    course_offering_id,
    day_of_week,
    start_time,
    end_time,
    entry_type,
    delivery_type,
    instructor,
    title,
    created_at,
    course_offerings!inner(
      course_id,
      group_id,
      instructor,
      courses!inner(
        name,
        level
      ),
      academic_groups!inner(
        code,
        level
      )
    )
  ''';

  Future<List<LectureModel>> getLectures() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
      var responseQuery = _supabase.client
          .from('schedule_entries')
          .select(_select);

      final selected = await _supabase.client
          .from('student_course_selections')
          .select('course_offering_id')
          .eq('student_id', user.id);
      final selectedIds = selected
          .map((row) => row['course_offering_id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (selectedIds.isEmpty) return [];

      responseQuery = responseQuery.inFilter(
        'course_offering_id',
        selectedIds,
      );

      final response = await responseQuery
          .order('day_of_week')
          .order('start_time');

      final lectures = (response as List)
          .map((row) => _toLecture(Map<String, dynamic>.from(row as Map)))
          .toList()
        ..sort((a, b) {
          final date = a.date.compareTo(b.date);
          if (date != 0) return date;
          return compareTimeStrings(a.startTime, b.startTime);
        });
      await PlannerCache.instance.saveLectures(user.id, lectures);
      return lectures;
    } catch (_) {
      final cached = await PlannerCache.instance.loadLectures(user.id);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  LectureModel _toLecture(Map<String, dynamic> map) {
    final offering = _mapValue(map['course_offerings']);
    final course = _mapValue(offering['courses']);
    final group = _mapValue(offering['academic_groups']);

    final dayOfWeek = _toInt(map['day_of_week']);
    final date = _nextOccurrence(
      dayOfWeek,
      map['start_time']?.toString() ?? '',
      map['end_time']?.toString() ?? '',
    );

    return LectureModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? course['name']?.toString() ?? '',
      courseId: offering['course_id']?.toString() ?? '',
      courseName: course['name']?.toString() ?? '',
      instructor:
          map['instructor']?.toString() ??
          offering['instructor']?.toString() ??
          '',
      day: _dayName(dayOfWeek),
      date: date,
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      location: map['delivery_type']?.toString() ?? '',
      level: _toInt(course['level'] ?? group['level']),
      section: group['code']?.toString() ?? '',
      description: map['entry_type']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Future<LectureModel> createLecture(LectureModel lecture) {
    throw UnsupportedError('Lectures are managed from the academic schedule.');
  }

  Future<LectureModel> updateLecture(LectureModel lecture) {
    throw UnsupportedError('Lectures are managed from the academic schedule.');
  }

  Future<void> deleteLecture(String id) {
    throw UnsupportedError('Lectures are managed from the academic schedule.');
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _dayName(int dayOfWeek) {
    const days = <String>[
      '',
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

    return dayOfWeek >= 1 && dayOfWeek <= 7 ? days[dayOfWeek] : '';
  }

  static DateTime _nextOccurrence(
    int dayOfWeek,
    String startTime,
    String endTime,
  ) {
    final today = EgyptTime.now();
    final current = today.weekday;
    final target = switch (dayOfWeek) {
      1 => DateTime.saturday,
      2 => DateTime.sunday,
      3 => DateTime.monday,
      4 => DateTime.tuesday,
      5 => DateTime.wednesday,
      6 => DateTime.thursday,
      7 => DateTime.friday,
      _ => DateTime.saturday,
    };

    var daysUntil = target - current;
    if (daysUntil < 0) daysUntil += 7;

    var date = DateTime(
      today.year,
      today.month,
      today.day + daysUntil,
    );

    DateTime combine(String value) => EgyptTime.at(date, value);

    if (!combine(endTime).isAfter(today)) {
      date = date.add(const Duration(days: 7));
    }

    return date;
  }

}
