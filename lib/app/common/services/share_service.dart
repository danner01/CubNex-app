import 'package:share_plus/share_plus.dart';

import '../../config/http/api_client.dart';

class ShareService {
  const ShareService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String?> shareEntity({
    required String entityType,
    required String entityId,
    required String title,
    String? message,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/compartir/generar-enlace',
      data: {
        'tipo_entidad': entityType,
        'entidad_id': entityId,
      },
      parser: (json) {
        if (json is Map) return Map<String, dynamic>.from(json);
        return const {};
      },
    );

    if (!result.isSuccess) {
      return result.error?.message ?? 'No se pudo generar el enlace.';
    }

    final data = result.data ?? const {};
    final url = data['url']?.toString();
    final deepLink = data['deep_link']?.toString();
    final link = url?.isNotEmpty == true ? url : deepLink;
    if (link == null || link.isEmpty) {
      return 'El servidor no devolvio un enlace para compartir.';
    }

    await Share.share(
      [title, if (message != null && message.isNotEmpty) message, link].join('\n'),
      subject: title,
    );
    return null;
  }
}
