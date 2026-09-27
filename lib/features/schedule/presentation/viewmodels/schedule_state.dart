import '../../data/models/schedule_model.dart';
import '../../data/models/schedule_pause_model.dart';

enum ScheduleStatus { initial, loading, success, failure }

class ScheduleState {
  const ScheduleState({
    this.status = ScheduleStatus.initial,
    this.schedule = const [],
    this.pauses = const [],
    this.errorMessage,
  });

  final ScheduleStatus status;
  final List<ScheduleModel> schedule;
  final List<SchedulePauseModel> pauses;
  final String? errorMessage;

  ScheduleState copyWith({
    ScheduleStatus? status,
    List<ScheduleModel>? schedule,
    List<SchedulePauseModel>? pauses,
    String? errorMessage,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      pauses: pauses ?? this.pauses,
      errorMessage: errorMessage,
    );
  }
}
