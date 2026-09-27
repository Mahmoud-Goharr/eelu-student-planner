import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/services/supabase_service.dart';

import '../../data/models/lecture_model.dart';
import '../../domain/repositories/lectures_repository.dart';
import 'lectures_state.dart';

class LecturesCubit extends Cubit<LecturesState> {
  LecturesCubit(this._repository) : super(const LecturesState());

  final LecturesRepository _repository;

  Future<void> getLectures() async {
    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <LectureModel>[]
        : await PlannerCache.instance.loadLectures(userId);

    if (isClosed) return;

    emit(state.copyWith(status: LecturesStatus.loading, clearError: true));

    final online = await NetworkProbe.isOnline();
    if (isClosed) return;

    if (!online) {
      if (cached.isNotEmpty) {
        emit(
          state.copyWith(
            status: LecturesStatus.success,
            lectures: cached,
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: LecturesStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    try {
      final data = await _repository.getLectures();
      if (isClosed) return;
      emit(LecturesState(status: LecturesStatus.success, lectures: data));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: cached.isNotEmpty
              ? LecturesStatus.success
              : LecturesStatus.failure,
          lectures: cached.isNotEmpty ? cached : state.lectures,
          errorMessage: cached.isNotEmpty ? 'offline' : AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> createLecture(LectureModel draft) async {
    emit(state.copyWith(status: LecturesStatus.creating, clearError: true));

    try {
      final lecture = await _repository.createLecture(draft);

      emit(
        state.copyWith(
          status: LecturesStatus.createSuccess,
          lectures: [...state.lectures, lecture],
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: LecturesStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> updateLecture(LectureModel draft) async {
    emit(state.copyWith(status: LecturesStatus.updating, clearError: true));

    try {
      final updated = await _repository.updateLecture(draft);

      final lectures = state.lectures
          .map((item) => item.id == updated.id ? updated : item)
          .toList();

      emit(
        state.copyWith(
          status: LecturesStatus.updateSuccess,
          lectures: lectures,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: LecturesStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> deleteLecture(String id) async {
    emit(state.copyWith(status: LecturesStatus.deleting, clearError: true));

    try {
      await _repository.deleteLecture(id);

      emit(
        state.copyWith(
          status: LecturesStatus.deleteSuccess,
          lectures: state.lectures.where((item) => item.id != id).toList(),
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: LecturesStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }
}
