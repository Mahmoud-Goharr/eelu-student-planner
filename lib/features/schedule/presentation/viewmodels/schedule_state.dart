import '../../data/models/schedule_model.dart';

enum ScheduleStatus { initial, loading, success, failure }

class ScheduleState {
  const ScheduleState({
    this.status = ScheduleStatus.initial,
    this.schedule = const [],
    this.errorMessage,
  });

  final ScheduleStatus status;
  final List<ScheduleModel> schedule;
  final String? errorMessage;

  ScheduleState copyWith({
    ScheduleStatus? status,
    List<ScheduleModel>? schedule,
    String? errorMessage,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      errorMessage: errorMessage,
    );
  }
}
