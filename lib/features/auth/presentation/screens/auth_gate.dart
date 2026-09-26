import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/auth_error_mapper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/main_shell.dart';
import '../viewmodels/auth_cubit.dart';
import 'login_screen.dart';
import 'student_id_screen.dart';
import 'course_selection_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isOffline) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.offlineUsingCachedData),
                behavior: SnackBarBehavior.floating,
              ),
            );
          return;
        }

        if (state.status == AuthStatus.failure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(AuthErrorMapper.localized(state.errorType, l10n)),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.unauthenticated:
          case AuthStatus.failure:
            return const LoginScreen();
          case AuthStatus.needsStudentId:
            return const StudentIdScreen();
          case AuthStatus.needsCourseSelection:
            return const CourseSelectionScreen();
          case AuthStatus.authenticated:
            return const MainShell();
        }
      },
    );
  }
}
