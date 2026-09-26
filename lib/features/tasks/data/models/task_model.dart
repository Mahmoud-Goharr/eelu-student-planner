class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.courseId = '',
    required this.dueDate,
    required this.type,
    this.priority = 'medium',
    required this.isCompleted,
    this.level = 0,
    this.section = '',
    this.isPersonal = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String courseId;
  final DateTime dueDate;
  final String type;
  final String priority;
  final bool isCompleted;
  final int level;
  final String section;
  final bool isPersonal;
  final DateTime? createdAt;

  bool get isAcademic => !isPersonal;

  bool get canToggleCompletion =>
      type == 'assignment' ||
      type == 'quiz' ||
      type == 'personal_assignment';

  bool get canEdit => isPersonal;

  bool get canDelete => isPersonal;

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      courseId: map['course_id']?.toString() ?? '',
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? '') ??
          DateTime.now(),
      type: map['type']?.toString() ?? 'assignment',
      priority: map['priority']?.toString() ?? 'medium',
      isCompleted: map['is_completed'] as bool? ?? false,
      level: (map['level'] as num?)?.toInt() ?? 0,
      section: map['section']?.toString() ?? '',
      isPersonal: map['is_personal'] as bool? ?? false,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'course_id': courseId,
      'due_date': dueDate.toIso8601String(),
      'type': type,
      'priority': priority,
      'is_completed': isCompleted,
      'level': level,
      'section': section,
      'is_personal': isPersonal,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? courseId,
    DateTime? dueDate,
    String? type,
    String? priority,
    bool? isCompleted,
    int? level,
    String? section,
    bool? isPersonal,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      courseId: courseId ?? this.courseId,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      level: level ?? this.level,
      section: section ?? this.section,
      isPersonal: isPersonal ?? this.isPersonal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
