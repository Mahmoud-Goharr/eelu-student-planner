import '../../domain/entities/course_details.dart';

enum CourseDetailsStatus { initial, loading, success, failure }

class CourseDetailsState {
  const CourseDetailsState({
    this.status = CourseDetailsStatus.initial,
    this.data,
    this.errorMessage,
  });

  final CourseDetailsStatus status;
  final CourseDetails? data;
  final String? errorMessage;

  CourseDetailsState copyWith({
    CourseDetailsStatus? status,
    CourseDetails? data,
    String? errorMessage,
  }) {
    return CourseDetailsState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }
}
