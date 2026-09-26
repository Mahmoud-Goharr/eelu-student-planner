import '../../../../core/services/supabase_service.dart';
import '../models/course_model.dart';

class CoursesRemoteDataSource {
  CoursesRemoteDataSource({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<List<CourseModel>> getCourses() async {
    final userId = _service.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Student session not found.');
    }

    final term = await _service.client
        .from('academic_terms')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();

    if (term == null) {
      throw StateError('No active academic term found.');
    }

    final termId = term['id'].toString();

    final selected = await _service.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', termId);

    final selectedIds = selected
        .map((row) => row['course_offering_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (selectedIds.isEmpty) return [];

    final offerings = await _service.client
        .from('course_offerings')
        .select('''
          id,
          course_id,
          instructor,
          instructor_email,
          youtube_playlist_url,
          academic_groups!inner(id,code),
          courses!inner(id,name,level,image_url,materials_url)
        ''')
        .eq('term_id', termId)
        .inFilter('id', selectedIds);

    final result = <CourseModel>[];

    for (final row in offerings as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final course = _mapValue(map['courses']);
      final group = _mapValue(map['academic_groups']);
      final courseId = map['course_id']?.toString() ?? '';

      if (courseId.isEmpty || course['name']?.toString().trim().isEmpty == true) {
        continue;
      }

      result.add(
        CourseModel.fromMap(
          course,
          instructor: map['instructor']?.toString() ?? '',
          instructorEmail: map['instructor_email']?.toString() ?? '',
          youtubePlaylistUrl:
              map['youtube_playlist_url']?.toString() ?? '',
          groupCode: group['code']?.toString() ?? '',
        ),
      );
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
