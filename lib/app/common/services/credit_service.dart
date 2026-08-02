import '../../config/http/api_client.dart';

class CreditService {
  CreditService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> recordCreditEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _apiClient.post<void>(
        '/creditos/acciones',
        data: {
          'tipo_accion': eventType,
          ...payload,
        },
        parser: (_) {},
      );
    } catch (_) {
      // Guardar el evento de crédito no es crítico para la experiencia local.
    }
  }

  Future<void> recordBusinessShare(String businessId) async {
    await recordCreditEvent('compartir_negocio', {'negocio_id': businessId});
  }

  Future<void> recordBusinessContact(String businessId, String method) async {
    await recordCreditEvent('contacto_negocio', {
      'negocio_id': businessId,
      'metodo': method,
    });
  }

  Future<void> recordBusinessReview(String businessId) async {
    await recordCreditEvent('resena_negocio', {'negocio_id': businessId});
  }
}
