class SchedulePauseModel {
  const SchedulePauseModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.isActive,
  });

  final String id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;
  final bool isActive;

  bool appliesTo(DateTime date) {
    if (!isActive) return false;

    final day = DateTime(date.year, date.month, date.day);
    final start = startDate == null
        ? null
        : DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);

    if (start == null && end == null) return true;
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;
    return true;
  }

  String get signature => [
        id,
        startDate?.toIso8601String() ?? '',
        endDate?.toIso8601String() ?? '',
        reason,
        isActive,
      ].join('|');
}
