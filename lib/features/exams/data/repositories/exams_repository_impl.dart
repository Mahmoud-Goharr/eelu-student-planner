import '../../domain/repositories/exams_repository.dart';
import '../datasources/exams_remote_data_source.dart';
import '../models/exam_model.dart';

class ExamsRepositoryImpl implements ExamsRepository {
  ExamsRepositoryImpl(this._remoteDataSource);
  final ExamsRemoteDataSource _remoteDataSource;

  @override
  Future<List<ExamModel>> getExams() => _remoteDataSource.getExams();
  @override
  Future<ExamModel> createExam({
    required String courseId,
    required String courseName,
    required String type,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required int level,
    required String section,
  }) => _remoteDataSource.createExam(
    courseId: courseId,
    courseName: courseName,
    type: type,
    date: date,
    startTime: startTime,
    endTime: endTime,
    location: location,
    level: level,
    section: section,
  );
  @override
  Future<ExamModel> updateExam(ExamModel exam) =>
      _remoteDataSource.updateExam(exam);
  @override
  Future<void> deleteExam(String id) => _remoteDataSource.deleteExam(id);
}
