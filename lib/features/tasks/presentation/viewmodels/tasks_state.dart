import '../../../../core/cache/planner_cache.dart';

import '../../data/models/task_model.dart';

enum TasksStatus {
  initial,
  loading,
  success,
  failure,
  creating,
  createSuccess,
  updating,
  updateSuccess,
  deleting,
  deleteSuccess,
}

class TasksState {
  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.history = const [],
    this.errorMessage,
  });

  final TasksStatus status;
  final List<TaskModel> tasks;
  final List<PlannerHistoryItem> history;
  final String? errorMessage;

  TasksState copyWith({
    TasksStatus? status,
    List<TaskModel>? tasks,
    List<PlannerHistoryItem>? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      history: history ?? this.history,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
