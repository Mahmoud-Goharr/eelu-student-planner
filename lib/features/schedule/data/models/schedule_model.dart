class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.instructor,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.level,
    required this.section,
    required this.imageUrl,
    required this.scheduleStartDate,
    required this.scheduleEndDate,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String instructor;
  final String day;
  final String startTime;
  final String endTime;
  final int level;
  final String section;
  final String imageUrl;
  final DateTime scheduleStartDate;
  final DateTime scheduleEndDate;

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    final offering = _mapValue(map['course_offerings']);
    final course = _mapValue(offering['courses']);
    final group = _mapValue(offering['academic_groups']);
    final term = _mapValue(offering['academic_terms']);

    final dayOfWeek = _toInt(map['day_of_week']);

    return ScheduleModel(
      id: map['id']?.toString() ?? '',
      courseId: offering['course_id']?.toString() ?? '',
      courseName: course['name']?.toString() ?? '',
      instructor:
          map['instructor']?.toString() ??
          offering['instructor']?.toString() ??
          '',
      day: _dayName(dayOfWeek),
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      level: _toInt(course['level']) != 0
          ? _toInt(course['level'])
          : _toInt(group['level']),
      section: group['code']?.toString() ?? '',
      imageUrl: course['image_url']?.toString() ?? '',
      scheduleStartDate: DateTime.tryParse(
            term['schedule_start_date']?.toString() ?? '',
          ) ??
          DateTime(2026, 9, 26),
      scheduleEndDate: DateTime.tryParse(
            term['end_date']?.toString() ?? '',
          ) ??
          DateTime(2027, 1, 31),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'course_id': courseId,
        'course_name': courseName,
        'instructor': instructor,
        'day': day,
        'start_time': startTime,
        'end_time': endTime,
        'level': level,
        'section': section,
        'image_url': imageUrl,
        'schedule_start_date': scheduleStartDate.toIso8601String(),
        'schedule_end_date': scheduleEndDate.toIso8601String(),
      };

  factory ScheduleModel.fromCacheMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      courseName: map['course_name']?.toString() ?? '',
      instructor: map['instructor']?.toString() ?? '',
      day: map['day']?.toString() ?? '',
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      level: int.tryParse(map['level']?.toString() ?? '') ?? 0,
      section: map['section']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      scheduleStartDate: DateTime.tryParse(
            map['schedule_start_date']?.toString() ?? '',
          ) ??
          DateTime(2026, 9, 26),
      scheduleEndDate: DateTime.tryParse(
            map['schedule_end_date']?.toString() ?? '',
          ) ??
          DateTime(2027, 1, 31),
    );
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _dayName(int dayOfWeek) {
    // Database day_of_week is Saturday-based: 1=Saturday ... 7=Friday.
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
}
