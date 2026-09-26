class LectureModel {
  const LectureModel({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.instructor,
    required this.day,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.level,
    required this.section,
    this.description,
    this.createdAt,
  });

  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final String instructor;
  final String day;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String location;
  final int level;
  final String section;
  final String? description;
  final DateTime? createdAt;

  factory LectureModel.fromMap(Map<String, dynamic> map) => LectureModel(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    courseId: map['course_id']?.toString() ?? '',
    courseName:
        map['course_name']?.toString() ?? map['course_id']?.toString() ?? '',
    instructor: map['instructor']?.toString() ?? '',
    day: map['day']?.toString() ?? '',
    date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    startTime: map['start_time']?.toString() ?? '09:00',
    endTime: map['end_time']?.toString() ?? '10:00',
    location: map['location']?.toString() ?? '',
    level: (map['level'] as num?)?.toInt() ?? 3,
    section: map['section']?.toString() ?? 'C&D',
    description: map['description']?.toString(),
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'course_id': courseId,
    'course_name': courseName,
    'instructor': instructor,
    'day': day,
    'date': date.toIso8601String(),
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
    'level': level,
    'section': section,
    'description': description,
  };

  LectureModel copyWith({
    String? id,
    String? title,
    String? courseId,
    String? courseName,
    String? instructor,
    String? day,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? location,
    int? level,
    String? section,
    Object? description = _keepDescription,
    DateTime? createdAt,
  }) => LectureModel(
    id: id ?? this.id,
    title: title ?? this.title,
    courseId: courseId ?? this.courseId,
    courseName: courseName ?? this.courseName,
    instructor: instructor ?? this.instructor,
    day: day ?? this.day,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    location: location ?? this.location,
    level: level ?? this.level,
    section: section ?? this.section,
    description: identical(description, _keepDescription)
        ? this.description
        : description as String?,
    createdAt: createdAt ?? this.createdAt,
  );

  static const _keepDescription = Object();
}
