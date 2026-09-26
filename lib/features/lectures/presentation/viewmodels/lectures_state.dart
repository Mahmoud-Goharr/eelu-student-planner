import '../../data/models/lecture_model.dart';

enum LecturesStatus {
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

class LecturesState {
  const LecturesState({
    this.status = LecturesStatus.initial,
    this.lectures = const [],
    this.errorMessage,
  });
  final LecturesStatus status;
  final List<LectureModel> lectures;
  final String? errorMessage;
  LecturesState copyWith({
    LecturesStatus? status,
    List<LectureModel>? lectures,
    String? errorMessage,
    bool clearError = false,
  }) => LecturesState(
    status: status ?? this.status,
    lectures: lectures ?? this.lectures,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}
