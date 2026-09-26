import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._preferences)
    : super(ThemeState(themeMode: _readThemeMode(_preferences)));

  static const _themeKey = 'theme_mode';
  final SharedPreferences _preferences;

  Future<void> toggleTheme() {
    return setThemeMode(
      state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    emit(ThemeState(themeMode: themeMode));
    await _preferences.setString(
      _themeKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static ThemeMode _readThemeMode(SharedPreferences preferences) {
    return preferences.getString(_themeKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}
