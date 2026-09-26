import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/deadlines/presentation/screens/all_deadlines_screen.dart';
import '../../features/deadlines/presentation/screens/completed_assessments_screen.dart';

import '../localization/app_localizations.dart';

import '../../features/auth/presentation/screens/auth_gate.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';

import '../../features/courses/data/models/course_model.dart';
import '../../features/courses/presentation/screens/course_details_screen.dart';

import '../../features/exams/data/models/exam_model.dart';
import '../../features/exams/presentation/screens/exam_details_screen.dart';
import '../../features/exams/presentation/screens/exams_screen.dart';

import '../../features/lecture_progress/presentation/screens/lecture_progress_screen.dart';

import '../../features/lectures/data/models/lecture_model.dart';
import '../../features/lectures/presentation/screens/lecture_details_screen.dart';
import '../../features/lectures/presentation/screens/lectures_screen.dart';

import '../../features/notifications/presentation/screens/notifications_screen.dart';

import '../../features/profile/presentation/screens/academic_information_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

import '../../features/settings/presentation/screens/about_app_screen.dart';
import '../../features/settings/presentation/screens/contact_links_screen.dart';

import '../../features/tasks/data/models/task_model.dart';
import '../../features/tasks/presentation/screens/task_details_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    // Start directly with AuthGate.
    // The Android native splash is the only startup splash.
    initialLocation: '/',

    routes: [
      // =========================
      // Authentication / Home
      // =========================
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AuthGate(),
      ),

      GoRoute(
        path: '/home',
        name: 'home-alias',
        builder: (context, state) => const AuthGate(),
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // =========================
      // Profile
      // =========================
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/academic-information',
        name: 'academic-information',
        builder: (context, state) => const AcademicInformationScreen(),
      ),

      // =========================
      // Settings
      // =========================
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutAppScreen(),
      ),

      GoRoute(
        path: '/contact',
        name: 'contact',
        builder: (context, state) => const ContactLinksScreen(),
      ),

      // =========================
      // Exams
      // =========================
      GoRoute(
        path: '/exams',
        name: 'exams',
        builder: (context, state) => const ExamsScreen(),
      ),

      GoRoute(
        path: '/exam-details',
        name: 'exam-details',
        builder: (context, state) => state.extra is ExamModel
            ? ExamDetailsScreen(exam: state.extra! as ExamModel)
            : const _InvalidDetails(),
      ),

      // =========================
      // Lectures
      // =========================
      GoRoute(
        path: '/lectures',
        name: 'lectures',
        builder: (context, state) => const LecturesScreen(),
      ),

      GoRoute(
        path: '/lecture-progress',
        name: 'lecture-progress',
        builder: (context, state) => const LectureProgressScreen(),
      ),

      GoRoute(
        path: '/lecture-details',
        name: 'lecture-details',
        builder: (context, state) => state.extra is LectureModel
            ? LectureDetailsScreen(lecture: state.extra! as LectureModel)
            : const _InvalidDetails(),
      ),

      // =========================
      // All Deadlines
      // =========================
      GoRoute(
        path: '/all-deadlines',
        name: 'all-deadlines',
        builder: (context, state) => const AllDeadlinesScreen(),
      ),

      GoRoute(
        path: '/completed-assessments',
        name: 'completed-assessments',
        builder: (context, state) => const CompletedAssessmentsScreen(),
      ),

      // =========================
      // Notifications
      // =========================
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // =========================
      // Course Details
      // =========================
      GoRoute(
        path: '/course-details',
        name: 'course-details',
        builder: (context, state) {
          final course = state.extra;

          if (course is! CourseModel) {
            return const CourseDetailsScreen.invalid();
          }

          return CourseDetailsScreen(course: course);
        },
      ),

      // =========================
      // Tasks / Quizzes
      // =========================
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) => const TasksScreen(),
      ),

      GoRoute(
        path: '/quizzes',
        name: 'quizzes',
        builder: (context, state) =>
            const TasksScreen(quizOnly: true),
      ),

      // =========================
      // Task Details
      // =========================
      GoRoute(
        path: '/task-details',
        name: 'task-details',
        builder: (context, state) => state.extra is TaskModel
            ? TaskDetailsScreen(task: state.extra! as TaskModel)
            : const _InvalidDetails(),
      ),
    ],
  );
}

class _InvalidDetails extends StatelessWidget {
  const _InvalidDetails();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(AppLocalizations.of(context).detailsUnavailable),
      ),
    );
  }
}
