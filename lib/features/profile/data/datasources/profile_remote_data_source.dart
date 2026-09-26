import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/course_group_selection.dart';
import '../models/profile_model.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  Future<ProfileModel> getProfile() async {
    final user = _supabaseService.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final profile = ProfileModel.fromMap(
        Map<String, dynamic>.from(response),
        email: user.email,
      );
      await PlannerCache.instance.saveProfile(user.id, profile);
      await PlannerCache.instance.markSynced(user.id, 'profile');
      return profile;
    } catch (_) {
      final cached = await PlannerCache.instance.loadProfile(user.id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<CourseGroupSelection>> getSelectedCourseGroups() async {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const AuthException('User is not authenticated.');

    final term = await _supabaseService.client
        .from('academic_terms')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();
    final termId = term?['id']?.toString();
    if (termId == null || termId.isEmpty) return const [];

    final response = await _supabaseService.client
        .from('student_course_selections')
        .select('''
          course_offering_id,
          course_offerings!inner(
            courses!inner(name),
            academic_groups!inner(code)
          )
        ''')
        .eq('student_id', user.id)
        .eq('term_id', termId);

    final selections = response.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      final offering = row['course_offerings'] is Map
          ? Map<String, dynamic>.from(row['course_offerings'] as Map)
          : const <String, dynamic>{};
      final course = offering['courses'] is Map
          ? Map<String, dynamic>.from(offering['courses'] as Map)
          : const <String, dynamic>{};
      final group = offering['academic_groups'] is Map
          ? Map<String, dynamic>.from(offering['academic_groups'] as Map)
          : const <String, dynamic>{};
      return CourseGroupSelection(
        courseName: course['name']?.toString().trim() ?? '',
        groupCode: group['code']?.toString().trim() ?? '',
      );
    }).where((item) => item.courseName.isNotEmpty).toList();

    selections.sort((a, b) => a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()));
    return selections;
  }

  Future<ProfileModel> updateProfile({
    required String name,
    required String groupCode,
    String? avatarFilePath,
  }) async {
    final user = _supabaseService.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    String? avatarUrl;
    String? uploadedObjectPath;

    try {
      // ---------------------------------------------------------------
      // 1. Upload new avatar if the user selected one.
      // ---------------------------------------------------------------
      if (avatarFilePath != null && avatarFilePath.trim().isNotEmpty) {
        final file = File(avatarFilePath);

        if (!await file.exists()) {
          throw Exception('Selected image file was not found.');
        }

        final extension = _fileExtension(file.path);
        final fileName =
            'avatar_${DateTime.now().microsecondsSinceEpoch}$extension';

        uploadedObjectPath = '${user.id}/$fileName';

        await _supabaseService.client.storage
            .from('avatars')
            .upload(
              uploadedObjectPath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        avatarUrl = _supabaseService.client.storage
            .from('avatars')
            .getPublicUrl(uploadedObjectPath);
      }

      // ---------------------------------------------------------------
      // 2. Update only editable profile fields.
      //
      // Student ID, level and group are onboarding/academic data.
      // They must never be changed from Edit Profile.
      // Group is derived from student_course_selections.
      // ---------------------------------------------------------------
      final updateData = <String, dynamic>{'name': name.trim()};
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updateData['avatar_url'] = avatarUrl;
      }

      await _supabaseService.client
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      await _updateSelectedCourseGroups(
        userId: user.id,
        groupCode: groupCode,
      );

      final profileResponse = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final profile = ProfileModel.fromMap(
        Map<String, dynamic>.from(profileResponse),
        email: user.email,
      );

      await PlannerCache.instance.saveProfile(user.id, profile);
      await PlannerCache.instance.markSynced(user.id, 'profile');
      return profile;
    } catch (error) {
      // ---------------------------------------------------------------
      // Cleanup uploaded file if the profile update failed.
      // ---------------------------------------------------------------
      if (uploadedObjectPath != null) {
        try {
          await _supabaseService.client.storage.from('avatars').remove([
            uploadedObjectPath,
          ]);
        } catch (_) {
          // Do not replace the original error with cleanup failure.
        }
      }

      rethrow;
    }
  }

  Future<void> _updateSelectedCourseGroups({
    required String userId,
    required String groupCode,
  }) async {
    final code = groupCode.trim().toUpperCase();
    if (!{'A', 'B', 'C', 'D'}.contains(code)) {
      throw const PostgrestException(message: 'Invalid group.');
    }

    final term = await _supabaseService.client
        .from('academic_terms')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();

    final termId = term?['id']?.toString();
    if (termId == null || termId.isEmpty) {
      throw const PostgrestException(message: 'No active academic term found.');
    }

    final selections = await _supabaseService.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', userId)
        .eq('term_id', termId);

    if (selections.isEmpty) return;

    final currentOfferingIds = selections
        .map((row) => row['course_offering_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final currentOfferings = await _supabaseService.client
        .from('course_offerings')
        .select('id,course_id')
        .eq('term_id', termId)
        .inFilter('id', currentOfferingIds);

    final courseIds = currentOfferings
        .map((row) => row['course_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    if (courseIds.isEmpty) return;

    final targetOfferings = await _supabaseService.client
        .from('course_offerings')
        .select('id,course_id,academic_groups!inner(code)')
        .eq('term_id', termId)
        .eq('academic_groups.code', code)
        .inFilter('course_id', courseIds.toList());

    final targetByCourse = <String, String>{};
    for (final row in targetOfferings) {
      final courseId = row['course_id']?.toString();
      final offeringId = row['id']?.toString();
      if (courseId != null && offeringId != null) {
        targetByCourse[courseId] = offeringId;
      }
    }

    if (targetByCourse.length != courseIds.length) {
      throw PostgrestException(
        message: 'Group $code is not available for one or more selected courses.',
      );
    }

    await _supabaseService.client
        .from('student_course_selections')
        .delete()
        .eq('student_id', userId)
        .eq('term_id', termId);

    await _supabaseService.client.from('student_course_selections').insert(
      courseIds.map((courseId) {
        return {
          'student_id': userId,
          'term_id': termId,
          'course_offering_id': targetByCourse[courseId],
        };
      }).toList(),
    );
  }

  String _fileExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1) {
      return '.jpg';
    }

    final extension = fileName.substring(dotIndex).toLowerCase();

    const allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

    return allowedExtensions.contains(extension) ? extension : '.jpg';
  }
}
