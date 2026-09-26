import '../../domain/entities/course_details.dart';
import '../../domain/repositories/course_details_repository.dart';
import '../datasources/course_details_remote_data_source.dart';

class CourseDetailsRepositoryImpl implements CourseDetailsRepository {
  CourseDetailsRepositoryImpl({CourseDetailsRemoteDataSource? remoteDataSource})
      : _remote = remoteDataSource ?? CourseDetailsRemoteDataSource();

  final CourseDetailsRemoteDataSource _remote;

  @override
  Future<CourseDetails> getDetails({
    required String courseId,
    required String courseName,
  }) {
    return _remote.getDetails(courseId: courseId, courseName: courseName);
  }
}
