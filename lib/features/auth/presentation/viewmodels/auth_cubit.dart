import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/connectivity/network_probe.dart';

import '../../../../core/errors/auth_error_mapper.dart';
import '../../domain/entities/course_selection_option.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  needsStudentId,
  needsCourseSelection,
  unauthenticated,
  failure,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.errorType,
    this.isOffline = false,
  });

  final AuthStatus status;
  final AuthErrorType? errorType;
  final bool isOffline;

  AuthState copyWith({
    AuthStatus? status,
    AuthErrorType? errorType,
    bool clearError = false,
    bool? isOffline,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorType: clearError
          ? null
          : (errorType ?? this.errorType),
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository)
      : super(const AuthState());

  final AuthRepository _repository;

  bool _authActionRunning = false;

  String? get currentUserEmail =>
      _repository.currentUserEmail;

  // ============================================================
  // Restore Session
  // ============================================================

  Future<void> restoreSession() async {
    emit(
      const AuthState(
        status: AuthStatus.loading,
      ),
    );

    try {
      final online = await NetworkProbe.isOnline();

      if (!_repository.isAuthenticated) {
        if (!online) {
          final snapshot = await PlannerCache.instance.loadAuthSnapshot();
          if (snapshot != null) {
            emit(
              AuthState(
                status: _statusFromSnapshot(snapshot.status),
                isOffline: true,
              ),
            );
            return;
          }
        }

        emit(
          const AuthState(
            status: AuthStatus.unauthenticated,
          ),
        );

        return;
      }

      // A persisted Supabase session is enough to keep the user inside
      // the app while offline. Do not make an RPC request a requirement
      // for startup; use the last known onboarding state instead.
      if (!online) {
        final snapshot = await PlannerCache.instance.loadAuthSnapshot();
        if (snapshot != null) {
          emit(
            AuthState(
              status: _statusFromSnapshot(snapshot.status),
              isOffline: true,
            ),
          );
          return;
        }
      }

      await _emitAuthenticationState();
    } catch (error) {
      // If the network disappears during startup, keep the last known
      // authenticated/onboarding state instead of sending the user to Login.
      final snapshot = await PlannerCache.instance.loadAuthSnapshot();
      if (snapshot != null && _repository.isAuthenticated) {
        emit(
          AuthState(
            status: _statusFromSnapshot(snapshot.status),
            isOffline: true,
          ),
        );
        return;
      }

      emit(
        AuthState(
          status: AuthStatus.failure,
          errorType: AuthErrorMapper.type(error),
        ),
      );
    }
  }

  // ============================================================
  // Email Login
  // ============================================================

  Future<void> signIn(
    String email,
    String password,
  ) async {
    await _run(
      () => _repository.signIn(
        email,
        password,
      ),
    );
  }

  // ============================================================
  // Register
  // ============================================================

  Future<void> register(
    String name,
    String email,
    String password,
  ) async {
    await _run(
      () => _repository.register(
        name,
        email,
        password,
      ),
    );
  }

  // ============================================================
  // Google Login
  // ============================================================

  Future<void> signInWithGoogle() async {
    await _run(
      _repository.signInWithGoogle,
    );
  }

  // ============================================================
  // Complete Student Profile
  // ============================================================

  Future<void> completeStudentProfile({
    required String studentId,
  }) async {
    emit(
      const AuthState(
        status: AuthStatus.loading,
      ),
    );

    try {
      await _repository.completeStudentProfile(
        studentId: studentId,
      );

      /*
       * Student ID onboarding is now complete.
       *
       * Do not call _emitAuthenticationState() here. That method also
       * loads the current-term course selections, which can fail while
       * the onboarding flow is transitioning to Course Selection.
       * At this point the only valid next step is selecting courses.
       *
       * On later app launches, restoreSession() will run the full
       * authentication-state check and will still distinguish between
       * Course Selection and Home based on saved selections.
       */
      emit(
        const AuthState(
          status: AuthStatus.needsCourseSelection,
        ),
      );
    } catch (error) {
      emit(
        AuthState(
          status: AuthStatus.needsStudentId,
          errorType: AuthErrorMapper.type(error),
        ),
      );
    }
  }

  Future<List<CourseSelectionOption>> getCourseSelectionOptions() =>
      _repository.getCourseSelectionOptions();

  Future<List<String>> getSelectedCourseOfferingIds() =>
      _repository.getSelectedCourseOfferingIds();

  Future<void> saveCourseSelections(List<String> offeringIds) async {
    emit(const AuthState(status: AuthStatus.loading));
    try {
      await _repository.saveCourseSelections(offeringIds);
      await _emitAuthenticationState();
    } catch (error) {
      emit(
        AuthState(
          status: AuthStatus.needsCourseSelection,
          errorType: AuthErrorMapper.type(error),
        ),
      );
    }
  }

  // ============================================================
  // Logout
  // ============================================================

  Future<void> signOut() async {
    /*
     * Immediately tell the UI that we're logging out.
     */
    emit(
      const AuthState(
        status: AuthStatus.loading,
      ),
    );

    try {
      await _repository.signOut();
      await PlannerCache.instance.clearAuthSnapshot();

      /*
       * Make sure the local AuthCubit state is completely
       * unauthenticated.
       */
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
        ),
      );
    } catch (error) {
      emit(
        AuthState(
          status: AuthStatus.failure,
          errorType: AuthErrorMapper.type(error),
        ),
      );
    }
  }

  // ============================================================
  // Common Auth Action
  // ============================================================

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    // Prevent two authentication operations from running at the same time.
    // This is especially important when Google login is attempted immediately
    // after logout.
    if (_authActionRunning) {
      log(
        'Ignoring authentication action because another action is running.',
        name: 'AUTH',
      );
      return;
    }

    _authActionRunning = true;

    emit(
      const AuthState(
        status: AuthStatus.loading,
      ),
    );

    try {
      log(
        'Starting authentication action.',
        name: 'AUTH',
      );

      await action();

      final session =
          Supabase.instance.client.auth.currentSession;

      log(
        'Supabase session exists: ${session != null}',
        name: 'AUTH',
      );

      if (session == null) {
        emit(
          const AuthState(
            status: AuthStatus.unauthenticated,
          ),
        );

        return;
      }

      await _emitAuthenticationState();
    } catch (error, stackTrace) {
      log(
        'Authentication action failed: $error',
        name: 'AUTH',
        stackTrace: stackTrace,
      );

      emit(
        AuthState(
          status: AuthStatus.failure,
          errorType: AuthErrorMapper.type(error),
        ),
      );
    } finally {
      _authActionRunning = false;
    }
  }

  // ============================================================
  // Determine Account Type
  // ============================================================

  Future<void> _emitAuthenticationState() async {
    final hasStudentProfile =
        await _repository.hasStudentProfile();

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (!hasStudentProfile) {
      if (userId != null) {
        await PlannerCache.instance.saveAuthSnapshot(
          userId,
          AuthStatus.needsStudentId.name,
        );
      }

      emit(const AuthState(status: AuthStatus.needsStudentId));
      return;
    }

    final selectedOfferings =
        await _repository.getSelectedCourseOfferingIds();

    final status = selectedOfferings.isEmpty
        ? AuthStatus.needsCourseSelection
        : AuthStatus.authenticated;

    if (userId != null) {
      await PlannerCache.instance.saveAuthSnapshot(
        userId,
        status.name,
      );
    }

    emit(
      AuthState(
        status: status,
      ),
    );
  }

  AuthStatus _statusFromSnapshot(String value) {
    switch (value) {
      case 'authenticated':
        return AuthStatus.authenticated;
      case 'needsStudentId':
        return AuthStatus.needsStudentId;
      case 'needsCourseSelection':
        return AuthStatus.needsCourseSelection;
      default:
        return AuthStatus.unauthenticated;
    }
  }
}