import '../../domain/repositories/profile_repository.dart';
import '../models/course_group_selection.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({ProfileRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? ProfileRemoteDataSource();

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<ProfileModel> getProfile() {
    return _remoteDataSource.getProfile();
  }

  @override
  Future<List<CourseGroupSelection>> getSelectedCourseGroups() {
    return _remoteDataSource.getSelectedCourseGroups();
  }

  @override
  Future<ProfileModel> updateProfile({
    required String name,
    required String groupCode,
    String? avatarFilePath,
  }) {
    return _remoteDataSource.updateProfile(
      name: name,
      groupCode: groupCode,
      avatarFilePath: avatarFilePath,
    );
  }
}
