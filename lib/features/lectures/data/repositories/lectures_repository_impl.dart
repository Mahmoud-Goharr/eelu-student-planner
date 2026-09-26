import '../../domain/repositories/lectures_repository.dart';
import '../datasources/lectures_remote_data_source.dart';
import '../models/lecture_model.dart';

class LecturesRepositoryImpl implements LecturesRepository {
  LecturesRepositoryImpl(this._remote);
  final LecturesRemoteDataSource _remote;
  @override
  Future<List<LectureModel>> getLectures() => _remote.getLectures();
  @override
  Future<LectureModel> createLecture(LectureModel lecture) =>
      _remote.createLecture(lecture);
  @override
  Future<LectureModel> updateLecture(LectureModel lecture) =>
      _remote.updateLecture(lecture);
  @override
  Future<void> deleteLecture(String id) => _remote.deleteLecture(id);
}
