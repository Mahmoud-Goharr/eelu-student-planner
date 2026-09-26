import '../../domain/repositories/tasks_repository.dart';
import '../datasources/tasks_remote_data_source.dart';
import '../models/task_model.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl(this._remoteDataSource);

  final TasksRemoteDataSource _remoteDataSource;

  @override
  Future<List<TaskModel>> getTasks() => _remoteDataSource.getTasks();

  @override
  Stream<List<TaskModel>> watchTasks() => _remoteDataSource.watchTasks();

  @override
  Future<TaskModel> createPersonalAssignment({
    required String title,
    String? description,
    required DateTime dueDate,
  }) {
    return _remoteDataSource.createPersonalAssignment(
      title: title,
      description: description,
      dueDate: dueDate,
    );
  }

  @override
  Future<TaskModel> updatePersonalAssignment(TaskModel task) {
    return _remoteDataSource.updatePersonalAssignment(task);
  }

  @override
  Future<void> deletePersonalAssignment(String taskId) {
    return _remoteDataSource.deletePersonalAssignment(taskId);
  }

  @override
  Future<TaskModel> toggleTaskCompletion({
    required TaskModel task,
    required bool isCompleted,
  }) {
    return _remoteDataSource.toggleTaskCompletion(
      task: task,
      isCompleted: isCompleted,
    );
  }
}
