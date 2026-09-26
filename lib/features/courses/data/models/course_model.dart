import '../../domain/entities/course.dart';

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.code,
    required super.name,
    required super.level,
    required super.instructor,
    super.instructorEmail,
    super.youtubePlaylistUrl,
    required super.materialsUrl,
    required super.imageUrl,
    required super.groupCode,
  });

  factory CourseModel.fromMap(
    Map<String, dynamic> map, {
    String instructor = '',
    String instructorEmail = '',
    String youtubePlaylistUrl = '',
    String groupCode = '',
  }) {
    final name = map['name']?.toString().trim() ?? '';

    return CourseModel(
      id: map['id']?.toString() ?? '',
      code: _code(map['code'], name),
      name: name,
      level: _toInt(map['level']),
      instructor: instructor.trim().isEmpty ? '-' : instructor.trim(),
      instructorEmail: _nullable(instructorEmail),
      youtubePlaylistUrl: _nullable(youtubePlaylistUrl),
      materialsUrl: _nullable(map['materials_url']),
      imageUrl: _nullable(map['image_url']),
      groupCode: groupCode.trim(),
    );
  }

  static String _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text;
  }

  static int _toInt(Object? value) {
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  static String _code(Object? value, String name) {
    final code = value?.toString().trim() ?? '';
    if (code.isNotEmpty) return code;
    final words = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = words.toList();
    if (list.length == 1) {
      return list.first.substring(0, list.first.length.clamp(1, 4)).toUpperCase();
    }
    return list.map((e) => e[0]).join().toUpperCase();
  }
}
