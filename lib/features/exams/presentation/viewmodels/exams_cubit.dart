import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';
import '../../../../core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/exam_model.dart';
import '../../domain/repositories/exams_repository.dart';
import 'exams_state.dart';

class ExamsCubit extends Cubit<ExamsState> {
  ExamsCubit(this._repository) : super(const ExamsState());
  final ExamsRepository _repository;

  Future<void> getExams() async {
    if (state.status == ExamsStatus.loading ||
        state.status == ExamsStatus.creating ||
        state.status == ExamsStatus.updating ||
        state.status == ExamsStatus.deleting) {
      return;
    }

    if (isClosed) return;

    final userId = SupabaseService().auth.currentUser?.id;
    final cached = userId == null
        ? const <ExamModel>[]
        : await PlannerCache.instance.loadExams(userId);
    final completed = userId == null
        ? const <String, bool>{}
        : await PlannerCache.instance.loadCompletions(userId);

    if (isClosed) return;

    emit(state.copyWith(status: ExamsStatus.loading, clearError: true));

    final online = await NetworkProbe.isOnline();
    if (isClosed) return;

    if (!online) {
      if (cached.isNotEmpty) {
        emit(
          ExamsState(
            status: ExamsStatus.success,
            exams: cached,
            completed: {
              for (final exam in cached)
                'exam:${exam.id}': completed['exam:${exam.id}'] ?? false,
            },
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ExamsStatus.failure,
            errorMessage: 'offline',
          ),
        );
      }
      return;
    }

    try {
      final exams = await _repository.getExams();
      if (isClosed) return;
      final freshCompleted = userId == null
          ? const <String, bool>{}
          : await PlannerCache.instance.loadCompletions(userId);
      if (isClosed) return;
      emit(
        ExamsState(
          status: ExamsStatus.success,
          exams: exams,
          completed: {
            for (final exam in exams)
              'exam:${exam.id}': freshCompleted['exam:${exam.id}'] ?? false,
          },
        ),
      );
    } catch (error) {
      debugPrint('Exams load failed: $error');
      if (isClosed) return;
      if (cached.isNotEmpty) {
        emit(
          ExamsState(
            status: ExamsStatus.success,
            exams: cached,
            completed: {
              for (final exam in cached)
                'exam:${exam.id}': completed['exam:${exam.id}'] ?? false,
            },
            errorMessage: 'offline',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ExamsStatus.failure,
            errorMessage: AppErrorLocalizer.code(error),
          ),
        );
      }
    }
  }

  Future<void> createExam({
    required String courseId,
    required String courseName,
    required String type,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    int level = 3,
    String section = 'C&D',
  }) async {
    if (_isBusy) return;
    emit(state.copyWith(status: ExamsStatus.creating, clearError: true));
    try {
      final exam = await _repository.createExam(
        courseId: courseId,
        courseName: courseName,
        type: type,
        date: date,
        startTime: startTime,
        endTime: endTime,
        location: location,
        level: level,
        section: section,
      );
      emit(
        state.copyWith(
          status: ExamsStatus.createSuccess,
          exams: [...state.exams, exam],
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ExamsStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> updateExam(ExamModel exam) async {
    if (_isBusy) return;
    emit(state.copyWith(status: ExamsStatus.updating, clearError: true));
    try {
      final updated = await _repository.updateExam(exam);
      _replace(updated, ExamsStatus.updateSuccess);
    } catch (error) {
      emit(
        state.copyWith(
          status: ExamsStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }

  Future<void> deleteExam(String id) async {
    if (_isBusy) return;
    emit(state.copyWith(status: ExamsStatus.deleting, clearError: true));
    try {
      await _repository.deleteExam(id);
      emit(
        state.copyWith(
          status: ExamsStatus.deleteSuccess,
          exams: state.exams.where((e) => e.id != id).toList(),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ExamsStatus.failure,
          errorMessage: AppErrorLocalizer.code(error),
        ),
      );
    }
  }


  Future<void> toggleExamCompletion(ExamModel exam, bool completed) async {
    if (_isBusy) return;
    final userId = SupabaseService().auth.currentUser?.id;
    if (userId == null) return;

    await PlannerCache.instance.saveCompletion(
      userId,
      'exam:${exam.id}',
      completed,
    );
    emit(
      state.copyWith(
        status: ExamsStatus.success,
        completed: {
          ...state.completed,
          'exam:${exam.id}': completed,
        },
      ),
    );
  }

  void _replace(ExamModel exam, ExamsStatus status) {
    emit(
      state.copyWith(
        status: status,
        exams: state.exams.map((item) => item.id == exam.id ? exam : item).toList(),
      ),
    );
  }

  bool get _isBusy => state.status == ExamsStatus.loading ||
      state.status == ExamsStatus.creating ||
      state.status == ExamsStatus.updating ||
      state.status == ExamsStatus.deleting;
}
