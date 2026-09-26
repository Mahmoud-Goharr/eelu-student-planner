class Course {
  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.level,
    required this.instructor,
    this.instructorEmail,
    this.youtubePlaylistUrl,
    required this.materialsUrl,
    required this.imageUrl,
    required this.groupCode,
  });

  final String id;
  final String code;
  final String name;
  final int level;
  final String instructor;
  final String? instructorEmail;
  final String? youtubePlaylistUrl;
  final String? materialsUrl;
  final String? imageUrl;
  final String groupCode;
}
