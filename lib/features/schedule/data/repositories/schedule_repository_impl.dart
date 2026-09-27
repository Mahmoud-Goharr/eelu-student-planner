import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_remote_data_source.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._remoteDataSource);

  final ScheduleRemoteDataSource _remoteDataSource;

  @override
  Future<ScheduleBundle> getSchedule() {
    return _remoteDataSource.getSchedule();
  }

  @override
  Stream<ScheduleBundle> watchSchedule() {
    return _remoteDataSource.watchSchedule();
  }
}
