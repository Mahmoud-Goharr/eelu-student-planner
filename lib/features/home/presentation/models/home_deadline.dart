class HomeDeadline {
  const HomeDeadline({
    required this.title,
    required this.course,
    required this.when,
    required this.type,
    required this.isExam,
    this.isPersonal = false,
  });

  final String title;
  final String course;
  final DateTime when;
  final String type;
  final bool isExam;
  final bool isPersonal;
}
