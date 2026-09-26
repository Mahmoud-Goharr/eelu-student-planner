import '../../../exams/data/models/exam_model.dart';
import '../../../tasks/data/models/task_model.dart';

enum AllDeadlinesStatus { initial, loading, success, failure }

class AllDeadlinesState {
  const AllDeadlinesState({
    this.status = AllDeadlinesStatus.initial,
    this.tasks = const [],
    this.exams = const [],
    this.errorMessage,
  });

  final AllDeadlinesStatus status;
  final List<TaskModel> tasks;
  final List<ExamModel> exams;
  final String? errorMessage;

  AllDeadlinesState copyWith({
    AllDeadlinesStatus? status,
    List<TaskModel>? tasks,
    List<ExamModel>? exams,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AllDeadlinesState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      exams: exams ?? this.exams,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
