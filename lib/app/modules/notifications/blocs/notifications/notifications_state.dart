import 'package:equatable/equatable.dart';

import '../../data/models/notification_model.dart';

enum NotificationsStatus { initial, loading, success, failure, saving }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.message,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final NotificationsStatus status;
  final List<NotificationModel> items;
  final String? message;
  final bool hasMore;
  final bool isLoadingMore;

  int get unreadCount => items.where((item) => !item.read).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationModel>? items,
    String? message,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: message,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [status, items, message, hasMore, isLoadingMore];
}
