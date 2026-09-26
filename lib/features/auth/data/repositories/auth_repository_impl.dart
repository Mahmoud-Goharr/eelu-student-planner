import '../datasources/auth_remote_data_source.dart';
import '../../domain/entities/course_selection_option.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  bool get isAuthenticated => _remoteDataSource.currentUser != null;

  @override
  String? get currentUserEmail => _remoteDataSource.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) =>
      _remoteDataSource.signIn(email, password);

  @override
  Future<void> register(String name, String email, String password) =>
      _remoteDataSource.register(name, email, password);

  @override
  Future<void> signInWithGoogle() => _remoteDataSource.signInWithGoogle();

  @override
  Future<void> signOut() => _remoteDataSource.signOut();

  @override
  Future<List<CourseSelectionOption>> getCourseSelectionOptions() =>
      _remoteDataSource.getCourseSelectionOptions();

  @override
  Future<List<String>> getSelectedCourseOfferingIds() =>
      _remoteDataSource.getSelectedCourseOfferingIds();

  @override
  Future<void> saveCourseSelections(List<String> offeringIds) =>
      _remoteDataSource.saveCourseSelections(offeringIds);

  @override
  Future<bool> hasStudentProfile() => _remoteDataSource.hasStudentProfile();

  @override
  Future<void> completeStudentProfile({
    required String studentId,
  }) =>
      _remoteDataSource.completeStudentProfile(
        studentId: studentId,
      );
}
