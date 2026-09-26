class CourseSelectionOption {
  const CourseSelectionOption({
    required this.offeringId,
    required this.courseId,
    required this.courseName,
    required this.instructor,
    required this.groupCode,
  });

  final String offeringId;
  final String courseId;
  final String courseName;
  final String instructor;
  final String groupCode;
}
