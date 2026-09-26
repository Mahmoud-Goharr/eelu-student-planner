import '../../data/models/course_group_selection.dart';
import '../../data/models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel> getProfile();

  Future<List<CourseGroupSelection>> getSelectedCourseGroups();

  Future<ProfileModel> updateProfile({
    required String name,
    required String groupCode,
    String? avatarFilePath,
  });
}
