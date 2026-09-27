import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';

import '../../../profile/presentation/sync/profile_sync_bus.dart';

import '../../domain/repositories/courses_repository.dart';
import 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit(this._repository) : super(const CoursesState()) {
    _profileSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) getCourses();
    });
  }

  final CoursesRepository _repository;
  StreamSubscription<void>? _profileSubscription;

  Future<void> getCourses() async {
    emit(state.copyWith(status: CoursesStatus.loading));
    try {
      emit(state.copyWith(
        status: CoursesStatus.success,
        courses: await _repository.getCourses(),
      ));
    } catch (error) {
      emit(state.copyWith(
        status: CoursesStatus.failure,
        errorMessage: AppErrorLocalizer.code(error),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _profileSubscription?.cancel();
    return super.close();
  }
}
