import '../../data/models/course_lecture_progress_model.dart';
import '../../data/models/lecture_progress_model.dart';

abstract class LectureProgressRepository {
  Future<List<CourseLectureProgressModel>> getCourseProgress();

  Future<List<LectureProgressModel>> getLectureProgress();

  Future<void> setLectureCompleted({
    required LectureProgressModel lecture,
    required bool completed,
  });
}
