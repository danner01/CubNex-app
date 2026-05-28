import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../wizard/data/models/business_type_model.dart';
import 'preferences_state.dart';

class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const PreferencesState());

  final ApiClient _apiClient;

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

    emit(
      state.copyWith(
        status: PreferencesStatus.ready,
        selectedTypeIds: profileResult.data ?? <String>{},
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

  Map<String, dynamic>? _firstMap(dynamic json) {
    if (json is List && json.isNotEmpty && json.first is Map) {
      return Map<String, dynamic>.from(json.first as Map);
    }
    if (json is Map) return Map<String, dynamic>.from(json);
    return null;
  }
}
