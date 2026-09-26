import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/course_details_repository.dart';
import 'course_details_state.dart';

class CourseDetailsCubit extends Cubit<CourseDetailsState> {
  CourseDetailsCubit(this._repository) : super(const CourseDetailsState());

  final CourseDetailsRepository _repository;

  Future<void> load({
    required String courseId,
    required String courseName,
  }) async {
    if (isClosed) return;

    emit(state.copyWith(status: CourseDetailsStatus.loading));

    try {
      final data = await _repository.getDetails(
        courseId: courseId,
        courseName: courseName,
      );

      // The screen may have been closed while the request was running.
      if (isClosed) return;

      emit(state.copyWith(status: CourseDetailsStatus.success, data: data));
    } catch (error) {
      // Do not emit after the Cubit has been disposed.
      if (isClosed) return;

      emit(
        state.copyWith(
          status: CourseDetailsStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
