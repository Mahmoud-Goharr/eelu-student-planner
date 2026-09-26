import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/course_lecture_progress_model.dart';
import '../../data/models/lecture_progress_model.dart';
import '../../domain/usecases/get_lecture_progress.dart';
import '../../domain/usecases/toggle_lecture_progress.dart';
import 'lecture_progress_state.dart';

class LectureProgressCubit extends Cubit<LectureProgressState> {
  LectureProgressCubit({
    required this.getLectureProgress,
    required this.toggleLectureProgress,
  }) : super(const LectureProgressState());

  final GetLectureProgress getLectureProgress;
  final ToggleLectureProgress toggleLectureProgress;

  Future<void> load() async {
    if (isClosed) return;
    emit(
      state.copyWith(status: LectureProgressStatus.loading, clearError: true),
    );

    try {
      final courses = await getLectureProgress();
      if (isClosed) return;

      emit(
        state.copyWith(
          status: LectureProgressStatus.success,
          courses: courses,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(status: LectureProgressStatus.failure, error: error));
    }
  }

  Future<void> toggleLecture(LectureProgressModel lecture) async {
    if (isClosed) return;
    final newCompleted = !lecture.completed;
    final previousCourses = state.courses;

    final updatedCourses = <CourseLectureProgressModel>[];

    for (final course in previousCourses) {
      if (course.courseId != lecture.courseId) {
        updatedCourses.add(course);
        continue;
      }

      final updatedLectures = course.lectures.map((item) {
        final sameOccurrence =
            item.scheduleEntryId == lecture.scheduleEntryId &&
            _sameDate(item.lectureDate, lecture.lectureDate);

        return sameOccurrence ? item.copyWith(completed: newCompleted) : item;
      }).toList();

      updatedCourses.add(
        CourseLectureProgressModel(
          courseId: course.courseId,
          courseName: course.courseName,
          lectures: List.unmodifiable(updatedLectures),
        ),
      );
    }

    emit(
      state.copyWith(
        status: LectureProgressStatus.updating,
        courses: updatedCourses,
        clearError: true,
      ),
    );

    try {
      await toggleLectureProgress(lecture: lecture, completed: newCompleted);
      if (isClosed) return;

      emit(
        state.copyWith(
          status: LectureProgressStatus.success,
          courses: updatedCourses,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LectureProgressStatus.failure,
          courses: previousCourses,
          error: error,
        ),
      );
    }
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
