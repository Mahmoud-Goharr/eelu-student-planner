import '../../data/models/course_lecture_progress_model.dart';
import '../../data/models/lecture_progress_model.dart';

enum LectureProgressStatus {
  initial,
  loading,
  success,
  failure,
  updating,
}

class LectureProgressState {
  const LectureProgressState({
    this.status = LectureProgressStatus.initial,
    this.courses = const [],
    this.error,
  });

  final LectureProgressStatus status;
  final List<CourseLectureProgressModel> courses;
  final Object? error;

  List<LectureProgressModel> get lectures => [
        for (final course in courses) ...course.lectures,
      ];

  int get completedCount =>
      courses.fold(0, (total, course) => total + course.completedCount);

  int get totalCount =>
      courses.fold(0, (total, course) => total + course.totalCount);

  double get progress {
    if (totalCount == 0) {
      return 0;
    }

    return completedCount / totalCount;
  }

  CourseLectureProgressModel? courseById(String courseId) {
    for (final course in courses) {
      if (course.courseId == courseId) {
        return course;
      }
    }

    return null;
  }

  LectureProgressState copyWith({
    LectureProgressStatus? status,
    List<CourseLectureProgressModel>? courses,
    Object? error,
    bool clearError = false,
  }) {
    return LectureProgressState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
