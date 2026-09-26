import '../../domain/repositories/lecture_progress_repository.dart';
import '../datasources/lecture_progress_remote_data_source.dart';
import '../models/course_lecture_progress_model.dart';
import '../models/lecture_progress_model.dart';

class LectureProgressRepositoryImpl
    implements LectureProgressRepository {
  LectureProgressRepositoryImpl({
    LectureProgressRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? LectureProgressRemoteDataSource();

  final LectureProgressRemoteDataSource _remoteDataSource;

  @override
  Future<List<CourseLectureProgressModel>> getCourseProgress() {
    return _remoteDataSource.getCourseProgress();
  }

  @override
  Future<List<LectureProgressModel>> getLectureProgress() {
    return _remoteDataSource.getLectureProgress();
  }

  @override
  Future<void> setLectureCompleted({
    required LectureProgressModel lecture,
    required bool completed,
  }) {
    return _remoteDataSource.setLectureCompleted(
      lecture: lecture,
      completed: completed,
    );
  }
}
