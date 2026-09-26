import '../../data/models/task_model.dart';

abstract class TasksRepository {
  Future<List<TaskModel>> getTasks();

  Stream<List<TaskModel>> watchTasks();

  Future<TaskModel> createPersonalAssignment({
    required String title,
    String? description,
    required DateTime dueDate,
  });

  Future<TaskModel> updatePersonalAssignment(TaskModel task);

  Future<void> deletePersonalAssignment(String taskId);

  Future<TaskModel> toggleTaskCompletion({
    required TaskModel task,
    required bool isCompleted,
  });
}
