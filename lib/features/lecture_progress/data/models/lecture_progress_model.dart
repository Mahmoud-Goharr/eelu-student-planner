class LectureProgressModel {
  const LectureProgressModel({
    required this.scheduleEntryId,
    required this.lectureDate,
    required this.courseId,
    required this.courseName,
    required this.instructor,
    required this.startTime,
    required this.endTime,
    required this.completed,
  });

  final String scheduleEntryId;
  final DateTime lectureDate;
  final String courseId;
  final String courseName;
  final String instructor;
  final String startTime;
  final String endTime;
  final bool completed;

  LectureProgressModel copyWith({
    String? scheduleEntryId,
    DateTime? lectureDate,
    String? courseId,
    String? courseName,
    String? instructor,
    String? startTime,
    String? endTime,
    bool? completed,
  }) {
    return LectureProgressModel(
      scheduleEntryId: scheduleEntryId ?? this.scheduleEntryId,
      lectureDate: lectureDate ?? this.lectureDate,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      instructor: instructor ?? this.instructor,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      completed: completed ?? this.completed,
    );
  }
}
