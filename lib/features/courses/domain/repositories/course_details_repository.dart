import '../entities/course_details.dart';

abstract class CourseDetailsRepository {
  Future<CourseDetails> getDetails({
    required String courseId,
    required String courseName,
  });
}
