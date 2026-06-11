import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/business_type_model.dart';
import 'business_wizard_state.dart';

class BusinessWizardCubit extends Cubit<BusinessWizardState> {
  BusinessWizardCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessWizardState());

  final ApiClient _apiClient;

  Future<void> loadCatalog() async {
    emit(state.copyWith(status: BusinessWizardStatus.loading));
    final result = await _apiClient.get<List<BusinessTypeModel>>(
      '/wizard/tipos-negocio',
      queryParameters: {'limit': 100, 'order': 'orden.asc'},
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

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.ready,
          types: result.data ?? const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessWizardStatus.failure,
        message: result.error?.message ?? 'No se pudieron cargar los tipos.',
      ),
    );
  }

  Future<void> createBusiness({
    required String name,
    String? description,
    String? businessTypeId,
    String? phone,
    String? whatsapp,
    String? email,
    String? province,
    String? municipality,
    String? address,
    String? openingTime,
    String? closingTime,
    bool availableNow = true,
    bool hasPhysicalLocation = true,
    bool requiresElectricity = false,
    bool hasElectricService = true,
    bool hasElectricBackup = false,
    String? electricBackupType,
    String? electricBlock,
    String? electricCircuit,
    double? latitude,
    double? longitude,
  }) async {
    emit(state.copyWith(status: BusinessWizardStatus.saving));
    final result = await _apiClient.post<String?>(
      '/wizard/crear-negocio',
      data: {
        'nombre': name,
        'slug': _slug(name),
        'descripcion': description,
        'tipo_negocio_id': businessTypeId,
        'telefono': phone,
        'whatsapp': whatsapp,
        'email': email,
        'provincia': province,
        'municipio': municipality,
        'direccion': address,
        'horario_apertura': openingTime,
        'horario_cierre': closingTime,
        'disponible_ahora': availableNow,
        'tiene_local_fisico': hasPhysicalLocation,
        'requiere_electricidad': requiresElectricity,
        'tiene_fluido_electrico': hasElectricService,
        'tiene_respaldo_electrico': hasElectricBackup,
        'tipo_respaldo_electrico': electricBackupType,
        'bloque_electrico': electricBlock,
        'circuito_electrico': electricCircuit,
        if (latitude != null && longitude != null)
          'coordenadas': {'lat': latitude, 'lng': longitude},
        'colores': {
          'primario': '#111512',
          'secundario': '#FFFFFF',
          'acento': '#D4AF37',
        },
        'activo': true,
      },
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          final first = Map<String, dynamic>.from(json.first as Map);
          return first['id']?.toString();
        }
        if (json is Map) return json['id']?.toString();
        return null;
      },
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.success,
          createdBusinessId: result.data,
          message: 'Negocio creado correctamente.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessWizardStatus.failure,
        message: result.error?.message ?? 'No se pudo crear el negocio.',
      ),
    );
  }

  String _slug(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return normalized.isEmpty
        ? 'negocio-${DateTime.now().millisecondsSinceEpoch}'
        : '$normalized-${DateTime.now().millisecondsSinceEpoch}';
  }
}
