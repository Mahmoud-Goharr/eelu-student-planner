import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit(this._preferences)
    : super(LocaleState(locale: _readLocale(_preferences)));

  static const _localeKey = 'app_locale';
  final SharedPreferences _preferences;

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'ar') {
      return;
    }

    emit(LocaleState(locale: locale));

    await _preferences.setString(_localeKey, locale.languageCode);
  }

  static Locale _readLocale(SharedPreferences preferences) {
    final savedLocale = preferences.getString(_localeKey);

    if (savedLocale == 'en') {
      return const Locale('en');
    }

    return const Locale('ar');
  }
}
