import 'lecture_progress_model.dart';

class CourseLectureProgressModel {
  const CourseLectureProgressModel({
    required this.courseId,
    required this.courseName,
    required this.lectures,
  });

  final String courseId;
  final String courseName;
  final List<LectureProgressModel> lectures;

  int get totalCount => lectures.length;

  int get completedCount =>
      lectures.where((lecture) => lecture.completed).length;

  double get progress {
    if (totalCount == 0) {
      return 0;
    }

    return completedCount / totalCount;
  }
}
