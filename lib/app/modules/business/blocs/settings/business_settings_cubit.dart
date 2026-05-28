import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/store_customization_model.dart';
import 'business_settings_state.dart';

class BusinessSettingsCubit extends Cubit<BusinessSettingsState> {
  BusinessSettingsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessSettingsState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: BusinessSettingsStatus.loading));
    final businessResult = await _apiClient.get<BusinessModel?>(
      '/negocios/mi-negocio',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return BusinessModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        return null;
      },
    );

    if (!businessResult.isSuccess || businessResult.data == null) {
      emit(
        state.copyWith(
          status: BusinessSettingsStatus.failure,
          message: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    final business = businessResult.data!;
    final customizationResult = await _apiClient.get<StoreCustomizationModel?>(
      '/personalizacion/${business.id}',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return StoreCustomizationModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        if (json is Map && json.isNotEmpty) {
          return StoreCustomizationModel.fromJson(Map<String, dynamic>.from(json));
        }
        return null;
      },
    );

    emit(
      state.copyWith(
        status: BusinessSettingsStatus.ready,
        business: business,
        customization:
            customizationResult.data ??
            StoreCustomizationModel(businessId: business.id),
      ),
    );
  }

  void update(StoreCustomizationModel customization) {
    emit(
      state.copyWith(
        status: BusinessSettingsStatus.ready,
        customization: customization,
      ),
    );
  }

  Future<void> save() async {
    final customization = state.customization;
    if (customization == null) return;

    emit(state.copyWith(status: BusinessSettingsStatus.saving));
    final result = customization.id == null
        ? await _apiClient.post<void>(
            '/personalizacion',
            data: customization.toJson(),
            parser: (_) {},
          )
        : await _apiClient.put<void>(
            '/personalizacion/${customization.businessId}',
            data: customization.toJson(),
            parser: (_) {},
          );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessSettingsStatus.failure,
          message: result.error?.message ?? 'No se pudo guardar.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessSettingsStatus.success,
        message: 'Apariencia guardada.',
      ),
    );
    await load();
  }
}
