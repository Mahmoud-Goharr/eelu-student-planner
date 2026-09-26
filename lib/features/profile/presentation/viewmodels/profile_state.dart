import '../../data/models/course_group_selection.dart';
import '../../data/models/profile_model.dart';

enum ProfileStatus {
  initial,
  loading,
  success,
  failure,
  updating,
  updateSuccess,
}

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.courseGroups = const [],
    this.isDemo = false,
    this.error,
  });

  final ProfileStatus status;
  final ProfileModel? profile;
  final List<CourseGroupSelection> courseGroups;
  final bool isDemo;
  final String? error;

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileModel? profile,
    List<CourseGroupSelection>? courseGroups,
    bool? isDemo,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      courseGroups: courseGroups ?? this.courseGroups,
      isDemo: isDemo ?? this.isDemo,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
