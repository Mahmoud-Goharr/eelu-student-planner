import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/exams/data/models/exam_model.dart';
import '../../features/tasks/data/models/task_model.dart';
import '../../features/schedule/data/models/schedule_model.dart';
import '../../features/lectures/data/models/lecture_model.dart';
import '../../features/profile/data/models/profile_model.dart';


class PlannerAuthSnapshot {
  const PlannerAuthSnapshot({
    required this.userId,
    required this.status,
  });

  final String userId;
  final String status;
}

class PlannerHistoryItem {
  const PlannerHistoryItem({
    required this.id,
    required this.title,
    required this.course,
    required this.type,
    required this.dueDate,
    required this.isCompleted,
    required this.isPersonal,
  });

  final String id;
  final String title;
  final String course;
  final String type;
  final DateTime dueDate;
  final bool isCompleted;
  final bool isPersonal;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'course': course,
        'type': type,
        'due_date': dueDate.toIso8601String(),
        'is_completed': isCompleted,
        'is_personal': isPersonal,
      };

  factory PlannerHistoryItem.fromMap(Map<String, dynamic> map) {
    return PlannerHistoryItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      course: map['course']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isCompleted: map['is_completed'] as bool? ?? false,
      isPersonal: map['is_personal'] as bool? ?? false,
    );
  }
}

/// User-scoped local cache used as the offline source of last-known data.
/// Supabase remains the source of truth whenever the network is available.
class PlannerCache {
  PlannerCache._();

  static final PlannerCache instance = PlannerCache._();

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _key(String userId, String name) => 'planner:$userId:$name';

  Future<void> saveAuthSnapshot(String userId, String status) async {
    final prefs = await _prefs;
    await prefs.setString(
      'planner:auth_snapshot',
      jsonEncode({
        'user_id': userId,
        'status': status,
      }),
    );
  }

  Future<PlannerAuthSnapshot?> loadAuthSnapshot() async {
    final prefs = await _prefs;
    final raw = prefs.getString('planner:auth_snapshot');
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final userId = decoded['user_id']?.toString() ?? '';
      final status = decoded['status']?.toString() ?? '';
      if (userId.isEmpty || status.isEmpty) return null;

      return PlannerAuthSnapshot(
        userId: userId,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAuthSnapshot() async {
    final prefs = await _prefs;
    await prefs.remove('planner:auth_snapshot');
  }

  Future<void> saveProfile(String userId, ProfileModel profile) async {
    final prefs = await _prefs;
    final map = <String, dynamic>{
      ...profile.toMap(),
      'email': profile.email,
    };
    await prefs.setString(
      _key(userId, 'profile'),
      jsonEncode(map),
    );
  }

  Future<ProfileModel?> loadProfile(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'profile'));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return ProfileModel.fromMap(map, email: map['email']?.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> markSynced(String userId, String source) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(userId, 'synced_at:$source'),
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> lastSyncedAt(String userId, String source) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'synced_at:$source'));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveTasks(String userId, List<TaskModel> tasks) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(userId, 'tasks'),
      jsonEncode(tasks.map((task) => task.toMap()).toList()),
    );
  }

  Future<List<TaskModel>> loadTasks(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'tasks'));
    if (raw == null || raw.isEmpty) return const <TaskModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveExams(String userId, List<ExamModel> exams) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(userId, 'exams'),
      jsonEncode(exams.map((exam) => exam.toMap()).toList()),
    );
  }

  Future<List<ExamModel>> loadExams(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'exams'));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => ExamModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSchedule(String userId, List<ScheduleModel> rows) async {
    final prefs = await _prefs;
    await prefs.setString(_key(userId, 'schedule'), jsonEncode(rows.map((row) => row.toMap()).toList()));
  }

  Future<List<ScheduleModel>> loadSchedule(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'schedule'));
    if (raw == null || raw.isEmpty) return const <ScheduleModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ScheduleModel>[];
      return decoded
          .whereType<Map>()
          .map((item) => ScheduleModel.fromCacheMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const <ScheduleModel>[];
    }
  }

  Future<void> saveLectures(String userId, List<LectureModel> lectures) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(userId, 'lectures'),
      jsonEncode(lectures.map((lecture) => lecture.toMap()).toList()),
    );
  }

  Future<List<LectureModel>> loadLectures(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'lectures'));
    if (raw == null || raw.isEmpty) return const <LectureModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <LectureModel>[];
      return decoded
          .whereType<Map>()
          .map((item) => LectureModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const <LectureModel>[];
    }
  }

  Future<void> saveCompletion(String userId, String itemKey, bool value) async {
    final prefs = await _prefs;
    final key = _key(userId, 'completion');
    final current = await loadCompletions(userId);
    current[itemKey] = value;
    await prefs.setString(key, jsonEncode(current));
  }

  Future<Map<String, bool>> loadCompletions(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'completion'));
    if (raw == null || raw.isEmpty) return <String, bool>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, bool>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as bool? ?? false),
      );
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<bool> isCompleted(String userId, String itemKey) async {
    final values = await loadCompletions(userId);
    return values[itemKey] ?? false;
  }

  Future<void> archiveTask(String userId, TaskModel task) async {
    await _archive(
      userId,
      PlannerHistoryItem(
        id: task.id,
        title: task.title,
        course: task.courseId,
        type: task.type,
        dueDate: task.dueDate,
        isCompleted: task.isCompleted,
        isPersonal: task.isPersonal,
      ),
    );
  }

  Future<void> archiveExam(String userId, ExamModel exam, {bool? completed}) async {
    await _archive(
      userId,
      PlannerHistoryItem(
        id: 'exam:${exam.id}',
        title: exam.type,
        course: exam.courseName,
        type: 'exam',
        dueDate: exam.startTime,
        isCompleted: completed ?? await isCompleted(userId, 'exam:${exam.id}'),
        isPersonal: false,
      ),
    );
  }

  Future<List<PlannerHistoryItem>> loadHistory(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'history'));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = decoded
          .whereType<Map>()
          .map((item) => PlannerHistoryItem.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
      result.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// Removes academic Assignment/Quiz history entries whose source rows
  /// no longer exist in Supabase. Personal assignments and exams are kept.
  /// This prevents a Dashboard deletion from leaving the deleted item in
  /// the local "Past Deadlines" cache.
  Future<void> reconcileDeletedAcademicTasks(
    String userId,
    Set<String> existingTaskIds,
  ) async {
    final prefs = await _prefs;
    final existingHistory = await loadHistory(userId);

    final filteredHistory = existingHistory.where((item) {
      final isAcademicTask =
          item.id.startsWith('assignment:') || item.id.startsWith('quiz:');

      if (!isAcademicTask) return true;
      return existingTaskIds.contains(item.id);
    }).toList();

    final completions = await loadCompletions(userId);
    final validCompletionKeys = <String, bool>{
      for (final entry in completions.entries)
        if (!entry.key.startsWith('quiz:') || existingTaskIds.contains(entry.key))
          entry.key: entry.value,
    };

    await prefs.setString(
      _key(userId, 'history'),
      jsonEncode(filteredHistory.map((value) => value.toMap()).toList()),
    );
    await prefs.setString(
      _key(userId, 'completion'),
      jsonEncode(validCompletionKeys),
    );
  }

  Future<void> _archive(String userId, PlannerHistoryItem item) async {
    final prefs = await _prefs;
    final existing = await loadHistory(userId);
    final byId = <String, PlannerHistoryItem>{
      for (final value in existing) value.id: value,
    };
    byId[item.id] = item;
    final values = byId.values.toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    await prefs.setString(
      _key(userId, 'history'),
      jsonEncode(values.map((value) => value.toMap()).toList()),
    );
  }
}
