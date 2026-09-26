class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    this.level,
    this.section,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final int? level;
  final String? section;
  final String? email;
  final String? avatarUrl;

  ProfileModel copyWith({
    String? id,
    String? name,
    String? role,
    int? level,
    String? section,
    String? email,
    String? avatarUrl,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      level: level ?? this.level,
      section: section ?? this.section,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map, {String? email}) {
    return ProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Student',
      role: map['role'] as String? ?? 'student',
      level: map['level'] as int?,
      section: map['section'] as String?,
      email: email,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'level': level,
      'section': section,
      'avatar_url': avatarUrl,
    };
  }
}
