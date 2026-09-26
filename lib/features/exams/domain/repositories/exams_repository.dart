import '../../data/models/exam_model.dart';

abstract class ExamsRepository {
  Future<List<ExamModel>> getExams();
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
  });
  Future<ExamModel> updateExam(ExamModel exam);
  Future<void> deleteExam(String id);
}
