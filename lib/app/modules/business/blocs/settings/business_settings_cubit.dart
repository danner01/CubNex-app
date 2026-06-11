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
          return StoreCustomizationModel.fromJson(
            Map<String, dynamic>.from(json),
          );
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

  void updateBusinessBrand({String? logoUrl, String? bannerUrl}) {
    final business = state.business;
    if (business == null) return;

    emit(
      state.copyWith(
        status: BusinessSettingsStatus.ready,
        business: business.copyWith(
          logoUrl: logoUrl ?? business.logoUrl,
          bannerUrl: bannerUrl ?? business.bannerUrl,
        ),
      ),
    );
  }

  void updateBusinessOperations({
    String? openingTime,
    String? closingTime,
    bool? availableNow,
    bool? hasPhysicalLocation,
    bool? requiresElectricity,
    bool? hasElectricService,
    bool? hasElectricBackup,
    String? electricBackupType,
    String? electricBlock,
    String? electricCircuit,
  }) {
    final business = state.business;
    if (business == null) return;

    emit(
      state.copyWith(
        status: BusinessSettingsStatus.ready,
        business: business.copyWith(
          openingTime: openingTime,
          closingTime: closingTime,
          availableNow: availableNow,
          hasPhysicalLocation: hasPhysicalLocation,
          requiresElectricity: requiresElectricity,
          hasElectricService: hasElectricService,
          hasElectricBackup: hasElectricBackup,
          electricBackupType: electricBackupType,
          electricBlock: electricBlock,
          electricCircuit: electricCircuit,
        ),
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

    final business = state.business;
    if (business != null) {
      final businessResult = await _apiClient.put<void>(
        '/negocios/${business.id}',
        data: {
          'logo_url': business.logoUrl,
          'banner_url': business.bannerUrl,
          'horario_apertura': _blankToNull(business.openingTime),
          'horario_cierre': _blankToNull(business.closingTime),
          'disponible_ahora': business.availableNow,
          'tiene_local_fisico': business.hasPhysicalLocation,
          'requiere_electricidad': business.requiresElectricity,
          'tiene_fluido_electrico': business.hasElectricService,
          'tiene_respaldo_electrico': business.hasElectricBackup,
          'tipo_respaldo_electrico': business.hasElectricBackup
              ? _blankToNull(business.electricBackupType)
              : null,
          'bloque_electrico': business.requiresElectricity
              ? _blankToNull(business.electricBlock)
              : null,
          'circuito_electrico': business.requiresElectricity
              ? _blankToNull(business.electricCircuit)
              : null,
          'colores': {
            'primario': customization.primaryColor,
            'secundario': customization.secondaryColor,
            'acento': customization.accentColor,
            'texto': customization.textColor,
            'fondo': customization.backgroundColor,
          },
        },
        parser: (_) {},
      );

      if (!businessResult.isSuccess) {
        emit(
          state.copyWith(
            status: BusinessSettingsStatus.failure,
            message:
                businessResult.error?.message ??
                'La paleta se guardo, pero no se pudo actualizar logo/banner.',
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        status: BusinessSettingsStatus.success,
        message: 'Apariencia guardada.',
      ),
    );
    await load();
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
