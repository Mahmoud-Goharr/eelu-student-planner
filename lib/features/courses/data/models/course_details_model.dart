import '../../domain/entities/course_details.dart';

class CourseDetailsModel extends CourseDetails {
  const CourseDetailsModel({
    required super.instructors,
    required super.tasks,
    required super.quizzes,
    required super.exams,
    required super.lectures,
  });

  factory CourseDetailsModel.fromParts({
    required List<CourseInstructor> instructors,
    required List<CourseDetailsItem> tasks,
    required List<CourseDetailsItem> quizzes,
    required List<CourseDetailsItem> exams,
    required List<CourseDetailsItem> lectures,
  }) {
    return CourseDetailsModel(
      instructors: instructors,
      tasks: tasks,
      quizzes: quizzes,
      exams: exams,
      lectures: lectures,
    );
  }
}
