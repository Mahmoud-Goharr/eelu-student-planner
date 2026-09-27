import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/exam_model.dart';

class ExamsRemoteDataSource {
  ExamsRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  Future<List<ExamModel>> getExams() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
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

      developer.log(
        'Exam enrollment query; selectedOfferings=${selectedOfferingIds.length}.',
        name: 'NotificationDebug',
      );

      if (selectedOfferingIds.isEmpty) {
        return [];
      }

      final selectedOfferings = await _supabase.client
          .from('course_offerings')
          .select('course_id')
          .inFilter('id', selectedOfferingIds);

      final selectedCourseIds = selectedOfferings
          .map((row) => row['course_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      developer.log(
        'Exam query enrollment counts; selectedOfferings=${selectedOfferingIds.length}; '
        'selectedCourses=${selectedCourseIds.length}',
        name: 'NotificationDebug',
      );

      if (selectedCourseIds.isEmpty) {
        return [];
      }

      final response = await _supabase.client
          .from('exams')
          .select(
            'id,course_id,type,exam_date,exam_time,description,created_at,'
            'courses(name,level)',
          )
          .inFilter('course_id', selectedCourseIds.toList())
          .order('exam_date')
          .order('exam_time');

      final exams = (response as List)
          .map((row) => _toExam(Map<String, dynamic>.from(row as Map)))
          .toList();

      final invalidExamDateTimes = (response as List)
          .where((row) {
            final map = row as Map;
            return DateTime.tryParse(map['exam_date']?.toString() ?? '') ==
                    null ||
                (map['exam_time']?.toString().isEmpty ?? true);
          })
          .length;

      developer.log(
        'Exam query returned ${exams.length} records; '
        'invalidExamDateTimes=$invalidExamDateTimes',
        name: 'NotificationDebug',
      );

      await PlannerCache.instance.saveExams(user.id, exams);
      for (final exam in exams) {
        if (!exam.startTime.isAfter(EgyptTime.now())) {
          await PlannerCache.instance.archiveExam(user.id, exam);
        }
      }

      return exams;
    } catch (error) {
      final cached = await PlannerCache.instance.loadExams(user.id);
      developer.log(
        'Exam query failed; errorType=${error.runtimeType}; '
        'cachedExams=${cached.length}; usingCache=${cached.isNotEmpty}',
        name: 'NotificationDebug',
      );
      if (cached.isEmpty) rethrow;
      for (final exam in cached) {
        if (!exam.startTime.isAfter(EgyptTime.now())) {
          await PlannerCache.instance.archiveExam(user.id, exam);
        }
      }
      return cached;
    }
  }

  ExamModel _toExam(Map<String, dynamic> map) {
    final course = _mapValue(map['courses']);

    final date = _parseDate(map['exam_date']);
    final startTime = _combineDateAndTime(date, map['exam_time']?.toString());

    return ExamModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      courseName: course['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'final',
      date: date,
      startTime: startTime,
      endTime: startTime,
      location: null,
      level: _toInt(course['level']),
      section: '',
      description: map['description']?.toString(),
      createdAt: _parseNullableDate(map['created_at']),
    );
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

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? EgyptTime.now();
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static DateTime _combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) return date;
    return EgyptTime.at(date, time);
  }

  Future<ExamModel> createExam({
    required String courseId,
    required String courseName,
    required String type,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required int level,
    required String section,
  }) async {
    final response = await _supabase.client
        .from('exams')
        .insert({
          'course_id': courseId,
          'type': type,
          'exam_date':
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
          'exam_time':
              '${startTime.hour.toString().padLeft(2, '0')}:'
              '${startTime.minute.toString().padLeft(2, '0')}:'
              '${startTime.second.toString().padLeft(2, '0')}',
        })
        .select(
          'id,course_id,type,exam_date,exam_time,description,created_at,'
          'courses(name,level)',
        )
        .single();

    return _toExam(Map<String, dynamic>.from(response as Map));
  }

  Future<ExamModel> updateExam(ExamModel exam) async {
    final response = await _supabase.client
        .from('exams')
        .update({
          'course_id': exam.courseId,
          'type': exam.type,
          'exam_date':
              '${exam.date.year.toString().padLeft(4, '0')}-'
              '${exam.date.month.toString().padLeft(2, '0')}-'
              '${exam.date.day.toString().padLeft(2, '0')}',
          'exam_time':
              '${exam.startTime.hour.toString().padLeft(2, '0')}:'
              '${exam.startTime.minute.toString().padLeft(2, '0')}:'
              '${exam.startTime.second.toString().padLeft(2, '0')}',
        })
        .eq('id', exam.id)
        .select(
          'id,course_id,type,exam_date,exam_time,description,created_at,'
          'courses(name,level)',
        )
        .single();

    return _toExam(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteExam(String id) async {
    await _supabase.client.from('exams').delete().eq('id', id);
  }
}
