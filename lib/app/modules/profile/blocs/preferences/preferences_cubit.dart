import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/http/api_client.dart';
import '../../../wizard/data/models/business_type_model.dart';
import 'preferences_state.dart';

class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit({
    required ApiClient apiClient,
    required SharedPreferences sharedPreferences,
  })
    : _apiClient = apiClient,
      _sharedPreferences = sharedPreferences,
      super(const PreferencesState());

  static const _localPreferencesKey = 'profile.preferencias_categorias';

  final ApiClient _apiClient;
  final SharedPreferences _sharedPreferences;

  Future<void> load() async {
    emit(state.copyWith(status: PreferencesStatus.loading));

    final profileResult = await _apiClient.get<Set<String>>(
      '/usuarios/perfil',
      parser: (json) {
        final profile = _firstMap(json);
        final preferences = profile?['preferencias_categorias'];
        if (preferences is List) {
          return preferences.map((item) => item.toString()).toSet();
        }
        return <String>{};
      },
    );

    final typesResult = await _apiClient.get<List<BusinessTypeModel>>(
      '/tipos-negocio',
      queryParameters: {'limit': 120, 'order': 'orden.asc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    BusinessTypeModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!profileResult.isSuccess || !typesResult.isSuccess) {
      emit(
        state.copyWith(
          status: PreferencesStatus.failure,
          message:
              profileResult.error?.message ??
              typesResult.error?.message ??
              'No se pudieron cargar preferencias.',
        ),
      );
      return;
    }

    final serverPreferences = profileResult.data ?? <String>{};
    final localPreferences = _readLocalPreferences();
    final selectedPreferences = localPreferences.isNotEmpty
        ? localPreferences
        : serverPreferences;

    emit(
      state.copyWith(
        status: PreferencesStatus.ready,
        selectedTypeIds: selectedPreferences,
        types: typesResult.data ?? const [],
      ),
    );
  }

  void toggleType(String typeId) {
    final next = Set<String>.from(state.selectedTypeIds);
    if (next.contains(typeId)) {
      next.remove(typeId);
    } else {
      next.add(typeId);
    }
    emit(state.copyWith(selectedTypeIds: next, status: PreferencesStatus.ready));
  }

  Future<void> save() async {
    emit(state.copyWith(status: PreferencesStatus.saving));
    final result = await _apiClient.put<void>(
      '/usuarios/preferencias',
      data: {'preferencias_categorias': state.selectedTypeIds.toList()},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      final errorCode = result.error?.code.toUpperCase();
      if (errorCode == 'SOLO_SUPERADMIN' || result.error?.statusCode == 403) {
        await _saveLocalPreferences(state.selectedTypeIds);
        emit(
          state.copyWith(
            status: PreferencesStatus.success,
            message:
                'Preferencias guardadas en este dispositivo. El backend necesita redeploy para sincronizarlas.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: PreferencesStatus.failure,
          message: result.error?.message ?? 'No se pudieron guardar.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PreferencesStatus.success,
        message: 'Preferencias guardadas.',
      ),
    );
  }

  Set<String> _readLocalPreferences() {
    return _sharedPreferences
        .getStringList(_localPreferencesKey)
        ?.toSet() ??
        <String>{};
  }

  Future<void> _saveLocalPreferences(Set<String> preferences) async {
    await _sharedPreferences.setStringList(
      _localPreferencesKey,
      preferences.toList(),
    );
  }

  Map<String, dynamic>? _firstMap(dynamic json) {
    if (json is List && json.isNotEmpty && json.first is Map) {
      return Map<String, dynamic>.from(json.first as Map);
    }
    if (json is Map) return Map<String, dynamic>.from(json);
    return null;
  }
}
