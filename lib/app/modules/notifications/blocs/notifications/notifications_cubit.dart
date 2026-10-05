import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/services/push_notification_service.dart';
import '../../../../config/http/api_client.dart';
import '../../data/models/notification_model.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required ApiClient apiClient,
    required PushNotificationService pushNotificationService,
  }) : _apiClient = apiClient,
       _pushNotificationService = pushNotificationService,
       super(const NotificationsState());

  final ApiClient _apiClient;
  final PushNotificationService _pushNotificationService;

  static const _tamanoPagina = 10;

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading));
    final result = await _apiClient.get<List<NotificationModel>>(
      '/notificaciones',
      queryParameters: {'limit': '$_tamanoPagina', 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar avisos.',
        ),
      );
      return;
    }

    final items = result.data ?? const [];
    emit(
      state.copyWith(
        status: NotificationsStatus.success,
        items: items,
        hasMore: items.length == _tamanoPagina,
        isLoadingMore: false,
      ),
    );
    _pushNotificationService.notifyNotificationsChanged();
  }

  Future<void> loadMore() async {
    if (state.status == NotificationsStatus.loading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, message: null));
    final result = await _apiClient.get<List<NotificationModel>>(
      '/notificaciones',
      queryParameters: {
        'limit': '$_tamanoPagina',
        'offset': '${state.items.length}',
        'order': 'created_at.desc',
      },
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          message: result.error?.message ?? 'No se pudieron cargar mas avisos.',
        ),
      );
      return;
    }

    final nuevos = result.data ?? const [];
    final ids = state.items.map((item) => item.id).toSet();
    emit(
      state.copyWith(
        isLoadingMore: false,
        items: [
          ...state.items,
          ...nuevos.where((item) => !ids.contains(item.id)),
        ],
        hasMore: nuevos.length == _tamanoPagina,
      ),
    );
    _pushNotificationService.notifyNotificationsChanged();
  }

  Future<void> markAsRead(String id) async {
    final result = await _apiClient.put<void>(
      '/notificaciones/$id/leer',
      parser: (_) {},
    );
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          message:
              result.error?.message ?? 'No se pudo marcar la notificacion.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        items: state.items
            .map((item) => item.id == id ? item.copyWith(read: true) : item)
            .toList(),
      ),
    );
    _pushNotificationService.notifyNotificationsChanged();
  }

  Future<void> markAllAsRead() async {
    emit(state.copyWith(status: NotificationsStatus.saving));
    final result = await _apiClient.put<void>(
      '/notificaciones/leer-todas',
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          message: result.error?.message ?? 'No se pudieron marcar.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: NotificationsStatus.success,
        items: state.items.map((item) => item.copyWith(read: true)).toList(),
        message: 'Notificaciones marcadas como leidas.',
      ),
    );
    _pushNotificationService.notifyNotificationsChanged();
  }
}
