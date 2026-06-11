import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../entities/user_role.dart';

enum RoleMode { client, business, delivery }

class RoleModeState {
  const RoleModeState({
    required this.activeMode,
    required this.availableModes,
  });

  const RoleModeState.client()
    : activeMode = RoleMode.client,
      availableModes = const [RoleMode.client];

  final RoleMode activeMode;
  final List<RoleMode> availableModes;

  bool get canSwitch => availableModes.length > 1;

  RoleModeState copyWith({
    RoleMode? activeMode,
    List<RoleMode>? availableModes,
  }) {
    return RoleModeState(
      activeMode: activeMode ?? this.activeMode,
      availableModes: availableModes ?? this.availableModes,
    );
  }
}

class RoleModeCubit extends Cubit<RoleModeState> {
  RoleModeCubit({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences,
      super(const RoleModeState.client());

  static const _storageKey = 'role_mode.active';

  final SharedPreferences _sharedPreferences;

  void syncWithRole(UserRole role) {
    final modes = _availableModesFor(role);
    final saved = _modeFromStorage(_sharedPreferences.getString(_storageKey));
    final active = saved != null && modes.contains(saved)
        ? saved
        : _defaultModeFor(role);

    emit(RoleModeState(activeMode: active, availableModes: modes));
  }

  Future<void> setMode(RoleMode mode) async {
    if (!state.availableModes.contains(mode)) return;
    await _sharedPreferences.setString(_storageKey, mode.name);
    emit(state.copyWith(activeMode: mode));
  }

  RoleMode _defaultModeFor(UserRole role) {
    return switch (role) {
      UserRole.businessAdmin || UserRole.superadmin => RoleMode.business,
      UserRole.delivery => RoleMode.delivery,
      _ => RoleMode.client,
    };
  }

  List<RoleMode> _availableModesFor(UserRole role) {
    return switch (role) {
      UserRole.businessAdmin => const [RoleMode.business, RoleMode.client],
      UserRole.superadmin => const [RoleMode.business, RoleMode.client],
      UserRole.delivery => const [RoleMode.delivery, RoleMode.client],
      UserRole.client => const [RoleMode.client],
      UserRole.guest => const [RoleMode.client],
    };
  }

  RoleMode? _modeFromStorage(String? value) {
    return switch (value) {
      'business' => RoleMode.business,
      'delivery' => RoleMode.delivery,
      'client' => RoleMode.client,
      _ => null,
    };
  }
}
