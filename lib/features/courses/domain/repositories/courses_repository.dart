import '../entities/course.dart';

abstract class CoursesRepository {
  Future<List<Course>> getCourses();
}
