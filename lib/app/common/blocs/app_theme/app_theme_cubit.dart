import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeCubit extends Cubit<ThemeMode> {
  AppThemeCubit({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences,
      super(ThemeMode.system);

  final SharedPreferences _sharedPreferences;
  static const _themeModeKey = 'app.theme_mode';

  void load() {
    emit(_modeFromStorage(_sharedPreferences.getString(_themeModeKey)));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _sharedPreferences.setString(_themeModeKey, mode.name);
    emit(mode);
  }

  ThemeMode _modeFromStorage(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
