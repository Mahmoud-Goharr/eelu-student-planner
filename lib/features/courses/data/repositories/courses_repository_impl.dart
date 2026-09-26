import '../../domain/entities/course.dart';
import '../../domain/repositories/courses_repository.dart';
import '../datasources/courses_remote_data_source.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  CoursesRepositoryImpl({CoursesRemoteDataSource? remoteDataSource})
      : _remote = remoteDataSource ?? CoursesRemoteDataSource();

  final CoursesRemoteDataSource _remote;

  @override
  Future<List<Course>> getCourses() => _remote.getCourses();
}
