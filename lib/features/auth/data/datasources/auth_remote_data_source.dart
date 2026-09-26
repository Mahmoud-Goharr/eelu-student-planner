import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/course_selection_option.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._supabase);

  final SupabaseService _supabase;

  GoogleSignIn? _googleSignIn;
  bool _googleInitialized = false;

  User? get currentUser => _supabase.auth.currentUser;

  // ============================================================
  // Email / Password Login
  // ============================================================

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);

    // Re-enable FCM after a successful login.
    await FcmService.instance.resetLogoutProtection();

    await _syncGoogleProfile();
  }

  // ============================================================
  // Email / Password Register
  // ============================================================

  Future<void> register(String name, String email, String password) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'role': AppConstants.studentRole, 'name': name},
    );
  }

  // ============================================================
  // Google Login
  // ============================================================

  Future<void> signInWithGoogle() async {
    final googleSignIn = _googleSignIn ??= GoogleSignIn.instance;

    // Initialize Google only once.
    if (!_googleInitialized) {
      await googleSignIn.initialize(
        serverClientId: SupabaseConstants.googleWebClientId.isEmpty
            ? null
            : SupabaseConstants.googleWebClientId,
      );

      _googleInitialized = true;
    }

    // Authenticate with Google.
    final googleUser = await googleSignIn.authenticate();

    final idToken = googleUser.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google did not return an ID token.');
    }

    final authorization = await googleUser.authorizationClient
        .authorizationForScopes(const ['email', 'profile']);

    // Login to Supabase.
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );

    // Re-enable FCM after Supabase authentication succeeds.
    await FcmService.instance.resetLogoutProtection();

    // Sync Google display name / avatar.
    await _syncGoogleProfile(
      name: googleUser.displayName,
      avatarUrl: googleUser.photoUrl,
    );
  }

  // ============================================================
  // Check whether current user is a registered student
  // ============================================================

  Future<bool> hasStudentProfile() async {
    final user = currentUser;

    if (user == null) {
      return false;
    }

    /*
     * The database function checks the authenticated user.
     *
     * IMPORTANT:
     * This does NOT create a profile.
     * It only checks whether the current user already has
     * a student profile.
     */
    final result = await _supabase.client.rpc('has_student_profile');

    return result == true;
  }

  // ============================================================
  // Complete Student Registration
  // ============================================================

  Future<void> completeStudentProfile({
    required String studentId,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be signed in before completing your student profile.',
      );
    }

    /*
     * The official student information comes from
     * student_directory.
     *
     * level and section are kept in the method signature because
     * the existing AuthRepository/AuthCubit use them, but we DO NOT
     * trust them here.
     */
    await _supabase.client.rpc(
      'claim_student_account',
      params: {'p_student_id': studentId.trim()},
    );

    await _syncGoogleProfile();
  }

  // ============================================================
  // Student Metadata
  // ============================================================

  Future<void> ensureStudentMetadata() async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    /*
     * DO NOT force role = student here.
     *
     * An Admin may log in using email/password.
     * Therefore we must never overwrite an existing Admin role.
     */

    final profile = await _supabase.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final profileRole = profile?['role']?.toString();

    // Existing Admin → leave it alone.
    if (profileRole == 'admin') {
      return;
    }

    // Existing Student → leave it alone.
    if (profileRole == 'student') {
      return;
    }

    /*
     * If there is no profile yet, this account can later be claimed
     * as a student through Student ID registration.
     *
     * We intentionally DO NOT create the profile here.
     */
  }

  // ============================================================
  // Sync Google Profile
  // ============================================================

  Future<void> _syncGoogleProfile({String? name, String? avatarUrl}) async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};

    final resolvedName =
        (name ??
                metadata['full_name'] ??
                metadata['name'] ??
                [metadata['given_name'], metadata['family_name']]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(' '))
            .toString()
            .trim();

    final resolvedAvatar =
        (avatarUrl ?? metadata['avatar_url'] ?? metadata['picture'])
            ?.toString()
            .trim();

    if (resolvedName.isEmpty) {
      return;
    }

    final updateData = <String, dynamic>{'name': resolvedName};

    if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
      updateData['avatar_url'] = resolvedAvatar;
    }

    /*
     * IMPORTANT:
     * We only update name/avatar.
     *
     * We DO NOT change:
     * - role
     * - student_id
     * - level
     * - section
     *
     * Those are controlled by the database/student registration.
     */
    await _supabase.client
        .from('profiles')
        .update(updateData)
        .eq('id', user.id);
  }


  // ============================================================
  // Course Selection
  // ============================================================

  Future<List<CourseSelectionOption>> getCourseSelectionOptions() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in.');
    }

    final context = await _studentAcademicContext(user.id);
    final response = await _supabase.client
        .from('course_offerings')
        .select('''
          id,
          course_id,
          group_id,
          instructor,
          courses!inner(id,name,level),
          academic_groups!inner(id,code,level)
        ''')
        .eq('term_id', context.termId)
        .eq('courses.level', context.level)
        .order('course_id')
        .order('group_id');

    return response.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      final course = _mapValue(row['courses']);
      final group = _mapValue(row['academic_groups']);

      return CourseSelectionOption(
        offeringId: row['id'].toString(),
        courseId: row['course_id'].toString(),
        courseName: course['name']?.toString().trim() ?? '',
        instructor: row['instructor']?.toString().trim() ?? '',
        groupCode: group['code']?.toString().trim() ?? '',
      );
    }).where((item) => item.courseName.isNotEmpty).toList();
  }

  Future<List<String>> getSelectedCourseOfferingIds() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in.');
    }

    final context = await _studentAcademicContext(user.id);
    final response = await _supabase.client
        .from('student_course_selections')
        .select('course_offering_id')
        .eq('student_id', user.id)
        .eq('term_id', context.termId);

    return response
        .map((row) => row['course_offering_id'].toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> saveCourseSelections(List<String> offeringIds) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in.');
    }

    final context = await _studentAcademicContext(user.id);
    final uniqueIds = offeringIds.toSet().toList();

    if (uniqueIds.isEmpty) {
      throw const PostgrestException(message: 'Select at least one course.');
    }

    final validOfferings = await _supabase.client
        .from('course_offerings')
        .select('id,course_id,term_id,courses!inner(level)')
        .eq('term_id', context.termId)
        .eq('courses.level', context.level)
        .inFilter('id', uniqueIds);

    final validRows = validOfferings
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final validIds = validRows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final courseIds = validRows
        .map((row) => row['course_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (validIds.length != uniqueIds.length ||
        courseIds.length != uniqueIds.length) {
      throw const PostgrestException(
        message: 'Choose only one group for each course.',
      );
    }

    await _supabase.client
        .from('student_course_selections')
        .delete()
        .eq('student_id', user.id)
        .eq('term_id', context.termId);

    await _supabase.client.from('student_course_selections').insert(
      uniqueIds
          .map((offeringId) => {
                'student_id': user.id,
                'term_id': context.termId,
                'course_offering_id': offeringId,
              })
          .toList(),
    );
  }

  Future<_StudentAcademicContext> _studentAcademicContext(
    String userId,
  ) async {
    final term = await _supabase.client
        .from('academic_terms')
        .select('id')
        .eq('is_active', true)
        .maybeSingle();

    if (term == null) {
      throw const PostgrestException(message: 'No active academic term found.');
    }

    final profile = await _supabase.client
        .from('profiles')
        .select('level')
        .eq('id', userId)
        .maybeSingle();

    final level = profile?['level'];
    if (level == null) {
      throw const PostgrestException(message: 'Student level is not assigned.');
    }

    return _StudentAcademicContext(
      termId: term['id'].toString(),
      level: level,
    );
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  // ============================================================
  // Logout
  // ============================================================

  Future<void> signOut() async {
    /*
     * IMPORTANT:
     *
     * This must happen BEFORE Supabase signOut().
     *
     * It immediately:
     * 1. Blocks new FCM sync operations.
     * 2. Invalidates existing FCM sync operations.
     * 3. Removes the student's device while the session
     *    is still authenticated.
     */
    await FcmService.instance.removeCurrentStudentDeviceBeforeSignOut();

    // Now sign out from Supabase.
    await _supabase.auth.signOut();

    /*
     * Then sign out from Google.
     *
     * This prevents the previous Google account from remaining
     * selected for the next authentication attempt.
     */
    if (_googleSignIn != null) {
      try {
        await _googleSignIn!.signOut();
      } catch (_) {
        // Supabase logout already succeeded.
        // Google local sign-out failure should not prevent
        // the app from becoming unauthenticated.
      }
    }
  }
}


class _StudentAcademicContext {
  const _StudentAcademicContext({
    required this.termId,
    required this.level,
  });

  final String termId;
  final Object level;
}
