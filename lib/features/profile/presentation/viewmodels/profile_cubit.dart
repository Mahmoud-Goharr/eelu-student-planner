import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/course_group_selection.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../sync/profile_sync_bus.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({ProfileRepository? repository})
    : _repository = repository ?? ProfileRepositoryImpl(),
      super(const ProfileState()) {
    _syncSubscription = ProfileSyncBus.instance.changes.listen((_) {
      if (!isClosed) getProfile();
    });
  }

  final ProfileRepository _repository;
  StreamSubscription<void>? _syncSubscription;

  Future<void> getProfile() async {
    emit(state.copyWith(status: ProfileStatus.loading, clearError: true));

    try {
      final profile = await _repository.getProfile();
      var courseGroups = const <CourseGroupSelection>[];

      try {
        courseGroups = await _repository.getSelectedCourseGroups();
      } catch (_) {
        // Keep profile available if group details are temporarily unavailable.
      }

      emit(
        state.copyWith(
          status: ProfileStatus.success,
          profile: profile,
          courseGroups: courseGroups,
          isDemo: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: ProfileStatus.failure, error: error.toString()),
      );
    }
  }

  Future<void> updateProfile({
    required String name,
    required String groupCode,
    String? avatarFilePath,
  }) async {
    emit(state.copyWith(status: ProfileStatus.updating, clearError: true));

    if (state.isDemo) {
      emit(
        state.copyWith(
          status: ProfileStatus.updateSuccess,
          profile: state.profile?.copyWith(
            name: name,
          ),
          isDemo: true,
          clearError: true,
        ),
      );
      return;
    }

    try {
      final profile = await _repository.updateProfile(
        name: name,
        groupCode: groupCode,
        avatarFilePath: avatarFilePath,
      );

      var courseGroups = state.courseGroups;
      try {
        courseGroups = await _repository.getSelectedCourseGroups();
      } catch (_) {}

      emit(
        state.copyWith(
          status: ProfileStatus.updateSuccess,
          profile: profile,
          courseGroups: courseGroups,
          isDemo: false,
          clearError: true,
        ),
      );
      ProfileSyncBus.instance.notify();
    } catch (error) {
      emit(
        state.copyWith(status: ProfileStatus.failure, error: error.toString()),
      );
    }
  }

  @override
  Future<void> close() async {
    await _syncSubscription?.cancel();
    return super.close();
  }
}
