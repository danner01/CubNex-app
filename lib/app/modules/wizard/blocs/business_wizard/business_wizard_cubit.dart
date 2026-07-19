import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../business/data/models/product_label_detection.dart';
import '../../data/models/business_type_model.dart';
import 'business_wizard_state.dart';

class BusinessWizardCubit extends Cubit<BusinessWizardState> {
  BusinessWizardCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessWizardState());

  final ApiClient _apiClient;
  static const _catalogTimeout = Duration(seconds: 18);
  static const _createTimeout = Duration(seconds: 25);

  Future<void> loadCatalog() async {
    emit(state.copyWith(status: BusinessWizardStatus.loading));
    try {
      final result = await _apiClient
          .get<List<BusinessTypeModel>>(
            '/wizard/tipos-negocio',
            queryParameters: {'limit': 100, 'order': 'orden.asc'},
            parser: (json) {
              if (json is List) {
                return json
                    .whereType<Map>()
                    .map(
                      (item) => BusinessTypeModel.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .toList();
              }
              return const [];
            },
          )
          .timeout(_catalogTimeout);

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
    } on TimeoutException {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.failure,
          message:
              'La carga de tipos de negocio esta tardando demasiado. Intenta nuevamente.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.failure,
          message: 'No se pudieron cargar los tipos de negocio.',
        ),
      );
    }
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
    bool acceptsTransfer = false,
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
    String? firstItemName,
    String? firstItemBrand,
    String? firstItemDescription,
    double? firstItemPrice,
    String firstItemCurrency = 'CUP',
    int? firstItemStock,
    String? firstItemCategory,
    List<String> firstItemImageUrls = const [],
    Map<String, dynamic> firstItemDetectedFeatures = const {},
    bool firstItemInInventory = true,
    bool firstItemPurchasable = true,
    List<Map<String, dynamic>> initialFuels = const [],
    List<Map<String, dynamic>> initialExchangeRates = const [],
  }) async {
    emit(state.copyWith(status: BusinessWizardStatus.saving));
    try {
      String? createdBusinessId;
      final result = await _apiClient
          .post<String?>(
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
              'acepta_transferencia': acceptsTransfer,
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
          )
          .timeout(_createTimeout);

      if (result.isSuccess) {
        createdBusinessId = result.data;
        if (createdBusinessId != null &&
            createdBusinessId.isNotEmpty &&
            firstItemName?.trim().isNotEmpty == true &&
            firstItemPrice != null) {
          final itemResult = await _apiClient
              .post<dynamic>(
                '/productos',
                data: {
                  'negocio_id': createdBusinessId,
                  'nombre': firstItemName!.trim(),
                  'slug': _slug(firstItemName),
                  'marca': _emptyToNull(firstItemBrand),
                  'descripcion': _emptyToNull(firstItemDescription),
                  'precio': firstItemPrice,
                  'moneda': firstItemCurrency,
                  'stock': firstItemStock,
                  'imagenes': firstItemImageUrls.take(3).toList(),
                  'caracteristicas': {
                    if (firstItemCategory?.trim().isNotEmpty == true)
                      'categoria': firstItemCategory!.trim(),
                    ...firstItemDetectedFeatures,
                    'creado_desde_wizard': true,
                  },
                  'en_inventario': firstItemInInventory,
                  'comprable': firstItemPurchasable,
                  'disponible': firstItemPurchasable,
                },
              )
              .timeout(_createTimeout);

          if (!itemResult.isSuccess) {
            emit(
              state.copyWith(
                status: BusinessWizardStatus.failure,
                message:
                    itemResult.error?.message ??
                    'El negocio se creo, pero no se pudo agregar el primer producto o servicio.',
              ),
            );
            return;
          }
        }

        final businessId = createdBusinessId;
        if (businessId != null && businessId.isNotEmpty) {
          final fuelRequests = initialFuels.map(
            (fuel) => _apiClient
                .post<dynamic>(
                  '/combustibles',
                  data: {'negocio_id': businessId, ...fuel},
                )
                .timeout(_createTimeout),
          );
          final rateRequests = initialExchangeRates.map(
            (rate) => _apiClient
                .post<dynamic>(
                  '/tasas-cambio',
                  data: {'negocio_id': businessId, ...rate},
                )
                .timeout(_createTimeout),
          );
          final specialResults = await Future.wait([...fuelRequests, ...rateRequests]);
          if (specialResults.any((item) => !item.isSuccess)) {
            emit(
              state.copyWith(
                status: BusinessWizardStatus.failure,
                message:
                    'El negocio se creo, pero no se pudo guardar toda su configuracion especializada.',
              ),
            );
            return;
          }
        }

        emit(
          state.copyWith(
            status: BusinessWizardStatus.success,
            createdBusinessId: createdBusinessId,
            message: 'Negocio configurado correctamente.',
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
    } on TimeoutException {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.failure,
          message:
              'La creacion del negocio esta tardando demasiado. Revisa la conexion y vuelve a intentar.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.failure,
          message: 'No se pudo crear el negocio. Intenta nuevamente.',
        ),
      );
    }
  }

  Future<ProductLabelDetection?> detectFirstProduct({
    String? frontImageBase64,
    String? backImageBase64,
  }) async {
    final result = await _apiClient.post<ProductLabelDetection>(
      '/vision-ia/detectar-etiqueta',
      data: {
        if (frontImageBase64 != null) 'imagen_frente_base64': frontImageBase64,
        if (backImageBase64 != null) 'imagen_reverso_base64': backImageBase64,
        'guardar_imagenes': true,
        'tipo_deteccion': 'ambos',
      },
      parser: (json) {
        if (json is Map) {
          return ProductLabelDetection.fromJson(
            Map<String, dynamic>.from(json),
          );
        }
        return const ProductLabelDetection();
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessWizardStatus.failure,
          message: result.error?.message ?? 'No se pudo analizar el empaque.',
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        status: BusinessWizardStatus.ready,
        message: 'Datos detectados. Revisa y corrige antes de finalizar.',
      ),
    );
    return result.data;
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

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
