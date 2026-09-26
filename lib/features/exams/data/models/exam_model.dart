class ExamModel {
  const ExamModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.type,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    required this.level,
    required this.section,
    this.createdAt,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String type;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final int level;
  final String section;
  final DateTime? createdAt;

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    return ExamModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      courseName:
          map['course_name']?.toString() ?? map['course_id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'final',
      date: parseDate(map['date']),
      startTime: parseDate(map['start_time']),
      endTime: parseDate(map['end_time']),
      location: map['location']?.toString(),
      description: map['description']?.toString(),
      level: (map['level'] as num?)?.toInt() ?? 3,
      section: map['section']?.toString() ?? 'C&D',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'course_id': courseId,
    'course_name': courseName,
    'type': type,
    'date': date.toIso8601String(),
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'location': location,
    'description': description,
    'level': level,
    'section': section,
    'created_at': createdAt?.toIso8601String(),
  };

  ExamModel copyWith({
    String? id,
    String? courseId,
    String? courseName,
    String? type,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    int? level,
    String? section,
    DateTime? createdAt,
  }) => ExamModel(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    courseName: courseName ?? this.courseName,
    type: type ?? this.type,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    location: location ?? this.location,
    description: description ?? this.description,
    level: level ?? this.level,
    section: section ?? this.section,
    createdAt: createdAt ?? this.createdAt,
  );
}
