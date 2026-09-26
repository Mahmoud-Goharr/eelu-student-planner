import '../../domain/entities/course.dart';

enum CoursesStatus { initial, loading, success, failure }

class CoursesState {
  const CoursesState({
    this.status = CoursesStatus.initial,
    this.courses = const [],
    this.errorMessage,
  });

  final CoursesStatus status;
  final List<Course> courses;
  final String? errorMessage;

  CoursesState copyWith({
    CoursesStatus? status,
    List<Course>? courses,
    String? errorMessage,
  }) {
    return CoursesState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      errorMessage: errorMessage,
    );
  }
}
