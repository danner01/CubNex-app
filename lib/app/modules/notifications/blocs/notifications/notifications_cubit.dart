import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/services/push_notification_service.dart';
import '../../../../config/http/api_client.dart';
import '../../data/models/notification_model.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required ApiClient apiClient,
    required PushNotificationService pushNotificationService,
  })
    : _apiClient = apiClient,
      _pushNotificationService = pushNotificationService,
      super(const NotificationsState());

  final ApiClient _apiClient;
  final PushNotificationService _pushNotificationService;

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading));
    final result = await _apiClient.get<List<NotificationModel>>(
      '/notificaciones',
      queryParameters: {'limit': 80, 'order': 'created_at.desc'},
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

    emit(
      state.copyWith(
        status: NotificationsStatus.success,
        items: result.data ?? const [],
      ),
    );
    _pushNotificationService.notifyNotificationsChanged();
  }

  Future<void> markAsRead(String id) async {
    final result = await _apiClient.put<void>(
      '/notificaciones/$id/leer',
      parser: (_) {},
    );
    if (!result.isSuccess) return;

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
