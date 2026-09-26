import '../entities/course_selection_option.dart';

abstract class AuthRepository {
  bool get isAuthenticated;
  String? get currentUserEmail;

  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();

  Future<List<CourseSelectionOption>> getCourseSelectionOptions();
  Future<List<String>> getSelectedCourseOfferingIds();
  Future<void> saveCourseSelections(List<String> offeringIds);

  Future<bool> hasStudentProfile();
  Future<void> completeStudentProfile({
    required String studentId,
  });
}
