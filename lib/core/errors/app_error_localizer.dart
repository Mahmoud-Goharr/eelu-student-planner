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

  static String code(Object? error) {
    if (error == null) return 'generic';
    if (error is String) {
      final value = error.toLowerCase();
      if ({'offline', 'network', 'permission', 'rate_limit', 'server', 'not_found', 'database', 'storage', 'auth', 'generic'}.contains(value)) {
        return value == 'offline' ? 'network' : value;
      }
      if (_looksLikeNetwork(value)) return 'network';
      if (_looksLikePermission(value)) return 'permission';
      if (_looksLikeRateLimit(value)) return 'rate_limit';
      if (_looksLikeServer(value)) return 'server';
      if (_looksLikeNotFound(value)) return 'not_found';
      return 'generic';
    }
    if (error is SocketException || error is TimeoutException) return 'network';
    if (error is AuthException) return _authCode(error);
    if (error is GoogleSignInException) return 'auth';
    if (error is ProfileImageUploadException || error is StorageException) {
      return 'storage';
    }
    if (error is PostgrestException) return _postgrestCode(error);
    return 'generic';
  }

  static String message(
    BuildContext context,
    Object? error, {
    String? fallback,
  }) {
    final l10n = AppLocalizations.of(context);
    switch (code(error)) {
      case 'network':
        return l10n.networkError;
      case 'permission':
        return l10n.permissionDeniedError;
      case 'rate_limit':
        return l10n.rateLimitError;
      case 'server':
        return l10n.serverError;
      case 'not_found':
        return l10n.notFoundError;
      case 'storage':
        return l10n.imageUploadFailed;
      case 'auth':
        final authType = error is AuthException
            ? AuthErrorMapper.type(error)
            : error is GoogleSignInException
                ? AuthErrorMapper.type(error)
                : null;
        return AuthErrorMapper.localized(authType, l10n);
      case 'database':
        return l10n.databaseError;
      case 'generic':
      default:
        return fallback ?? l10n.genericError;
    }
  }

  static String _authCode(AuthException error) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429) return 'rate_limit';
    if (status == 401 || status == 403) return 'auth';
    return 'auth';
  }

  static String _postgrestCode(PostgrestException error) {
    final code = error.code?.toUpperCase() ?? '';
    final text = '${error.message} ${error.details} ${error.hint}'.toLowerCase();
    if (code == '42501' || _looksLikePermission(text)) return 'permission';
    if (code == '23505') return 'database';
    if (code == '23503') return 'database';
    if (code == '22P02') return 'database';
    if (_looksLikeRateLimit(text)) return 'rate_limit';
    return 'database';
  }

  static bool _looksLikeNetwork(String value) =>
      value.contains('socketexception') ||
      value.contains('failed host lookup') ||
      value.contains('clientexception') ||
      value.contains('authretryablefetchexception') ||
      value.contains('connection reset') ||
      value.contains('connection refused') ||
      value.contains('network is unreachable') ||
      value.contains('timed out');

  static bool _looksLikePermission(String value) =>
      value.contains('42501') ||
      value.contains('permission denied') ||
      value.contains('row-level security') ||
      value.contains('rls') ||
      value.contains('forbidden') ||
      value.contains('403');

  static bool _looksLikeRateLimit(String value) =>
      value.contains('429') || value.contains('too many requests') || value.contains('rate limit');

  static bool _looksLikeServer(String value) =>
      value.contains('500') ||
      value.contains('502') ||
      value.contains('503') ||
      value.contains('504') ||
      value.contains('internal server error') ||
      value.contains('bad gateway') ||
      value.contains('service unavailable');

  static bool _looksLikeNotFound(String value) =>
      value.contains('404') || value.contains('not found');
}
