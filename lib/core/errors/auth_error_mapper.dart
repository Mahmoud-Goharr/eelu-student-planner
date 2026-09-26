import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_localizations.dart';

enum AuthErrorType {
  invalidCredentials,
  invalidStudentId,
  emailNotConfirmed,
  userAlreadyRegistered,
  invalidEmail,
  weakPassword,
  rateLimit,
  network,
  googleSignIn,
  database,
  generic,
}

class AuthErrorMapper {
  const AuthErrorMapper._();

  static AuthErrorType type(Object error) {
    if (error is GoogleSignInException) {
      return AuthErrorType.googleSignIn;
    }

    if (error is PostgrestException) {
      final message =
          '${error.message} ${error.details}'.toLowerCase();

      if (message.contains('already linked') ||
          message.contains('another account')) {
        return AuthErrorType.invalidStudentId;
      }

      if (message.contains('student') &&
          (message.contains('not found') ||
              message.contains('invalid') ||
              message.contains('does not exist'))) {
        return AuthErrorType.invalidStudentId;
      }

      return AuthErrorType.database;
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        return AuthErrorType.invalidCredentials;
      }

      if (message.contains('email not confirmed')) {
        return AuthErrorType.emailNotConfirmed;
      }

      if (message.contains('user already registered')) {
        return AuthErrorType.userAlreadyRegistered;
      }

      if (message.contains('email address') && message.contains('invalid')) {
        return AuthErrorType.invalidEmail;
      }

      if (message.contains('password') &&
          (message.contains('at least') || message.contains('weak'))) {
        return AuthErrorType.weakPassword;
      }

      if (message.contains('rate limit')) {
        return AuthErrorType.rateLimit;
      }

      if (message.contains('network')) {
        return AuthErrorType.network;
      }
    }

    return AuthErrorType.generic;
  }

  static String localized(
    AuthErrorType? errorType,
    AppLocalizations l10n,
  ) {
    return switch (errorType ?? AuthErrorType.generic) {
      AuthErrorType.invalidCredentials => l10n.invalidCredentials,
      AuthErrorType.invalidStudentId => l10n.studentIdAlreadyLinked,
      AuthErrorType.emailNotConfirmed => l10n.emailNotConfirmed,
      AuthErrorType.userAlreadyRegistered => l10n.userAlreadyRegistered,
      AuthErrorType.invalidEmail => l10n.invalidEmail,
      AuthErrorType.weakPassword => l10n.weakPassword,
      AuthErrorType.rateLimit => l10n.rateLimit,
      AuthErrorType.network => l10n.networkError,
      AuthErrorType.googleSignIn => l10n.googleSignInFailed,
      AuthErrorType.database => l10n.databaseError,
      AuthErrorType.generic => l10n.genericError,
    };
  }
}
