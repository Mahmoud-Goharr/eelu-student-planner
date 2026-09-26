import '../../data/models/lecture_progress_model.dart';
import '../repositories/lecture_progress_repository.dart';

class ToggleLectureProgress {
  const ToggleLectureProgress(this._repository);

  final LectureProgressRepository _repository;

  Future<void> call({
    required LectureProgressModel lecture,
    required bool completed,
  }) {
    return _repository.setLectureCompleted(
      lecture: lecture,
      completed: completed,
    );
  }
}
