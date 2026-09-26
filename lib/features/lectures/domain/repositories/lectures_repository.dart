import '../../data/models/lecture_model.dart';

abstract class LecturesRepository {
  Future<List<LectureModel>> getLectures();
  Future<LectureModel> createLecture(LectureModel lecture);
  Future<LectureModel> updateLecture(LectureModel lecture);
  Future<void> deleteLecture(String id);
}
