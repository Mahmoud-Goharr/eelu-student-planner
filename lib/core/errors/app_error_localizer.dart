import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_localizations.dart';
import 'app_exceptions.dart';
import 'auth_error_mapper.dart';

class AppErrorLocalizer {
  const AppErrorLocalizer._();

  static String message(
    BuildContext context,
    Object? error, {
    String? fallback,
  }) {
    final l10n = AppLocalizations.of(context);

    if (error is ProfileImageUploadException ||
        error is StorageException) {
      return l10n.imageUploadFailed;
    }

    if (error is SocketException || error is TimeoutException) {
      return l10n.networkError;
    }

    if (error is PostgrestException) {
      return l10n.databaseError;
    }

    if (error is AuthException || error is GoogleSignInException) {
      return AuthErrorMapper.localized(
        AuthErrorMapper.type(error!),
        l10n,
      );
    }

    return fallback ?? l10n.genericError;
  }
}
