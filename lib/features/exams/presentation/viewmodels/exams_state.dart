import '../../data/models/exam_model.dart';

enum ExamsStatus {
  initial,
  loading,
  success,
  failure,
  creating,
  updating,
  deleting,
  createSuccess,
  updateSuccess,
  deleteSuccess,
}

class ExamsState {
  const ExamsState({
    this.status = ExamsStatus.initial,
    this.errorMessage,
    this.exams = const [],
    this.completed = const {},
  });

  final ExamsStatus status;
  final String? errorMessage;
  final List<ExamModel> exams;
  final Map<String, bool> completed;

  ExamsState copyWith({
    ExamsStatus? status,
    List<ExamModel>? exams,
    Map<String, bool>? completed,
    String? errorMessage,
    bool clearError = false,
  }) => ExamsState(
    status: status ?? this.status,
    exams: exams ?? this.exams,
    completed: completed ?? this.completed,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
