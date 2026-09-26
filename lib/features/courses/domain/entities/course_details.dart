class CourseInstructor {
  const CourseInstructor({
    required this.name,
    this.email,
    required this.groupCodes,
    this.youtubePlaylistUrl,
    this.materialsUrl,
    required this.isStudentInstructor,
  });

  final String name;
  final String? email;
  final List<String> groupCodes;
  final String? youtubePlaylistUrl;
  final String? materialsUrl;
  final bool isStudentInstructor;
}

class CourseDetails {
  const CourseDetails({
    required this.instructors,
    required this.tasks,
    required this.quizzes,
    required this.exams,
    required this.lectures,
  });

  final List<CourseInstructor> instructors;
  final List<CourseDetailsItem> tasks;
  final List<CourseDetailsItem> quizzes;
  final List<CourseDetailsItem> exams;
  final List<CourseDetailsItem> lectures;
}

class CourseDetailsItem {
  const CourseDetailsItem({
    required this.title,
    required this.subtitle,
    this.date,
    this.isCompleted = false,
  });

  final String title;
  final String subtitle;
  final DateTime? date;
  final bool isCompleted;
}
