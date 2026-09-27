import '../../data/models/schedule_model.dart';
import '../../data/models/schedule_pause_model.dart';

class ScheduleBundle {
  const ScheduleBundle({
    required this.schedule,
    required this.pauses,
  });

  final List<ScheduleModel> schedule;
  final List<SchedulePauseModel> pauses;
}

abstract class ScheduleRepository {
  Future<ScheduleBundle> getSchedule();

  Stream<ScheduleBundle> watchSchedule();
}
