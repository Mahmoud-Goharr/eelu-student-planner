import '../../data/models/course_lecture_progress_model.dart';
import '../repositories/lecture_progress_repository.dart';

class GetLectureProgress {
  const GetLectureProgress(this._repository);

  final LectureProgressRepository _repository;

  Future<List<CourseLectureProgressModel>> call() {
    return _repository.getCourseProgress();
  }
}
