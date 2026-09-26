import '../models/home_deadline.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState {
  const HomeState({
    this.status = HomeStatus.initial,
    this.deadlines = const [],
    this.taskCount = 0,
    this.hasDeadlineHistory = false,
    this.errorMessage,
  });

  final HomeStatus status;
  final List<HomeDeadline> deadlines;
  final int taskCount;
  final bool hasDeadlineHistory;
  final String? errorMessage;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeDeadline>? deadlines,
    int? taskCount,
    bool? hasDeadlineHistory,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      deadlines: deadlines ?? this.deadlines,
      taskCount: taskCount ?? this.taskCount,
      hasDeadlineHistory: hasDeadlineHistory ?? this.hasDeadlineHistory,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
