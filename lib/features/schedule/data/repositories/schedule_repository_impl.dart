import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_remote_data_source.dart';
import '../models/schedule_model.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._remoteDataSource);

  final ScheduleRemoteDataSource _remoteDataSource;

  @override
  Future<List<ScheduleModel>> getSchedule() {
    return _remoteDataSource.getSchedule();
  }

  @override
  Stream<List<ScheduleModel>> watchSchedule() {
    return _remoteDataSource.watchSchedule();
  }
}
