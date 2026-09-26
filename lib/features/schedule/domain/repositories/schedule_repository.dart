import '../../data/models/schedule_model.dart';

abstract class ScheduleRepository {
  Future<List<ScheduleModel>> getSchedule();

  Stream<List<ScheduleModel>> watchSchedule();
}
