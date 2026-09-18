import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/soporte_ticket_model.dart';
import 'support_tickets_state.dart';

class SupportTicketsCubit extends Cubit<SupportTicketsState> {
  SupportTicketsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const SupportTicketsState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: SupportTicketsStatus.loading));
    final result = await _apiClient.get<List<SoporteTicketModel>>(
      '/tickets',
      queryParameters: {'limit': 100, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) => SoporteTicketModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: SupportTicketsStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar tus tickets.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SupportTicketsStatus.success,
        tickets: result.data ?? const [],
      ),
    );
  }

  Future<SoporteTicketModel?> createTicket({
    required String descripcion,
    String? titulo,
    String? adjuntoUrl,
  }) async {
    emit(state.copyWith(status: SupportTicketsStatus.creating));
    final result = await _apiClient.post<SoporteTicketModel>(
      '/tickets',
      data: {
        'titulo': (titulo ?? '').trim().isEmpty ? null : titulo!.trim(),
        'descripcion': descripcion.trim(),
        if (adjuntoUrl != null && adjuntoUrl.isNotEmpty)
          'adjunto_url': adjuntoUrl,
      },
      parser: (json) => SoporteTicketModel.fromJson(
        json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{},
      ),
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: SupportTicketsStatus.failure,
          message: result.error?.message ?? 'No se pudo enviar el ticket.',
        ),
      );
      return null;
    }

    emit(state.copyWith(status: SupportTicketsStatus.success, message: null));
    await load();
    return result.data;
  }

  Future<String?> uploadAttachment(String filename, String contentType, String base64Data) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/storage/subir',
      data: {
        'archivo_base64': base64Data,
        'nombre_archivo': filename,
        'content_type': contentType,
        'bucket': 'soporte',
        'scope': 'tickets',
      },
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
    );
    if (!result.isSuccess) return null;
    final url = result.data?['public_url']?.toString();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  String fileToBase64(List<int> bytes) => base64Encode(bytes);
}